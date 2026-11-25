extends SceneTree
const Generator=preload("res://core/map_generator.gd")
const Session=preload("res://core/battle_session.gd")
const Saves=preload("res://core/battle_save.gd")
const Catalog=preload("res://core/catalog.gd")
func _initialize() -> void:
	var map=Generator.generate(24,20261125,0.45)
	var level={"levelId":"profile_rpg","name":"profile","mapId":map.mapId,"playerIds":["player_swordsman_01","player_mage_01","player_knight_01"],"enemyIds":["enemy_mage_base","enemy_knight_base","enemy_archer_base"],"winCondition":"ANNIHILATION","loseCondition":"PLAYER_DEATH"}
	var s=Session.new()
	s.prepare(map,level.playerIds,level.enemyIds)
	s.auto_deploy()
	s.start()
	var result={}
	s.end_player_turn()
	for unit in s.units:
		if unit.faction=="ENEMY":
			var start=Time.get_ticks_usec()
			s.enemy_plan(unit.id)
			result[unit.job+"_plan_ms"]=float(Time.get_ticks_usec()-start)/1000.0
	s.phase="PLAYER"
	for unit in s.units:unit.acted=false
	var memory=Performance.get_monitor(Performance.MEMORY_STATIC)
	var captures=[]
	for turn_number in range(2,201):
		s.turn=turn_number
		var start=Time.get_ticks_usec()
		s.capture_round()
		captures.append(float(Time.get_ticks_usec()-start)/1000.0)
	captures.sort()
	result.capture_p95_ms=captures[189]
	result.history_static_mib=(Performance.get_monitor(Performance.MEMORY_STATIC)-memory)/1048576.0
	var start=Time.get_ticks_usec()
	var payload=Saves.snapshot(s,level)
	result.snapshot_bytes=JSON.stringify(payload).to_utf8_buffer().size()
	result.serialize_ms=float(Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	var loaded=Saves.validate(JSON.parse_string(JSON.stringify(payload)))
	result.validate_ms=float(Time.get_ticks_usec()-start)/1000.0
	result.valid=loaded.ok
	start=Time.get_ticks_usec()
	result.rewind_middle=s.rewind_to(100) and s.turn==100 and s.history.size()==100
	result.rewind_ms=float(Time.get_ticks_usec()-start)/1000.0
	result.rewind_first=s.rewind_to(1) and s.turn==1 and s.history.size()==1
	var file=FileAccess.open(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("performance-rpg.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print(JSON.stringify(result))
	quit(0 if loaded.ok and result.rewind_middle and result.rewind_first else 1)
