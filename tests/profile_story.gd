extends SceneTree
var app
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var level = app.store.levels.filter(func(l): return l.levelId=="mission_story")[0]
	app.begin_deployment(level)
	app.battle.auto_deploy()
	app.start_battle()
	app.story_overlay.reveal()
	app.story_overlay.advance()
	await create_timer(0.6).timeout
	var times = []
	var memory = []
	var previous = Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now = Time.get_ticks_usec()
		times.append(float(now-previous)/1000.0)
		previous = now
		memory.append(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)
	times.sort()
	var result = {"frame_p95_ms":times[171],"frame_median_ms":times[90],"godot_static_mib_max":memory.max(),"video_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"portrait_cache_entries":app.story_overlay.cache.size()}
	app.story_overlay.finish()
	await process_frame
	result.cache_released = app.story_overlay.cache.is_empty() and app.story_overlay.portrait.texture==null
	var file = FileAccess.open(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("performance-story.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print(JSON.stringify(result))
	app.queue_free()
	await process_frame
	quit()
