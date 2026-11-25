extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
var app
var failures: Array[String] = []
var count = 0
var output_dir = ""

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var err = root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
		check(err == OK,"capture " + name)

func press_button(text: String) -> bool:
	for child in app.sidebar.get_children():
		if child is Button and child.text == text:
			await process_frame
			var position = child.get_global_rect().get_center()
			var motion = InputEventMouseMotion.new()
			motion.position = position
			root.push_input(motion, true)
			var down = InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.position = position
			down.pressed = true
			root.push_input(down, true)
			await process_frame
			var up = InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.position = position
			up.pressed = false
			root.push_input(up, true)
			await process_frame
			return true
	return false

func run() -> void:
	output_dir = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if output_dir.is_empty():
		quit(2)
		return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.mode == "MENU","menu opens")
	await capture("01-menu")
	check(await press_button("開始部署"),"deployment button wired")
	check(app.mode == "DEPLOYMENT","deployment opens")
	check(await press_button("自動部署"),"auto deploy button wired")
	await capture("02-deployment")
	app.start_battle()
	check(app.mode == "BATTLE" and app.battle.phase == "PLAYER","battle starts")
	var p = app.battle.units.filter(func(u):return u.faction == "PLAYER")[0]
	app.select_unit(p.id)
	await capture("03-movement")
	app.choose_action("MOVE")
	var search = app.battle.reachable(p.id)
	var destination = p.cell
	for key in search.costs:
		if search.costs[key] == 1:
			destination = Hex.cell(key)
			break
	app.on_cell_clicked(destination,MOUSE_BUTTON_LEFT)
	check(app.busy,"animation locks input immediately")
	var revision_cell: Vector3i = p.cell
	app.on_cell_clicked(p.cell,MOUSE_BUTTON_LEFT)
	check(p.cell == revision_cell,"rapid click cannot start another move")
	await create_timer(0.8).timeout
	check(not app.busy and p.moved,"movement completes")
	app.cancel_selection()
	check(not p.acted and p.moved,"cancel does not wait or undo movement")
	app.select_unit(p.id)
	check(app.move_button.disabled,"move disabled after moving")
	p.mp = 0
	app.battle_ui()
	check(app.skill_button.disabled,"insufficient MP skill visibly disabled")
	app.choose_action("SKILL")
	check(app.action_mode != "SKILL","insufficient MP cannot select skill")
	await capture("04-actions")
	# Actual attack flow after a controlled range setup.
	p.mp = 20
	p.acted = false
	p.cell = Vector3i.ZERO
	var target = app.battle.units.filter(func(u): return u.faction == "ENEMY")[0]
	target.cell = Vector3i(1,-1,0)
	var old_hp = target.hp
	app.select_unit(p.id)
	app.choose_action("SKILL")
	app.on_cell_hovered(target.cell)
	await capture("10-skill-preview")
	app.on_cell_clicked(target.cell,MOUSE_BUTTON_LEFT)
	check(p.mp == 10 and target.hp == old_hp-7 and p.acted,"UI skill consumes MP and action exactly once")
	app.on_cell_clicked(target.cell,MOUSE_BUTTON_LEFT)
	check(p.mp == 10 and target.hp == old_hp-7,"repeat target click cannot attack again")
	await capture("11-damage-feedback")
	app.show_menu()
	check(app.battle.phase == "MENU" and not app.busy,"menu clears active battle")
	# Interrupt enemy flow with animation active, then start a new battle.
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	app.end_turn()
	check(app.busy and app.battle.phase == "ENEMY","enemy flow locks player")
	app.show_menu()
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	await create_timer(1.0).timeout
	check(app.battle.turn == 1 and app.battle.phase == "PLAYER" and not app.busy,"old callbacks cannot alter restarted battle")
	# Exercise actual result UI for both terminal outcomes.
	for u in app.battle.units:
		if u.faction == "ENEMY": u.hp = 0
	app.battle.settle()
	app.after_action()
	check(app.mode == "RESULT" and app.battle.result == "VICTORY","victory UI")
	await capture("05-victory")
	check(await press_button("重新部署"),"retry button wired")
	check(app.battle.phase == "DEPLOYMENT" and app.battle.turn == 1,"retry returns deployment")
	app.battle.auto_deploy()
	app.start_battle()
	for u in app.battle.units:
		if u.faction == "PLAYER": u.hp = 0
	app.battle.settle()
	app.after_action()
	check(app.mode == "RESULT" and app.battle.result == "DEFEAT","defeat UI")
	await capture("06-defeat")
	app.show_menu()
	app.open_level_editor(app.level)
	check(app.mode == "LEVEL_EDITOR","level editor")
	await capture("07-level-editor")
	app.open_map_editor(app.store.map_by_id("map_tutorial"))
	app.brush = "FOREST"
	app.on_cell_clicked(Vector3i.ZERO,MOUSE_BUTTON_LEFT)
	check(app.editing_map.terrains["0,0,0"] == "FOREST","terrain brush")
	check(not app.store.map_by_id("map_tutorial").terrains.has("0,0,0"),"editor changes isolated until save")
	app.brush = "PLAYER"
	app.paint_cell(Vector3i.ZERO)
	app.brush = "WATER"
	app.paint_cell(Vector3i.ZERO)
	check(not app.editing_map.spawnPoints.has("0,0,0"),"blocked terrain clears spawn")
	app.brush = "ENEMY"
	app.paint_cell(Vector3i.ZERO)
	check(not app.editing_map.spawnPoints.has("0,0,0"),"blocked spawn rejected")
	await capture("08-map-editor")
	# Resizing smoke at the minimum supported window.
	root.size = Vector2i(1100,720)
	await capture("09-small-window")
	app.show_menu()
	check(not app.store.map_by_id("map_tutorial").terrains.has("0,0,0"),"cancel map edit preserves original")
	print("UI_TESTS: %d checks, %d failures" % [count,failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
