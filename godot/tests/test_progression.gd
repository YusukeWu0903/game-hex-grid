extends SceneTree
const P = preload("res://core/progression.gd")
const Catalog = preload("res://core/catalog.gd")
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Saves = preload("res://core/battle_save.gd")
const Party = preload("res://core/party_store.gd")
const Mission = preload("res://core/mission_rules.gd")
var checks = 0
var failures = 0
var store
var level
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func fixture():
	var s = Session.new()
	check(s.prepare(store.map_by_id(level.mapId),level.playerIds,level.enemyIds,level).is_empty(),"prepare")
	s.progression = {"player_mage_01":100,"player_knight_01":225}
	s.auto_deploy()
	check(s.start().is_empty(),"start")
	return s
func _initialize() -> void:
	var dir = OS.get_environment("HEX_TACTICS_TEST_DIR")
	store = Store.new(dir.path_join("progression-library.json"))
	level = store.levels[1].duplicate(true)
	level.enemyLevels = []
	for unused in level.enemyIds: level.enemyLevels.append(3)
	check(P.level_for(0)==1 and P.level_for(99)==1 and P.level_for(100)==2 and P.level_for(225)==3,"threshold boundaries")
	check(P.level_for(999999)==20,"level cap")
	check(not P.valid({"unknown":1}) and not P.valid({"player_mage_01":-1}) and not P.valid({"player_mage_01":1.5}),"invalid progress rejected")
	for job in Catalog.data().jobs:
		var id = "player_%s_01" % job
		var base = Catalog.player(id,Vector3i.ZERO)
		var unit = base.duplicate(true)
		P.apply(unit,1)
		check(unit.max_hp==base.max_hp and unit.attack_bonus==0,"level one unchanged")
		P.apply(unit,20)
		check(unit.max_hp>base.max_hp and unit.max_mp>base.max_mp and unit.level==20,"four class growth")
	var s = fixture()
	check(s.get_unit("player_mage_01").level==2 and s.get_unit("enemy_0").level==3,"independent player and enemy levels")
	check(s.pending_exp.size()==level.playerIds.size() and s.pending_exp.player_mage_01==30,"participation awarded only deployed")
	var save = Saves.snapshot(s,level)
	var loaded = Saves.validate(JSON.parse_string(JSON.stringify(save)))
	check(loaded.ok,"leveled battle JSON validates")
	if loaded.ok:
		var restored = Session.new()
		Saves.restore(restored,loaded)
		check(restored.progression==s.progression and restored.pending_exp==s.pending_exp and restored.get_unit("player_mage_01").level==2,"round trip level and rewards")
	var bad = save.duplicate(true)
	bad.rpg.progression.player_mage_01 = -1
	check(not Saves.validate(bad).ok,"corrupt baseline rejected")
	bad = save.duplicate(true)
	bad.rpg.pending_exp = {"player_mage_02":40}
	check(not Saves.validate(bad).ok,"reserve reward rejected")
	bad = save.duplicate(true)
	bad.rpg.history[0].pending_exp = {"player_mage_01":-40}
	check(not Saves.validate(bad).ok,"corrupt historical exp rejected")
	var mage = s.get_unit("player_mage_01")
	mage.cell = Vector3i.ZERO
	s.get_unit("enemy_0").cell = Vector3i(2,-2,0)
	s.get_unit("enemy_1").cell = Vector3i(2,-1,-1)
	s.get_unit("enemy_0").hp = 1
	s.get_unit("enemy_1").hp = 1
	check(s.attack(mage.id,"enemy_0",true).ok,"area kill")
	check(s.pending_exp[mage.id]==110,"two victims credit exactly two kills")
	check(mage.level==2,"no mid battle level up")
	check(s.rewind_to(1) and s.pending_exp[mage.id]==30,"rewind restores rewards")
	var party = Party.new(dir.path_join("level-party.json"))
	s.pending_exp[mage.id] = 230
	check(not party.claim(s).is_empty() and party.progression.is_empty(),"no claim during battle")
	s.phase = "RESULT"
	s.result = "DEFEAT"
	check(not party.claim(s).is_empty(),"defeat does not commit")
	s.result = "VICTORY"
	# A participant may have fallen; they still receive earned EXP.
	s.units = s.units.filter(func(u): return u.id!=mage.id)
	check(party.claim(s).is_empty() and party.progression[mage.id]==230,"fallen participant commits earned exp")
	check(P.level_for(party.progression[mage.id])==3,"multi level settlement")
	var again = Party.new(party.path)
	check(again.claim(s).is_empty() and again.progression[mage.id]==230,"duplicate battle settlement idempotent after reload")
	check(not s.rewind_to(1),"settled battle cannot rewind")
	check(again.equip(mage.id,"weapon","").is_empty() and Party.new(party.path).progression[mage.id]==230,"equipment save retains XP")
	var cap = fixture()
	cap.phase = "RESULT"
	cap.result = "VICTORY"
	cap.pending_exp[mage.id] = 999999
	check(again.claim(cap).is_empty() and again.progression[mage.id]==P.threshold(20),"experience capped")
	var blocked = Party.new(dir.path_join("blocked-level-party.json"))
	check(blocked.save_payload(blocked.inventory,blocked.loadouts,{}).is_empty(),"failure fixture")
	DirAccess.make_dir_absolute(blocked.path+".bak")
	var unpaid = fixture()
	unpaid.phase = "RESULT"
	unpaid.result = "VICTORY"
	check(not blocked.claim(unpaid).is_empty() and blocked.progression.is_empty() and blocked.settled_ids.is_empty() and not unpaid.settled,"failed write commits neither loot ledger nor XP")
	var legacy_path = dir.path_join("legacy-level-party.json")
	check(Saves.write_json(legacy_path,{"version":1,"inventory":party.inventory,"loadouts":party.loadouts,"settled_ids":{}}).is_empty(),"legacy fixture")
	var legacy = Party.new(legacy_path)
	check(legacy.error.is_empty() and legacy.progression.is_empty() and legacy.inventory==party.inventory,"legacy party retains inventory and starts level one")
	var old = fixture()
	old.progression = {}
	old.phase = "DEPLOYMENT"
	old.auto_deploy()
	old.history = []
	old.start()
	var old_save = Saves.snapshot(old,level)
	old_save.rpg.erase("progression")
	old_save.rpg.erase("pending_exp")
	for state in old_save.rpg.history: state.erase("pending_exp")
	check(Saves.validate(old_save).ok,"legacy battle defaults to level one and no invented EXP")
	var invalid_level = level.duplicate(true)
	invalid_level.enemyLevels[0] = 21
	check(not Mission.validate(invalid_level).is_empty(),"invalid enemy level rejected")
	print("Progression: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
