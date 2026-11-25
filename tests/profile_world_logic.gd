extends SceneTree
const Generator = preload("res://core/map_generator.gd")
const Session = preload("res://core/battle_session.gd")
const Rules = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/battle_save.gd")
const Catalog = preload("res://core/catalog.gd")
func _initialize() -> void:
	var session = Session.new()
	var level = {"levelId":"profile","name":"profile","mapId":"profile","playerIds":["player_swordsman_01","player_swordsman_02","player_archer_01"],"enemyIds":["enemy_swordsman_base","enemy_archer_base","enemy_swordsman_base"]}
	var map = Generator.generate(24,20261125,0.45)
	map.mapId = level.mapId
	var errors = session.prepare(map,level.playerIds,level.enemyIds)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	session.auto_deploy()
	session.start()
	session.end_player_turn()
	var results = {}
	for unit in session.units:
		if unit.faction=="ENEMY":
			var start = Time.get_ticks_usec()
			session.enemy_plan(unit.id)
			results[unit.id+"_plan_ms"] = float(Time.get_ticks_usec()-start)/1000.0
			start = Time.get_ticks_usec()
			Rules.threat_cells(map,unit,session.units,Catalog.action(unit))
			results[unit.id+"_threat_ms"] = float(Time.get_ticks_usec()-start)/1000.0
	results["snapshot_bytes"] = JSON.stringify(Saves.snapshot(session,level)).to_utf8_buffer().size()
	var path = OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("performance-logic.json")
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	print(JSON.stringify(results))
	quit()
