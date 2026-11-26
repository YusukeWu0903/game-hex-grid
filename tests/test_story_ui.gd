extends SceneTree
var app
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join(name+".png"))==OK,"capture "+name)
func key(code: Key, echo: bool = false) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var level = app.store.levels.filter(func(l): return l.levelId=="mission_story")[0]
	app.begin_deployment(level)
	app.battle.auto_deploy()
	app.start_battle()
	var d = app.story_overlay
	check(d.visible and app.busy and app.board.camera_locked,"opening owns controls")
	check(not d.nameplate.visible and not d.portrait.visible,"narration")
	key(KEY_SPACE,true)
	check(d.index==0 and d.body.visible_characters!=-1,"held key does not reveal or advance")
	key(KEY_SPACE)
	check(d.index==0 and d.body.visible_characters==-1,"first key reveals")
	key(KEY_SPACE)
	check(d.index==1 and d.nameplate.text=="艾爾","second key advances")
	d.reveal()
	await capture("dialogue-hero")
	d.toggle_history()
	var prior = d.index
	key(KEY_SPACE)
	check(d.index==prior and d.transcript.text.contains("晨霧"),"history blocks advance and shows read lines")
	key(KEY_ESCAPE)
	check(not d.history_panel.visible and d.index==prior,"history resumes same line")
	d.advance()
	d.reveal()
	d.advance()
	d.reveal()
	check(d.portrait.flip_h and d.nameplate.text=="帝國騎士","enemy faces inward")
	await capture("dialogue-enemy")
	root.size = Vector2i(1100,720)
	await capture("dialogue-small")
	d.advance()
	check(not d.visible and not app.busy,"returns to board")
	app.save_battle()
	check(app.current_notice.contains("已儲存"),"save after story")
	app.show_menu()
	app.load_battle()
	check(not d.visible and app.battle.story.log.size()==4,"load preserves read history")
	app.rewind_battle(1)
	check(d.visible and d.index==0 and app.battle.story.log.is_empty(),"rewind replays")
	d.finish()
	check(app.battle.story.log.is_empty() and not d.visible,"skip does not fabricate read lines")
	app.battle.phase = "RESULT"
	app.battle.result = "VICTORY"
	app.after_action()
	check(d.visible and not app.battle.settled,"victory dialogue precedes settlement")
	d.finish()
	check(app.battle.settled and not d.visible,"settles after dialogue")
	var xp = app.party.progression.duplicate(true)
	app.after_action()
	check(app.party.progression==xp,"no duplicate reward")
	app.show_menu()
	check(not d.visible and not d.is_processing() and d.cache.is_empty(),"cancel releases presentation")
	app.queue_free()
	await process_frame
	print("Story UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
