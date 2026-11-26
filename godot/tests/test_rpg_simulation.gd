extends SceneTree
const Session = preload("res://core/battle_session.gd")
const Saves = preload("res://core/battle_save.gd")
const Store = preload("res://core/data_store.gd")
const Catalog = preload("res://core/catalog.gd")
const Rules = preload("res://core/battle_rules.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func player_step(game: RefCounted, use_skills: bool) -> void:
	for unit in game.units:
		if unit.faction!="PLAYER" or unit.acted:
			continue
		var skill = Catalog.action(unit,true)
		var use_skill = use_skills and unit.mp>=skill.mp_cost and skill.get("effect","")!="guard"
		var action = Catalog.action(unit,use_skill)
		var plan = Rules.plan_ai(game.map,unit,game.units,action)
		if not plan.path.is_empty() and not unit.moved:
			game.move_unit(unit.id,plan.path[-1])
		if not str(plan.target_id).is_empty():
			var result = game.attack(unit.id,plan.target_id,use_skill)
			if not result.ok:
				game.wait_unit(unit.id)
		else:
			game.wait_unit(unit.id)
		return
func enemy_step(game: RefCounted) -> void:
	for unit in game.units.duplicate():
		if game.phase!="ENEMY":
			break
		if unit.faction=="ENEMY":
			game.commit_enemy(unit.id,game.enemy_plan(unit.id))
	game.next_round()
func equivalent(a: RefCounted,b: RefCounted) -> bool:
	return a.units==b.units and a.phase==b.phase and a.turn==b.turn and a.result==b.result and a.map==b.map and a.inventory==b.inventory and a.pending_loot==b.pending_loot and a.opened_chests==b.opened_chests and a.rng.state==b.rng.state
func _initialize() -> void:
	var output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if output.is_empty():
		quit(2)
		return
	var store = Store.new(output.path_join("simulation-library.json"))
	var cases = 0
	var wins = 0
	var losses = 0
	for map_id in ["map_rpg"]:
		for roster_count in [3,5]:
			for enemy_ids in [["enemy_mage_base","enemy_knight_base"],["enemy_swordsman_base","enemy_archer_base","enemy_mage_base","enemy_knight_base"]]:
				for use_skills in [false,true]:
					cases += 1
					var level = store.default_level(map_id)
					level.playerIds = Catalog.roster_ids().slice(0,roster_count)
					level.enemyIds = enemy_ids
					var game = Session.new()
					check(game.prepare(store.map_by_id(map_id),level.playerIds,enemy_ids).is_empty(),"prepare simulation")
					game.auto_deploy()
					game.start()
					var twin = Session.new()
					var steps = 0
					while game.phase!="RESULT" and game.turn<=80 and steps<500:
						steps += 1
						if game.phase=="PLAYER":
							var saved = Saves.snapshot(game,level)
							var loaded = Saves.validate(JSON.parse_string(JSON.stringify(saved)))
							check(loaded.ok,"simulation snapshot round-trip")
							if not loaded.ok:
								break
							Saves.restore(twin,loaded)
							check(equivalent(game,twin),"restored simulation starts equivalent")
							player_step(game,use_skills)
							player_step(twin,use_skills)
						else:
							enemy_step(game)
							enemy_step(twin)
						check(equivalent(game,twin),"continued combat matches uninterrupted combat")
					if game.phase!="RESULT":
						print("STALLED CASE %d: %s" % [cases,str(game.units)])
					check(game.phase=="RESULT","simulation reaches conclusion case %d" % cases)
					if game.result=="VICTORY": wins += 1
					if game.result=="DEFEAT": losses += 1
	print("RPG_SIMULATION: %d complete battles, %d victories, %d defeats" % [cases,wins,losses])
	print("RPG_SIMULATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
