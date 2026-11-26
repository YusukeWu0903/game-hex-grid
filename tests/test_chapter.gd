extends SceneTree
const Store = preload("res://core/data_store.gd")
const Session = preload("res://core/battle_session.gd")
const Story = preload("res://core/story_dialogue.gd")
const Saves = preload("res://core/battle_save.gd")
const Party = preload("res://core/party_store.gd")
const Mission = preload("res://core/mission_rules.gd")
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
	var s = Session.new()
	var ids = level.playerIds.slice(0,5)
	check(s.prepare(store.map_by_id(level.mapId),ids,level.enemyIds,level).is_empty(),"prepare")
	s.auto_deploy()
	check(s.start().is_empty(),"start")
	s.get_unit(ids[0]).cell = Vector3i.ZERO
	return s
func remove_enemies(s) -> void:
	for unit in s.units:
		if unit.faction=="ENEMY": unit.hp=0
	s.settle()
func _initialize() -> void:
	var dir = OS.get_environment("HEX_TACTICS_TEST_DIR")
	store = Store.new(dir.path_join("chapter-library.json"))
	level = store.levels.filter(func(l): return l.levelId=="chapter_treasure")[0]
	check(store.validate_level(level).is_empty(),"chapter validates")
	var s = fixture()
	check(s.open_chest(s.allowed_ids[0],Vector3i.ZERO),"open real chest")
	check(s.pending_loot.get("border_relic")==1 and s.result.is_empty(),"treasure guaranteed, enemies still block win")
	var lines = Story.collect(s)
	check(lines.size()==2 and lines[0].id=="chapter_c01","chest section")
	check(Story.collect(s).is_empty(),"chest once")
	check(s.rewind_to(1),"rewind before chest")
	check(s.opened_chests.is_empty() and not s.pending_loot.has("border_relic") and not s.story.seen.has("chapter_open"),"rewind all treasure state")
	s.get_unit(s.allowed_ids[0]).cell = Vector3i.ZERO
	remove_enemies(s)
	check(s.result.is_empty(),"all enemies dead is not enough")
	var save = Saves.validate(Saves.snapshot(s,level))
	check(save.ok,"save after all enemies dead before chest")
	check(s.open_chest(s.allowed_ids[0],Vector3i.ZERO) and s.result=="VICTORY","chest last wins")
	check(Story.collect(s).size()==2,"chest story still triggers after victory")
	var party = Party.new(dir.path_join("chapter-party.json"))
	var blocked = Party.new(dir.path_join("chapter-blocked.json"))
	DirAccess.make_dir_recursive_absolute(blocked.path+".tmp")
	check(not blocked.claim(s).is_empty() and not s.settled,"failed settlement does not mark claimed")
	check(blocked.pending_ending.is_empty() and not blocked.inventory.has("border_relic"),"failed settlement changes neither ending nor inventory")
	check(party.claim(s).is_empty() and s.settled,"claim")
	check(party.inventory.get("border_relic")==1 and not party.pending_ending.is_empty(),"reward and pending ending saved together")
	var resumed = Party.new(party.path)
	check(resumed.pending_ending==party.pending_ending,"restart resumes ending")
	check(resumed.claim(s).is_empty() and resumed.inventory.get("border_relic")==1,"claim idempotent")
	var actual_path = resumed.path
	resumed.path = blocked.path
	check(not resumed.finish_ending().is_empty() and not resumed.pending_ending.is_empty(),"failed ending save preserves continuation")
	resumed.path = actual_path
	check(resumed.finish_ending().is_empty(),"finish ending")
	check(Party.new(party.path).pending_ending.is_empty(),"ending completion persists")
	s = fixture()
	s.open_chest(s.allowed_ids[0],Vector3i.ZERO)
	remove_enemies(s)
	check(s.result=="VICTORY","enemies last wins")
	s = fixture()
	s.open_chest(s.allowed_ids[0],Vector3i.ZERO)
	Story.collect(s)
	for unit in s.units:
		if unit.faction=="PLAYER": unit.hp=0
	s.settle()
	check(s.result=="DEFEAT" and Story.collect(s)[0].id=="common_d01","common defeat section")
	check(not resumed.claim(s).is_empty() and resumed.inventory.get("border_relic")==1,"defeat awards nothing")
	check(s.rewind_to(1) and s.result.is_empty(),"defeat rewind")
	var invalid = level.duplicate(true)
	invalid.requiredChest = "1,1,-2"
	check(not Mission.validate(invalid,store.map_by_id(level.mapId)).is_empty(),"invalid target chest rejected")
	print("Chapter: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
