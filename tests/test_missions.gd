extends SceneTree
const Mission = preload("res://core/mission_rules.gd")
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Saves = preload("res://core/battle_save.gd")
const Catalog = preload("res://core/catalog.gd")
const Hex = preload("res://core/hex_rules.gd")
var checks = 0
var failures = 0
var store
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func config(kind: String) -> Dictionary:
	return store.levels.filter(func(l): return l.levelId=="mission_"+kind.to_lower())[0].duplicate(true)
func selected(level: Dictionary) -> Array:
	var ids = Mission.required(level)
	for id in level.playerIds:
		if ids.size()<Mission.limit(level) and not ids.has(id): ids.append(id)
	return ids
func fixture(level: Dictionary):
	var session = Session.new()
	check(session.prepare(store.map_by_id(level.mapId),selected(level),level.enemyIds,level).is_empty(),"prepare selected squad and mission")
	session.auto_deploy()
	check(session.start().is_empty(),"required units deployed")
	return session
func round_end(session) -> void:
	session.end_player_turn()
	for unit in session.units:
		if unit.faction=="ENEMY": unit.acted = true
	session.next_round()
func _initialize() -> void:
	store = Store.new(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("missions-library.json"))
	check(Catalog.roster().size()==8,"eight playable units")
	for job in Catalog.data().jobs:
		check(Catalog.roster().filter(func(u): return u.job==job).size()==2,"two units per job")
	for level in store.levels: check(store.validate_level(level).is_empty(),"built-in mission valid "+level.levelId)
	var level = config("SURVIVE")
	check(not Mission.selection_errors(level,level.playerIds).is_empty(),"over-capacity squad rejected")
	check(not Mission.selection_errors(level,["player_archer_01"]).is_empty(),"mandatory and protected units required")
	check(not Mission.selection_errors(level,["player_swordsman_01","player_swordsman_01"]).is_empty(),"duplicate selection rejected")
	var s = Session.new()
	check(s.prepare(store.map_by_id(level.mapId),selected(level),level.enemyIds,level).is_empty(),"prepare before incomplete deployment")
	s.deploy("player_swordsman_01",Hex.cell(s.map.spawnPoints.keys().filter(func(k): return s.map.spawnPoints[k]=="PLAYER")[0]))
	check(not s.start().is_empty(),"protected unit cannot be omitted in deployment")
	s = fixture(level)
	round_end(s)
	check(s.phase=="PLAYER" and s.turn==2,"survival not early at round one end")
	var payload = JSON.parse_string(JSON.stringify(Saves.snapshot(s,level)))
	var loaded = Saves.validate(payload)
	check(loaded.ok,"mission and subset survive JSON save validation")
	var restored = Session.new()
	Saves.restore(restored,loaded)
	check(restored.mission.winCondition=="SURVIVE" and restored.allowed_ids.size()==5,"mission and squad restored")
	round_end(restored)
	check(restored.phase=="PLAYER" and restored.turn==3,"third round remains playable")
	round_end(restored)
	check(restored.phase=="RESULT" and restored.result=="VICTORY" and restored.turn==3,"victory after full third round")
	check(restored.rewind_to(2) and restored.result.is_empty() and restored.history.size()==2,"rewind restores round and truncates future")
	restored.get_unit("player_mage_01").hp = 0
	restored.settle()
	check(restored.result=="DEFEAT" and restored.result_reason.contains("米菈"),"protected unit death fails with explanation")
	check(restored.rewind_to(2) and not restored.get_unit("player_mage_01").is_empty(),"rewind restores protected unit")
	level = config("TARGET")
	s = fixture(level)
	s.get_unit("enemy_0").hp = 0
	s.settle()
	check(s.result.is_empty(),"non-target kill does not win")
	s.get_unit("enemy_3").hp = 0
	s.settle()
	check(s.result=="VICTORY" and s.units.any(func(u):return u.faction=="ENEMY"),"target victory with other enemies alive")
	check(s.rewind_to(1) and not s.defeated_ids.has("enemy_3"),"rewind restores target and kill record")
	level.protectedIds = ["player_swordsman_01"]
	s = fixture(level)
	s.get_unit("enemy_3").hp = 0
	s.get_unit("player_swordsman_01").hp = 0
	s.settle()
	check(s.result=="DEFEAT","protected death takes priority over target victory")
	level = config("SURVIVE")
	level.surviveTurns = 2
	s = fixture(level)
	for unit in s.units:
		if unit.faction=="ENEMY": unit.hp = 0
	s.settle()
	check(s.result.is_empty(),"survival does not become annihilation")
	round_end(s)
	check(Saves.validate(JSON.parse_string(JSON.stringify(Saves.snapshot(s,level)))).ok,"survival save accepts no remaining enemies")
	round_end(s)
	check(s.result=="VICTORY","survival advances when no enemies remain")
	level = config("TARGET")
	level.turnLimit = 1
	s = fixture(level)
	check(s.phase=="PLAYER","deadline does not fail at round start")
	round_end(s)
	check(s.result=="DEFEAT" and s.turn==1,"deadline fails after last enemy phase")
	level = config("REACH")
	s = fixture(level)
	var unit = s.get_unit(s.allowed_ids[0])
	var reachable = s.reachable(unit.id)
	var destination = unit.cell
	for key in reachable.costs:
		if reachable.costs[key]==1:
			destination = Hex.cell(key)
			break
	s.mission.goalCell = [destination.x,destination.y,destination.z]
	check(not s.move_unit(unit.id,destination).is_empty() and s.result=="VICTORY","reach victory triggered by valid move")
	check(s.rewind_to(1) and s.result.is_empty(),"reach rewind restores outside region")
	for field in ["deployLimit","requiredIds","protectedIds","turnLimit","goalCell","goalRadius"]:
		var bad = level.duplicate(true)
		bad[field] = {"deployLimit":0,"requiredIds":["missing"],"protectedIds":["missing"],"turnLimit":-1,"goalCell":[99,0,-99],"goalRadius":-1}[field]
		check(not store.validate_level(bad).is_empty(),"invalid rule rejected "+field)
	var wrong_type = level.duplicate(true)
	wrong_type.deployLimit = {}
	check(not store.validate_level(wrong_type).is_empty(),"malformed limit rejected without conversion")
	var bad_target = config("TARGET")
	bad_target.targetEnemyIndex = 999
	check(not store.validate_level(bad_target).is_empty(),"invalid target rejected")
	var impossible = config("SURVIVE")
	impossible.turnLimit = 1
	check(not store.validate_level(impossible).is_empty(),"impossible deadline rejected")
	print("MISSION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
