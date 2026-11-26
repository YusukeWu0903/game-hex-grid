extends SceneTree
const MissionUI = preload("res://ui/mission_ui.gd")
const Catalog = preload("res://core/catalog.gd")
var app
var checks = 0
var failures = 0
var directory: String
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")
func find_button(caption: String):
	for child in app.sidebar.get_children():
		if child is BaseButton and child.text.begins_with(caption): return child
	return null
func click(caption: String) -> void:
	var button = find_button(caption)
	check(button!=null,"button exists "+caption)
	if button==null: return
	await process_frame
	app.sidebar.get_parent().ensure_control_visible(button)
	await process_frame
	var at = button.get_global_rect().get_center()
	var move = InputEventMouseMotion.new()
	move.position = at
	root.push_input(move,true)
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png"))==OK,"capture "+name)
func run() -> void:
	directory = OS.get_environment("HEX_TACTICS_TEST_DIR")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var level = app.store.levels.filter(func(l): return l.levelId=="mission_survive")[0]
	MissionUI.open(app,level)
	await process_frame
	check(app.mode=="SQUAD" and app.squad_ids.size()==5,"five preselected from eight")
	check(find_button("米菈").disabled and find_button("艾爾").disabled,"protected and required selections locked")
	await click("諾亞")
	check(app.squad_ids.size()==5 and not app.squad_ids.has("player_archer_02"),"over-limit click rejected")
	await click("羅伊")
	await click("諾亞")
	check(app.squad_ids.has("player_archer_02") and not app.squad_ids.has("player_swordsman_02"),"reserve replaces selected unit")
	await capture("mission-squad")
	await click("確認出戰並部署")
	check(app.mode=="DEPLOYMENT" and app.battle.allowed_ids.has("player_archer_02"),"confirmed squad reaches deployment")
	app.battle.auto_deploy()
	app.start_battle()
	check(app.mode=="BATTLE" and app.battle.mission.winCondition=="SURVIVE","mission enters combat")
	app.save_battle()
	check(app.current_notice.contains("已儲存"),"mission save succeeds")
	app.show_menu()
	app.load_battle()
	check(app.battle.mission.protectedIds.has("player_mage_01") and app.battle.allowed_ids.has("player_archer_02"),"UI load restores mission and squad")
	app.battle.get_unit("player_mage_01").hp = 0
	app.battle.settle()
	app.after_action()
	check(app.mode=="RESULT" and app.battle.result_reason.contains("米菈"),"protected failure displayed")
	await capture("mission-protected-failure")
	app.rewind_battle(1)
	check(app.mode=="BATTLE" and not app.battle.get_unit("player_mage_01").is_empty(),"UI rewind restores protected unit")
	var reach = app.store.levels.filter(func(l): return l.levelId=="mission_reach")[0]
	app.open_level_editor(reach)
	await process_frame
	var goal_input
	var win_picker
	for child in app.sidebar.get_children():
		if child is LineEdit and child.text=="0,0,0": goal_input = child
		if child is OptionButton and child.item_count==preload("res://core/mission_rules.gd").TYPES.size() and child.get_item_text(0)=="敵方全滅": win_picker = child
	check(goal_input!=null and win_picker!=null,"objective editor controls available")
	goal_input.text="0,1,-1"
	goal_input.text_changed.emit(goal_input.text)
	check(app.editing_level.goalCell==[0,1,-1],"coordinate editor updates rule")
	check(app.board.objective_cells.has("0,1,-1") and not app.board.objective_cells.has("0,0,0"),"coordinate marker updates immediately")
	app.editing_level.levelId="mission_ui_custom"
	app.save_level()
	check(app.current_notice.contains("已儲存"),"custom objective saved")
	app.sidebar.get_parent().ensure_control_visible(goal_input)
	await capture("mission-editor")
	MissionUI.open(app,reach)
	await click("確認出戰並部署")
	app.battle.auto_deploy()
	app.start_battle()
	check(app.board.objective_cells.has("0,0,0"),"reach cell marked on board")
	await capture("mission-reach-board")
	var target_level = app.store.levels.filter(func(l): return l.levelId=="mission_target")[0]
	app.begin_deployment(target_level,{},target_level.playerIds.slice(0,5))
	check(app.board.objective_roles.get("enemy_3","").contains("目標"),"target enemy visibly marked")
	await capture("mission-target-board")
	root.size = Vector2i(1100,720)
	MissionUI.open(app,level)
	await capture("mission-small-squad")
	app.queue_free()
	await process_frame
	print("MISSION_UI_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
