extends SceneTree
const Catalog = preload("res://core/catalog.gd")
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Saves = preload("res://core/battle_save.gd")
const Party = preload("res://core/party_store.gd")
const Rules = preload("res://core/battle_rules.gd")
var checks = 0
var failures = 0
var store
var level
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func fixture():
	var session = Session.new()
	check(session.prepare(store.map_by_id("map_rpg"),level.playerIds,level.enemyIds).is_empty(),"prepare expansion roster")
	session.auto_deploy()
	check(session.start().is_empty(),"start expanded battle")
	session.rng.seed = 31415
	session.history.clear()
	session.capture_round()
	return session
func _initialize() -> void:
	var dir = OS.get_environment("HEX_TACTICS_TEST_DIR")
	store = Store.new(dir.path_join("rpg-library.json"))
	level = store.levels[1]
	var bad_map = store.map_by_id("map_rpg").duplicate(true)
	bad_map.chests[bad_map.chests.keys()[0]] = "missing_table"
	check(not store.save_map(bad_map).is_empty(),"unknown chest table rejected by map save")
	check(not Session.new().prepare(bad_map,level.playerIds,level.enemyIds).is_empty(),"unknown chest table rejected before battle")
	var s = fixture()
	var mage = s.get_unit("player_mage_01")
	var ally = s.get_unit("player_swordsman_01")
	mage.cell = Vector3i.ZERO
	ally.cell = Vector3i(1,-1,0)
	s.get_unit("enemy_0").cell=Vector3i(2,-2,0)
	s.get_unit("enemy_1").cell=Vector3i(2,-1,-1)
	var hp0=s.get_unit("enemy_0").hp
	var hp1=s.get_unit("enemy_1").hp
	var ally_hp=ally.hp
	var hit=s.attack(mage.id,"enemy_0",true)
	check(hit.ok and hit.hits.size()==2,"fire burst hits both nearby enemies")
	check(s.get_unit("enemy_0").hp==hp0-6 and s.get_unit("enemy_1").hp==hp1-6,"magic damage applied to all targets")
	check(mage.mp==20 and mage.acted,"AoE costs MP and action only once")
	check(ally.hp==ally_hp,"AoE never hits allies")
	check(not s.attack(mage.id,"enemy_0",true).ok,"cannot repeat acted skill")
	s=fixture()
	var knight=s.get_unit("player_knight_01")
	check(s.guard_unit(knight.id),"knight uses shield wall")
	check(knight.mp==14 and knight.guard==3 and knight.acted,"guard resource and state")
	check(Rules.damage_for(s.get_unit("enemy_0"),knight,Catalog.action(s.get_unit("enemy_0")))==1,"physical guard mitigates with minimum one")
	s.end_player_turn()
	for unit in s.units: unit.acted=true
	check(s.next_round() and knight.guard==0,"guard expires at next allied round")
	check(s.history.size()==2,"each allied round start is captured")
	check(s.rewind_to(1) and s.history.size()==1,"rewind truncates future")
	check(s.get_unit(knight.id).mp==20 and s.get_unit(knight.id).guard==0,"rewind restores defense and MP")
	check(not s.rewind_to(99),"invalid round rejected")
	s=fixture()
	mage=s.get_unit("player_mage_01")
	ally=s.get_unit("player_swordsman_01")
	mage.cell=Vector3i.ZERO
	ally.cell=Vector3i(1,-1,0)
	var amount=s.inventory.potion
	check(not s.use_item(ally.id,mage.id,"potion"),"full HP item rejected")
	check(s.inventory.potion==amount and not ally.acted,"invalid item has no side effects")
	mage.hp=1
	check(s.use_item(ally.id,mage.id,"potion"),"adjacent ally item")
	check(mage.hp==9 and s.inventory.potion==amount-1 and ally.acted,"item restores and consumes once")
	check(not s.use_item(ally.id,mage.id,"potion"),"acted item use rejected")
	s=fixture()
	ally=s.get_unit("player_swordsman_01")
	ally.cell=Vector3i(1,-1,0)
	s.map.chests={"0,0,0":"wooden"}
	s.history.clear()
	s.capture_round()
	check(s.open_chest(ally.id,Vector3i.ZERO),"adjacent chest opens")
	var bag=s.inventory.duplicate(true)
	var rng_state=s.rng.state
	check(not s.open_chest(ally.id,Vector3i.ZERO),"chest cannot open twice")
	check(s.rewind_to(1) and s.opened_chests.is_empty(),"rewind restores closed chest")
	check(s.open_chest(ally.id,Vector3i.ZERO),"open again after rewind")
	check(s.inventory==bag and s.rng.state==rng_state,"rewind preserves exact random drop outcome")
	var payload=Saves.snapshot(s,level)
	var loaded=Saves.validate(JSON.parse_string(JSON.stringify(payload)))
	check(loaded.ok,"v2 snapshot JSON roundtrip")
	if loaded.ok:
		var resumed=Session.new()
		Saves.restore(resumed,loaded)
		check(resumed.inventory==s.inventory and resumed.history.size()==1,"load restores bag and history")
		check(resumed.rewind_to(1),"loaded history remains rewindable")
		check(resumed.open_chest(ally.id,Vector3i.ZERO) and resumed.inventory==bag,"loaded RNG outcome identical")
	var bad=payload.duplicate(true)
	bad.rpg.inventory.potion=-1
	check(not Saves.validate(bad).ok,"reject negative inventory")
	bad=payload.duplicate(true)
	bad.rpg.history[0].units[0].hp=9999
	check(not Saves.validate(bad).ok,"reject invalid historical unit")
	bad=payload.duplicate(true)
	bad.rpg.history.append(bad.rpg.history[0].duplicate(true))
	check(not Saves.validate(bad).ok,"reject duplicate historical turns")
	s=fixture()
	ally=s.get_unit("player_swordsman_01")
	ally.cell=Vector3i.ZERO
	var target=s.get_unit("enemy_0")
	target.cell=Vector3i(1,-1,0)
	target.hp=1
	var original=Catalog.data().loot_tables.common
	Catalog.data().loot_tables.common=[{"item":"potion","chance":1.0,"min":1,"max":1}]
	amount=s.inventory.potion
	check(s.attack(ally.id,target.id,false).ok,"kill resolves")
	check(s.inventory.potion==amount+1 and s.pending_loot.potion==1,"kill rolls reward once")
	s.settle()
	check(s.inventory.potion==amount+1,"settle repeat cannot duplicate drops")
	Catalog.data().loot_tables.common=original
	var party=Party.new(dir.path_join("party-rpg-%d.json" % Time.get_ticks_usec()))
	check(not party.equip("player_mage_01","weapon","iron_sword").is_empty(),"incompatible weapon rejected")
	check(party.equip("player_knight_01","armor","plate_armor").is_empty(),"valid armor saved")
	var equipped=Catalog.player("player_knight_01",Vector3i.ZERO)
	Catalog.equip_unit(equipped,party.loadouts.player_knight_01)
	check(equipped.defense==4,"equipment stats applied")
	var bank=party.inventory.duplicate(true)
	s.result="DEFEAT";s.phase="RESULT"
	check(not party.claim(s).is_empty() and party.inventory==bank,"defeat never banks loot")
	s.result="VICTORY"
	check(party.claim(s).is_empty() and s.settled,"victory settlement persisted")
	bank=party.inventory.duplicate(true)
	check(party.claim(s).is_empty() and party.inventory==bank,"repeat settlement idempotent")
	check(not s.rewind_to(1),"settled battle cannot rewind")
	var reopened=Party.new(party.path)
	check(reopened.settled_ids.has(s.battle_id) and reopened.inventory==bank,"settlement ledger survives restart")
	print("RPG_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
