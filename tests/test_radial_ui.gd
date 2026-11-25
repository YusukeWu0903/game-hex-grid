extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
var app
var count = 0
var failures: Array[String] = []
var output = ""

func check(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")

func click_at(point: Vector2, mouse_button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var down = InputEventMouseButton.new()
	down.button_index = mouse_button
	down.position = point
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up = InputEventMouseButton.new()
	up.button_index = mouse_button
	up.position = point
	up.pressed = false
	root.push_input(up, true)
	await process_frame

func click_action(id: String) -> void:
	await process_frame
	await click_at(app.radial_actions.buttons[id].get_global_rect().get_center())

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"screenshot " + name)

func check_menu_inside(label: String) -> void:
	await process_frame
	await process_frame
	var bounds = app.board.get_global_rect()
	for id in app.radial_actions.ORDER:
		check(bounds.encloses(app.radial_actions.buttons[id].get_global_rect()),label+" "+id+" remains clickable on board")

func run() -> void:
	output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if output.is_empty():
		quit(2)
		return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.level.mapId = "map_tutorial"
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	var p = app.battle.get_unit("player_swordsman_01")
	# Controlled center fixture permits clear directional assertions.
	p.cell = Vector3i.ZERO
	await process_frame
	await click_at(app.board.global_position+app.board.position_of(p.cell))
	check(app.selection == p.id and app.action_mode == "COMMAND","clicking unit opens command selection")
	check(app.radial_actions.visible,"ring visible")
	check(app.board.reachable.is_empty() and app.board.target_cells.is_empty(),"commands precede target overlays")
	var center = app.radial_actions.ring_center
	var buttons = app.radial_actions.buttons
	check(buttons.MOVE.position.y < center.y and absf(buttons.MOVE.position.x+27-center.x) < 1,"move above unit")
	check(buttons.ATTACK.position.x > center.x and buttons.ATTACK.position.y < center.y,"attack upper right")
	check(buttons.SKILL.position.x > center.x and buttons.SKILL.position.y > center.y,"skill lower right")
	check(buttons.WAIT.position.x < center.x and buttons.WAIT.position.y > center.y,"wait lower left")
	check(buttons.CANCEL.position.x < center.x and buttons.CANCEL.position.y < center.y,"cancel upper left")
	for id in app.radial_actions.ORDER:
		check(buttons[id].text.is_empty(),"icon-only command "+id)
	check(not app.sidebar.get_children().any(func(child):return child is Button and child.text in ["移動","待機","取消選取"]),"no sidebar action duplicates")
	await capture("radial-01-center")
	await click_action("MOVE")
	check(app.action_mode == "MOVE" and not app.radial_actions.visible,"move click collapses ring")
	check(not p.moved and p.cell == Vector3i.ZERO,"command click never leaks into board movement")
	check(not app.board.reachable.is_empty(),"move displays reachable area")
	await key(KEY_ESCAPE)
	check(app.action_mode == "COMMAND" and app.radial_actions.visible,"escape returns from movement targeting")
	await click_action("ATTACK")
	check(app.action_mode == "ATTACK" and not app.radial_actions.visible,"attack collapses ring")
	await click_at(app.board.global_position+app.board.position_of(p.cell),MOUSE_BUTTON_RIGHT)
	check(app.action_mode == "COMMAND" and not p.acted,"right click returns without waiting")
	await click_action("SKILL")
	check(app.action_mode == "SKILL" and not app.radial_actions.visible,"skill collapses ring")
	await key(KEY_ESCAPE)
	await capture("radial-02-returned")
	await key(KEY_M)
	check(app.action_mode == "MOVE","M shortcut")
	var destination = Vector3i(1,-1,0)
	await click_at(app.board.global_position+app.board.position_of(destination))
	check(app.busy and not app.radial_actions.visible,"menu hidden during movement")
	await create_timer(0.8).timeout
	check(p.cell == destination and p.moved,"selected unit moved")
	check(app.action_mode == "COMMAND" and app.radial_actions.visible,"menu reopens after moving")
	check(app.radial_actions.anchor_cell == destination,"ring follows new cell")
	check(buttons.MOVE.disabled,"used movement disabled")
	await click_action("MOVE")
	check(app.action_mode == "COMMAND" and p.cell == destination,"disabled move does not activate or leak")
	p.mp = 0
	app.battle_ui()
	check(buttons.SKILL.disabled and buttons.SKILL.tooltip_text.contains("MP 不足"),"disabled skill explains cost")
	await click_action("SKILL")
	check(app.action_mode == "COMMAND" and p.mp == 0 and not p.acted,"disabled skill is inert")
	var motion = InputEventMouseMotion.new()
	motion.position = buttons.SKILL.get_global_rect().get_center()
	root.push_input(motion, true)
	await create_timer(0.8).timeout
	await capture("radial-03-disabled")
	await click_action("CANCEL")
	check(app.selection.is_empty() and not app.radial_actions.visible and not p.acted,"cancel icon deselects without waiting")
	# Opposite and intermediate placements, plus zoom and resize.
	for fixture in [
		["left",Vector3i(-4,4,0)],
		["right",Vector3i(4,-4,0)],
		["top",Vector3i(0,4,-4)],
		["bottom",Vector3i(0,-4,4)],
		["middle",Vector3i.ZERO]]:
		p.cell = fixture[1]
		p.moved = false
		p.mp = 20
		app.select_unit(p.id)
		await check_menu_inside(fixture[0])
		if fixture[0] in ["left","right"]:
			await capture("radial-04-"+fixture[0])
	app.board.zoom = 1.5
	p.cell = Vector3i(-4,4,0)
	app.select_unit(p.id)
	await check_menu_inside("zoomed left")
	await capture("radial-05-zoom")
	root.size = Vector2i(1100,720)
	await check_menu_inside("small viewport")
	await capture("radial-06-small")
	root.size = Vector2i(1440,900)
	app.board.zoom = 1.0
	p.cell = Vector3i.ZERO
	app.select_unit(p.id)
	await process_frame
	await click_action("WAIT")
	check(p.acted and app.selection.is_empty() and not app.radial_actions.visible,"wait acts once and closes ring")
	var another = app.battle.get_unit("player_swordsman_02")
	app.select_unit(another.id)
	app.end_turn()
	check(not app.radial_actions.visible and app.busy,"enemy phase hides command menu")
	app.show_menu()
	await create_timer(0.8).timeout
	check(not app.radial_actions.visible,"menu remains hidden outside battle")
	print("RADIAL_UI_TESTS: %d checks, %d failures" % [count,failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
