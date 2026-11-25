extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
const Generator = preload("res://core/map_generator.gd")
var app
var checks = 0
var failures = 0
var output = ""
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text==title: return node
	for child in node.get_children():
		var result = find_button(child,title)
		if result!=null: return result
	return null
func press_button(title: String) -> void:
	await process_frame
	await process_frame
	var button = find_button(app.sidebar,title)
	check(button!=null,"editor exposes "+title)
	if button==null: return
	var ancestor = button.get_parent()
	while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
	if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
	await process_frame
	await process_frame
	await click(button.get_global_rect().get_center())
func run() -> void:
	output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.open_map_editor(Generator.generate(24,20261125))
	app.board.edge_scroll_enabled = false
	await capture("world-01-center")
	check(app.board.hex_size()>25,"large map preserves readable hexes")
	for cell in [Vector3i(-24,24,0),Vector3i(24,-24,0),Vector3i.ZERO]:
		app.board.focus_cell(cell)
		await create_timer(0.9).timeout
		check(app.board.position_of(cell).distance_to(app.board.size*Vector2(0.5,0.49))<1,"camera focuses opposite edges and center")
		check(Hex.from_pixel(app.board.position_of(cell)-app.board.center(),app.board.hex_size())==cell,"world screen picking roundtrip")
		app.brush = "FOREST"
		await click(app.board.global_position+app.board.position_of(cell))
		check(app.editing_map.terrains.get(Hex.key(cell))=="FOREST","real click edits focused cell")
		await capture("world-edge-%d" % cell.x)
	app.board.zoom_target=0.45
	await create_timer(0.9).timeout
	check(absf(app.board.zoom-0.45)<0.001,"minimum zoom")
	await capture("world-02-zoom-out")
	app.board.zoom_target=2.0
	await create_timer(0.9).timeout
	check(absf(app.board.zoom-2.0)<0.001,"maximum zoom")
	await capture("world-03-zoom-in")
	var mini = app.board.minimap_rect()
	await click(app.board.global_position+mini.get_center()+Vector2(45,0))
	await create_timer(0.9).timeout
	check(app.board.pan_offset.x< -1000,"minimap seeks to far right map region")
	await capture("world-04-minimap")
	app.board.reset_camera()
	var original = app.editing_map.duplicate(true)
	app.editor_radius = 6
	await press_button("一鍵生成預覽")
	check(app.board.map.radius==6 and app.editing_map==original,"generation preview leaves editor draft unchanged")
	await capture("world-07-generator-preview")
	await press_button("套用生成結果")
	check(app.editing_map.radius==6 and app.generator_preview.is_empty(),"apply preview changes draft")
	await press_button("復原 Ctrl+Z")
	check(app.editing_map==original,"undo generation restores full previous draft")
	app.editor_radius = 2
	await press_button("套用尺寸（可復原）")
	check(app.editing_map.radius==2 and Hex.validate_map(app.editing_map).is_empty(),"resize button crops safely")
	await press_button("復原 Ctrl+Z")
	check(app.editing_map==original,"undo resize restores full previous draft")
	for d in Hex.DIRECTIONS: app.editing_map.terrains[Hex.key(d)]="PLAIN"
	app.brush = "WATER"
	app.paint_cell(Vector3i.ZERO)
	app.stroke_active = false
	app.validate_editor_map()
	check(not app.board.invalid_cells.is_empty(),"editor highlights invalid cluster")
	var library = app.store.maps.duplicate(true)
	app.save_map()
	check(app.store.maps==library,"invalid draft cannot overwrite library")
	await capture("world-05-validation")
	app.editing_map = app.map_editor.undo(app.editing_map)
	app.render_map_editor()
	check(app.editing_map.terrains.get("0,0,0")=="FOREST","editor undo restores previous terrain")
	root.size=Vector2i(1100,720)
	await capture("world-06-small-window")
	check(app.board.minimap_rect().end.x<=app.board.size.x,"minimap fits smaller window")
	app.queue_free()
	await process_frame
	print("World UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
