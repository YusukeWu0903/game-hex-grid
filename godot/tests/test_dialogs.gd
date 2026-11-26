extends SceneTree
var app
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	call_deferred("run")
func click(viewport: Viewport, at: Vector2) -> void:
	var motion=InputEventMouseMotion.new()
	motion.position=at
	viewport.push_input(motion,true)
	var down=InputEventMouseButton.new()
	down.position=at
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	viewport.push_input(down,true)
	await process_frame
	var up=InputEventMouseButton.new()
	up.position=at
	up.button_index=MOUSE_BUTTON_LEFT
	viewport.push_input(up,true)
	await process_frame
func click_dialog_button(button: Button) -> void:
	await process_frame
	await process_frame
	var window = button.get_window()
	await click(root,Vector2(window.position)+button.get_global_rect().get_center())
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.combat_cinematics=false
	app.reduced_motion=true
	app.level.mapId="map_tutorial"
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	var p=app.battle.get_unit("player_swordsman_01")
	app.select_unit(p.id)
	app.choose_action("MOVE")
	var before=app.battle.units.duplicate(true)
	app.show_help()
	await process_frame
	await click_dialog_button(app.help_dialog.get_ok_button())
	check(not app.help_dialog.visible,"rules return button closes actual dialog")
	if app.help_dialog.visible:
		app.help_dialog.hide()
		app.queue_free()
		await create_timer(0.2).timeout
		quit(1)
		return
	check(app.battle.units==before and app.action_mode=="MOVE","opening help preserves pending command")
	app.confirm("讓剩餘角色待機？",app.end_turn)
	await process_frame
	await click(root,app.board.global_position+app.board.position_of(Vector3i(-4,2,2)))
	check(app.confirm_dialog.visible,"exclusive confirmation remains open after background click")
	check(app.battle.units==before,"modal blocks background movement input")
	await click_dialog_button(app.confirm_dialog.get_cancel_button())
	check(not app.confirm_dialog.visible,"cancel button closes confirmation")
	check(app.battle.units==before and app.battle.turn==1,"cancel confirmation spends no actions")
	app.save_battle()
	var saved=FileAccess.get_file_as_string(app.battle_save_path())
	p.mp=5
	app.request_save_battle()
	check(app.confirm_dialog.visible,"overwrite requires concrete confirmation")
	await click_dialog_button(app.confirm_dialog.get_cancel_button())
	check(FileAccess.get_file_as_string(app.battle_save_path())==saved,"cancel overwrite preserves original bytes")
	app.request_save_battle()
	await click_dialog_button(app.confirm_dialog.get_ok_button())
	check(FileAccess.get_file_as_string(app.battle_save_path())!=saved,"confirm overwrite writes new progress")
	check(FileAccess.get_file_as_string(app.battle_save_path()+".bak")==saved,"overwrite backup is exact prior save")
	app.confirm("讓剩餘角色待機？",app.end_turn)
	await click_dialog_button(app.confirm_dialog.get_ok_button())
	await create_timer(0.1).timeout
	check(app.battle.turn==2 and app.battle.phase=="PLAYER","confirm end turn advances and returns to player")
	app.show_menu()
	app.audio.player.stop()
	app.queue_free()
	await create_timer(0.2).timeout
	print("DIALOG_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
