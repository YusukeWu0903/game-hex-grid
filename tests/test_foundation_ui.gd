extends SceneTree
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
func mouse(at: Vector2, index: int, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = at
	event.button_index = index
	event.pressed = pressed
	root.push_input(event,true)
	await process_frame
func click(at: Vector2, index: int = MOUSE_BUTTON_LEFT) -> void:
	await mouse(at,index,true)
	await mouse(at,index,false)
func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event,true)
	await process_frame
func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run() -> void:
	output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.combat_cinematics = false
	app.level.mapId = "map_tutorial"
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	await process_frame
	var enemy = app.battle.units.filter(func(u): return u.faction=="ENEMY")[0]
	await click(app.board.global_position+app.board.position_of(enemy.cell))
	check(app.inspected_id == enemy.id,"real enemy click opens inspection")
	await capture("foundation-01-enemy-inspection")
	await key(KEY_ESCAPE)
	check(app.inspected_id.is_empty(),"Esc closes inspection")
	await key(KEY_T)
	check(app.show_all_threats and not app.board.threat_cells.is_empty(),"T enables all threats")
	await capture("foundation-02-threats")
	await key(KEY_T)
	check(not app.show_all_threats and app.board.threat_cells.is_empty(),"T disables all threats")
	var player = app.battle.get_unit("player_swordsman_01")
	await click(app.board.global_position+app.board.position_of(player.cell))
	check(app.selection == player.id and app.radial_actions.visible,"player command after inspection")
	await key(KEY_F)
	check(app.board.position_of(player.cell).distance_to(app.board.size*Vector2(0.5,0.49))<1,"F focuses selected player")
	await key(KEY_HOME)
	check(app.board.pan_offset==Vector2.ZERO and app.board.zoom==1,"Home resets camera")
	var old_units = app.battle.units.duplicate(true)
	var start = app.board.global_position+Vector2(120,app.board.size.y-70)
	await mouse(start,MOUSE_BUTTON_MIDDLE,true)
	var motion = InputEventMouseMotion.new()
	motion.position = start+Vector2(100,-40)
	motion.relative = Vector2(100,-40)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(motion,true)
	await process_frame
	await mouse(motion.position,MOUSE_BUTTON_MIDDLE,false)
	check(app.board.pan_offset==Vector2(100,-40),"middle drag pans board")
	check(app.battle.units==old_units,"panning never spends movement")
	check(app.radial_actions.unit_center.distance_to(app.board.position_of(player.cell))<1,"ring tracks panned unit")
	await capture("foundation-03-panned")
	await click(app.board.global_position+app.board.position_of(enemy.cell))
	check(app.inspected_id==enemy.id,"panned mouse picking selects correct enemy")
	await key(KEY_F)
	check(app.board.position_of(enemy.cell).distance_to(app.board.size*Vector2(0.5,0.49))<1,"F focuses inspected enemy")
	root.size=Vector2i(1100,720)
	await capture("foundation-04-small")
	await key(KEY_HOME)
	await key(KEY_ESCAPE)
	root.size=Vector2i(1440,900)
	await process_frame
	app.select_unit(player.id)
	app.choose_action("MOVE")
	var routes = app.battle.reachable(player.id)
	var destination = player.cell
	for cell_key in routes.costs:
		if routes.costs[cell_key]==2:
			destination = app.Hex.cell(cell_key)
			break
	await click(app.board.global_position+app.board.position_of(destination))
	check(app.busy,"movement animation begins")
	root.size=Vector2i(1100,720)
	await capture("foundation-06-moving-resize")
	await create_timer(0.5).timeout
	check(not app.busy and player.cell==destination and player.moved,"resize during movement preserves destination and action")
	check(app.board.visual_positions.is_empty() and app.radial_actions.visible,"movement cleanup restores ring after resize")
	app.choose_action("MOVE")
	check(app.action_mode=="COMMAND","already moved cannot re-enter move mode")
	await key(KEY_F1)
	check(app.help_dialog.visible,"F1 opens in-game rules")
	await capture("foundation-05-help")
	app.help_dialog.hide()
	await process_frame
	var save_key = InputEventKey.new()
	save_key.keycode = KEY_S
	save_key.ctrl_pressed = true
	save_key.pressed = true
	root.push_input(save_key,true)
	await process_frame
	if app.confirm_dialog.visible:
		app.confirm_dialog.confirmed.emit()
		app.confirm_dialog.hide()
	check(FileAccess.file_exists(app.battle_save_path()),"Ctrl S saves battle instead of choosing skill")
	app.combat_cinematics=true
	app.cinematic.set_process(false)
	var old_hp = player.hp
	app.cinematic.begin(enemy,player,app.Catalog.action(enemy),3,maxi(0,old_hp-3),false)
	app.busy=true
	await key(KEY_SPACE)
	check(not app.cinematic.active,"Space skips cinematic through actual input")
	check(player.hp==old_hp,"standalone presentation does not mutate battle")
	app.cinematic.begin(enemy,player,app.Catalog.action(enemy),3,maxi(0,old_hp-3),false)
	await click(app.cinematic.skip_button.get_global_rect().get_center())
	check(not app.cinematic.active,"skip button works through actual mouse input")
	app.busy=false
	app.show_menu()
	app.audio.player.stop()
	app.queue_free()
	await create_timer(0.2).timeout
	print("FOUNDATION_UI_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
