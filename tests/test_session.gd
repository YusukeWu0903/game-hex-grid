extends SceneTree
const Session = preload("res://core/battle_session.gd")
const Catalog = preload("res://core/catalog.gd")
const Rules = preload("res://core/battle_rules.gd")
const Hex = preload("res://core/hex_rules.gd")
const Store = preload("res://core/data_store.gd")
var count = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var test_root = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if test_root.is_empty():
		push_error("HEX_TACTICS_TEST_DIR must point to isolated D-drive test storage")
		quit(2)
		return
	var db = Store.new(test_root.path_join("library.json"))
	var map = db.map_by_id("map_tutorial")
	var game = Session.new()
	var roster = Catalog.roster_ids()
	check(game.prepare(map,[roster[0]],["enemy_swordsman_base"]).is_empty(),"prepare selected roster")
	check(not game.deploy(roster[1],Hex.cell("-4,4,0")),"unselected roster cannot deploy")
	check(not game.deploy(roster[0],Vector3i.ZERO),"non-spawn cannot deploy")
	check(game.start().size() > 0,"cannot start without player")
	check(game.deploy(roster[0],Hex.cell("-4,4,0")),"selected roster deploys")
	check(game.recall(Hex.cell("-4,4,0")),"recall deployed unit")
	game.auto_deploy()
	check(game.start().is_empty(),"valid deployment starts")
	check(game.phase == "PLAYER" and game.turn == 1,"initial player turn")
	var p = game.get_unit(roster[0])
	check(p.mp == 20 and p.hp == 12,"job MP and HP restored")
	var search = game.reachable(p.id)
	var target = Vector3i.ZERO
	for key in search.costs:
		if search.costs[key] == 1:
			target = Hex.cell(key)
			break
	check(not game.move_unit(p.id,target).is_empty(),"legal move accepted")
	check(game.move_unit(p.id,Hex.cell("-4,4,0")).is_empty(),"second move rejected")
	check(game.get_unit(p.id).moved,"movement persists after selection changes")
	check(game.wait_unit(p.id),"wait ends action")
	check(game.phase == "ENEMY","all acted transitions enemy")
	check(not game.wait_unit(p.id),"player command blocked in enemy turn")
	check(not game.next_round(),"cannot skip unacted enemies")
	for unit in game.units.duplicate():
		if unit.faction == "ENEMY":
			game.commit_enemy(unit.id,game.enemy_plan(unit.id))
	check(game.next_round(),"next round after all enemies")
	check(game.turn == 2 and not p.acted and not p.moved,"new round resets per-turn flags")
	game.abandon()
	check(game.units.is_empty() and game.phase == "MENU","abandon clears battle")
	check(game.prepare(map,roster,["enemy_swordsman_base"]).is_empty(),"restart prepare")
	game.auto_deploy()
	game.start()
	check(game.turn == 1,"restart resets turn")
	check(game.get_unit(roster[2]).mp == 30,"archer restored MP")
	var too_many = []
	for i in range(7): too_many.append("enemy_swordsman_base")
	check(not game.prepare(map,roster,too_many).is_empty(),"enemy spawn shortage rejected")
	var copy_map = map.duplicate(true)
	copy_map.mapId = "test_saved_map"
	copy_map.name = "保存測試"
	copy_map.terrains["0,0,0"] = "FOREST"
	check(db.save_map(copy_map).is_empty(),"map save")
	var new_db = Store.new(test_root.path_join("library.json"))
	check(new_db.map_by_id(copy_map.mapId).terrains["0,0,0"] == "FOREST","map survives reload")
	var export_path = test_root.path_join("roundtrip.json")
	check(db.export_map(export_path,copy_map).is_empty(),"JSON export")
	var imported = db.import_map(export_path)
	check(imported.ok and imported.map == copy_map,"JSON roundtrip exact")
	var bad = copy_map.duplicate(true)
	bad.terrains["0,0,0"] = "LAVA"
	check(not db.save_map(bad).is_empty(),"invalid map save rejected")
	check(db.map_by_id(copy_map.mapId).terrains["0,0,0"] == "FOREST","invalid map does not mutate library")
	var level = db.default_level(copy_map.mapId)
	level.levelId = "test_level"
	level.playerIds = [roster[2]]
	check(db.save_level(level).is_empty(),"selected-ID level saves")
	new_db = Store.new(test_root.path_join("library.json"))
	var saved_levels = new_db.levels.filter(func(l): return l.levelId == "test_level")
	check(saved_levels.size() == 1 and saved_levels[0].playerIds == [roster[2]],"selected IDs survive reload")
	copy_map.spawnPoints = {}
	check(db.save_map(copy_map).is_empty(),"map edits may temporarily invalidate a level")
	new_db = Store.new(test_root.path_join("library.json"))
	check(new_db.levels.any(func(l): return l.levelId == "test_level"),"unplayable level is retained after map editing")
	check(not new_db.validate_level(level).is_empty(),"unplayable level is rejected at play time")
	level.winCondition = "SURVIVE"
	check(not db.save_level(level).is_empty(),"unsupported objective rejected")
	# Complete real battles on both maps using legal model commands.
	for map_id in ["map_tutorial","map_custom"]:
		game = Session.new()
		game.prepare(db.map_by_id(map_id),roster,["enemy_swordsman_base","enemy_archer_base","enemy_heavy_guard"])
		game.auto_deploy()
		game.start()
		var commands = 0
		while game.phase != "RESULT" and game.turn <= 80 and commands < 1000:
			commands += 1
			if game.phase == "PLAYER":
				for unit in game.units.duplicate():
					if game.phase != "PLAYER": break
					if unit.faction != "PLAYER" or unit.acted: continue
					var skill = Catalog.action(unit,true)
					var action = skill if unit.mp >= skill.mp_cost else Catalog.action(unit)
					var plan = Rules.plan_ai(game.map,unit,game.units,action)
					if not plan.path.is_empty():
						game.move_unit(unit.id,plan.path[-1])
					if not str(plan.target_id).is_empty():
						var hit = game.attack(unit.id,plan.target_id,unit.mp >= skill.mp_cost)
						if not hit.ok: game.wait_unit(unit.id)
					else:
						game.wait_unit(unit.id)
			elif game.phase == "ENEMY":
				for unit in game.units.duplicate():
					if game.phase != "ENEMY": break
					if unit.faction == "ENEMY":
						game.commit_enemy(unit.id,game.enemy_plan(unit.id))
				game.next_round()
		check(game.phase == "RESULT","complete simulated battle " + map_id)
		print("SIMULATION: %s result=%s round=%d commands=%d" % [map_id,game.result,game.turn,commands])
	print("SESSION_TESTS: %d checks, %d failures" % [count,failures.size()])
	quit(0 if failures.is_empty() else 1)
