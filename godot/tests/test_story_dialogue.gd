extends SceneTree
const Story = preload("res://core/story_dialogue.gd")
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Saves = preload("res://core/battle_save.gd")
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	var store = Store.new(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("story-library.json"))
	var level = store.levels.filter(func(l): return l.levelId == "mission_story")[0]
	var s = Session.new()
	check(s.prepare(store.map_by_id(level.mapId),level.playerIds,level.enemyIds,level).is_empty(),"prepare story")
	s.auto_deploy()
	check(Story.collect(s).is_empty(),"deployment does not trigger")
	check(s.start().is_empty(),"start")
	var opening = Story.collect(s)
	check(opening.size()==4,"opening four lines")
	check(Story.collect(s).is_empty(),"once per event")
	Story.record(s.story,opening[0].id)
	Story.record(s.story,opening[0].id)
	check(s.story.log.size()==1,"deduplicated transcript")
	var snapshot = Saves.snapshot(s,level)
	var loaded = Saves.validate(snapshot)
	check(loaded.ok,"story snapshot validates")
	var restored = Session.new()
	Saves.restore(restored,loaded)
	check(restored.story==s.story and Story.collect(restored).is_empty(),"load retains story without replay")
	snapshot.rpg.story.seen.append("unknown")
	check(not Saves.validate(snapshot).ok,"reject unknown event")
	check(not Story.valid({"seen":[],"log":["border_001"]},"mission_story"),"reject unread event transcript")
	check(s.rewind_to(1),"rewind")
	check(s.story.log.is_empty() and Story.collect(s).size()==4,"rewind replays opening")
	s.turn = 2
	check(Story.collect(s).size()==1 and s.story.seen.has("story_turn"),"specified turn")
	s.get_unit("player_swordsman_01").cell = Vector3i.ZERO
	check(Story.collect(s).size()==1 and s.story.seen.has("story_area"),"enter area")
	s.result = "DEFEAT"
	s.phase = "RESULT"
	check(Story.collect(s).size()==1,"defeat")
	s.story = Story.fresh()
	s.result = "VICTORY"
	check(Story.collect(s).size()==1 and Story.collect(s).is_empty(),"victory once")
	var started = Time.get_ticks_usec()
	for i in range(10000): Story.collect(s)
	print("Story evaluation average us: ",float(Time.get_ticks_usec()-started)/10000.0)
	print("Story: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
