extends SceneTree
const Generator = preload("res://core/map_generator.gd")
var app
var results = {}
func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")
func sample(name: String, moving: bool, zoom_value: float) -> void:
	app.board.zoom = zoom_value
	app.board.zoom_target = zoom_value
	await create_timer(0.6).timeout
	var frames = []
	var cpu = []
	var draws = []
	var memory = []
	var previous = Time.get_ticks_usec()
	for i in range(180):
		if moving: app.board.camera_target=Vector2(sin(i*0.035)*650,cos(i*0.035)*400)
		await process_frame
		var now = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		memory.append(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)
	frames.sort()
	cpu.sort()
	results[name] = {"frame_p50_ms":frames[90],"frame_p95_ms":frames[171],"frame_max_ms":frames[-1],"process_p95_ms":cpu[171],"draw_calls_max":draws.max(),"godot_static_mib_max":memory.max(),"video_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var before = Time.get_ticks_msec()
	var map = Generator.generate(24,20261125,0.45)
	results["generation_ms"] = Time.get_ticks_msec()-before
	app.open_map_editor(map)
	app.board.edge_scroll_enabled = false
	app.performance_label.visible = true
	await sample("idle",false,1.0)
	await sample("pan_normal",true,1.0)
	await sample("pan_zoom_out",true,0.45)
	var path = OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("performance.json")
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path.get_base_dir().path_join("performance.png"))
	print(JSON.stringify(results))
	app.queue_free()
	await process_frame
	quit()
