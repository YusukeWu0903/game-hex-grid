extends SceneTree
const Saves = preload("res://core/battle_save.gd")
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Preferences = preload("res://core/preferences.gd")
const Hex = preload("res://core/hex_rules.gd")
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if output.is_empty():
		quit(2)
		return
	var store = Store.new(output.path_join("save-library.json"))
	var level = store.default_level("map_tutorial")
	var battle = Session.new()
	battle.prepare(store.map_by_id("map_tutorial"),level.playerIds,level.enemyIds)
	battle.auto_deploy()
	battle.start()
	var p = battle.get_unit(level.playerIds[0])
	p.hp -= 3
	p.mp -= 10
	p.moved = true
	battle.get_unit(level.playerIds[1]).acted = true
	battle.turn = 7
	var payload = Saves.snapshot(battle,level)
	var snapshot = payload.duplicate(true)
	check(Saves.validate(payload).ok,"valid in-progress save")
	check(payload == snapshot,"validation does not mutate payload")
	var path = output.path_join("battle-test.json")
	check(Saves.write(path,payload).is_empty(),"save to file")
	var loaded = Saves.read(path)
	check(loaded.ok,"read JSON serialization")
	var restored = Session.new()
	Saves.restore(restored,loaded)
	check(restored.turn == 7 and restored.phase == "PLAYER","restore turn and phase")
	check(restored.units == battle.units,"restore every unit including resource and action flags")
	check(not restored.get_unit(p.id).acted and restored.get_unit(p.id).moved,"moved unit retains remaining attack")
	check(restored.reachable(p.id).is_empty(),"restore cannot grant second movement")
	check(not restored.can_control(level.playerIds[1]),"restore cannot grant acted unit another action")
	check(Saves.write(path,payload).is_empty() and FileAccess.file_exists(path+".bak"),"overwrite preserves backup")
	for mutation in ["version","phase","turn","missing","overlap","dead","mp","flag","cell","job","name","faction","roster","enemyflag","allacted","badmap","badlevel","floatcell","duplicate","nonarray"]:
		var bad = payload.duplicate(true)
		match mutation:
			"version": bad.version = 2
			"phase": bad.phase = "ENEMY"
			"turn": bad.turn = 1.5
			"missing": bad.erase("units")
			"overlap": bad.units[1].cell = bad.units[0].cell
			"dead": bad.units[0].hp = 0
			"mp": bad.units[0].mp = 999
			"flag": bad.units[0].acted = "false"
			"cell": bad.units[0].cell = [99,-99,0]
			"job": bad.units[0].job = "mage"
			"name": bad.units[0].name = "changed"
			"faction": bad.units[0].faction = "NEUTRAL"
			"roster": bad.allowed_ids = []
			"enemyflag": bad.units[0].acted = true
			"allacted":
				for unit in bad.units:
					if unit.faction == "PLAYER": unit.acted = true
			"badmap": bad.map.radius = 0
			"badlevel": bad.level.enemyIds = [4]
			"floatcell": bad.units[0].cell = [0.5,-0.5,0]
			"duplicate": bad.units[1].id = bad.units[0].id
			"nonarray": bad.units = "bad"
		check(not Saves.validate(bad).ok,"reject "+mutation)
	var original_text = FileAccess.get_file_as_string(path)
	var invalid = payload.duplicate(true)
	invalid.phase = "RESULT"
	check(not Saves.write(path,invalid).is_empty(),"cannot save result phase")
	check(FileAccess.get_file_as_string(path)==original_text,"rejected save preserves previous bytes")
	var corrupt_path = output.path_join("corrupt-battle.json")
	var file = FileAccess.open(corrupt_path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(not Saves.read(corrupt_path).ok,"broken JSON rejected")
	check(FileAccess.get_file_as_string(corrupt_path)=="{broken","corrupt original retained")
	var failure_path = output.path_join("blocked-save.json")
	check(Saves.write(failure_path,payload).is_empty(),"prepare failure fixture")
	DirAccess.make_dir_recursive_absolute(failure_path+".bak")
	var failure_original = FileAccess.get_file_as_string(failure_path)
	check(not Saves.write(failure_path,payload).is_empty(),"backup rename conflict reports failure")
	check(FileAccess.get_file_as_string(failure_path)==failure_original,"backup failure preserves current save bytes")
	var huge_path = output.path_join("oversized-save.json")
	file = FileAccess.open(huge_path,FileAccess.WRITE)
	file.store_string("x".repeat(Saves.MAX_BYTES+1))
	file.close()
	check(not Saves.read(huge_path).ok,"oversized save rejected before parsing")
	var file_as_directory = output.path_join("not-a-directory")
	file = FileAccess.open(file_as_directory,FileAccess.WRITE)
	file.store_string("preserve")
	file.close()
	check(not Saves.write(file_as_directory.path_join("battle.json"),payload).is_empty(),"unwritable destination reports failure")
	check(FileAccess.get_file_as_string(file_as_directory)=="preserve","failed destination leaves existing file unchanged")
	var prefs = Preferences.new(output.path_join("test-settings.json"))
	prefs.values = {"sound":false,"reduced_motion":true,"cinematics":false,"volume":35}
	check(prefs.save().is_empty(),"preferences save")
	check(Preferences.new(prefs.path).values == prefs.values,"preferences persist across instances")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.level = level
	app.begin_deployment(level)
	app.battle.auto_deploy()
	app.start_battle()
	app.battle.turn = 9
	app.battle.get_unit(level.playerIds[0]).mp = 5
	app.save_battle()
	check(app.current_notice.contains("已儲存"),"UI reports actual successful save")
	app.show_menu()
	app.load_battle()
	check(app.mode == "BATTLE" and app.battle.turn == 9,"menu continue restores live battle")
	check(app.battle.get_unit(level.playerIds[0]).mp == 5,"continue preserves MP rather than heals")
	app.battle.turn = 10
	app.save_battle()
	app.show_menu()
	app.load_battle(true)
	check(app.battle.turn == 9,"backup restore returns to prior snapshot")
	app.show_menu()
	var current_file = FileAccess.open(app.battle_save_path(),FileAccess.WRITE)
	current_file.store_string("{broken current")
	current_file.close()
	app.load_battle()
	check(app.mode == "MENU" and app.battle.units.is_empty(),"bad main save leaves menu and state intact")
	app.load_battle(true)
	check(app.mode == "BATTLE" and app.battle.turn == 9,"backup still loads after current file corruption")
	var saved_map = app.battle.map.duplicate(true)
	var original_map_id = saved_map.mapId
	saved_map.mapId = "snapshot_only_map"
	app.level.mapId = saved_map.mapId
	app.begin_deployment(app.level,saved_map)
	check(app.mode=="DEPLOYMENT" and app.battle.map.mapId=="snapshot_only_map","retry may use embedded map without changing library")
	check(app.store.map_by_id("snapshot_only_map").is_empty(),"embedded map not silently inserted into library")
	app.level.mapId = original_map_id
	app.show_menu()
	app.audio.player.stop()
	app.queue_free()
	await create_timer(0.2).timeout
	print("SAVE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
