extends SceneTree
const MissionUI = preload("res://ui/mission_ui.gd")
const RPGUI = preload("res://ui/rpg_ui.gd")
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
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.party.progression = {"player_mage_01":100,"player_knight_01":225}
	app.party_selected = "player_mage_01"
	RPGUI.show_party(app)
	await capture("level-party")
	var level = app.store.levels[1].duplicate(true)
	MissionUI.open(app,level)
	var labels = ""
	for child in app.sidebar.get_children():
		if child is CheckBox: labels += child.text
	check(labels.contains("米菈 Lv.2") and labels.contains("雷昂 Lv.3"),"squad displays individual level")
	await capture("level-squad")
	app.open_level_editor(level)
	var spin
	for row in app.sidebar.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is SpinBox and child.prefix=="Lv.": spin = child; break
		if spin!=null: break
	check(spin!=null,"enemy level control")
	spin.value = 5
	check(app.editing_level.enemyLevels[0]==5,"editor changes enemy level")
	level = app.editing_level.duplicate(true)
	app.sidebar.get_parent().ensure_control_visible(spin)
	await capture("level-editor")
	app.begin_deployment(level)
	app.battle.auto_deploy()
	app.start_battle()
	check(app.battle.get_unit("player_mage_01").level==2 and app.battle.get_unit("enemy_0").level==5,"UI deployment applies party and enemy levels")
	app.save_battle()
	check(app.current_notice.contains("已儲存"),"leveled battle saves")
	app.show_menu()
	app.load_battle()
	check(app.battle.get_unit("player_mage_01").level==2 and app.battle.get_unit("enemy_0").level==5,"UI resume keeps levels")
	app.battle.pending_exp.player_mage_01 = 275
	app.battle.phase = "RESULT"
	app.battle.result = "VICTORY"
	app.battle.result_reason = "測試戰役完成。"
	app.after_action()
	check(app.party.progression.player_mage_01==375 and app.battle.settled,"UI atomic claim levels mage to four")
	await capture("level-victory")
	root.size = Vector2i(1100,720)
	await capture("level-small-victory")
	app.show_menu()
	app.load_battle()
	check(app.current_notice.contains("已結算"),"UI rejects old snapshot after settlement")
	app.begin_deployment(level)
	app.battle.auto_deploy()
	check(app.battle.get_unit("player_mage_01").level==4 and app.battle.get_unit("player_mage_01").hp==app.battle.get_unit("player_mage_01").max_hp,"next deployment uses new level and full HP")
	app.queue_free()
	await process_frame
	print("Progression UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
