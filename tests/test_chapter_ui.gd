extends SceneTree
const Chapter = preload("res://ui/chapter_flow.gd")
const Party = preload("res://core/party_store.gd")
var app
var level
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	call_deferred("run")
func click(title: String) -> void:
	for child in app.sidebar.get_children():
		if child is Button and child.text==title:
			check(not child.disabled,"enabled "+title)
			child.pressed.emit()
			return
	check(false,"missing "+title)
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join(name+".png"))==OK,"capture "+name)
func kill_enemies() -> void:
	for unit in app.battle.units:
		if unit.faction=="ENEMY": unit.hp=0
	app.battle.settle()
func open_chest() -> void:
	var id = app.battle.allowed_ids[0]
	app.battle.get_unit(id).cell = Vector3i.ZERO
	app.selection = id
	app.action_mode = "CHEST"
	app.on_cell_clicked(Vector3i.ZERO,MOUSE_BUTTON_LEFT)
func deploy() -> void:
	click("確認出戰並部署")
	app.battle.auto_deploy()
	app.refresh_deployment()
	app.start_battle()
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	level = app.store.levels.filter(func(l): return l.levelId=="chapter_treasure")[0]
	Chapter.enter(app,level)
	check(app.mode=="INTRO" and app.board.units.is_empty() and app.busy,"intro before roster")
	check(Chapter.entry(app).stage=="INTRO","intro checkpoint")
	app.story_overlay.reveal()
	app.story_overlay.advance()
	app.story_overlay.reveal()
	await capture("chapter-intro")
	app.story_overlay.finish()
	check(app.mode=="SQUAD" and not app.busy,"intro to roster")
	check(Chapter.entry(app).stage=="SQUAD","roster checkpoint")
	var checkpoint_data = Chapter.entry(app)
	checkpoint_data.ids = ["missing"]
	preload("res://core/battle_save.gd").write_json(Chapter.checkpoint_path(app),checkpoint_data)
	check(Chapter.entry(app).is_empty(),"invalid roster checkpoint rejected")
	Chapter.checkpoint(app,"SQUAD")
	var stamp = FileAccess.get_modified_time(Chapter.checkpoint_path(app))
	await create_timer(1.1).timeout
	Chapter.checkpoint(app,"SQUAD")
	check(FileAccess.get_modified_time(Chapter.checkpoint_path(app))==stamp,"unchanged UI does not rewrite checkpoint")
	click("確認出戰並部署")
	app.battle.auto_deploy()
	app.refresh_deployment()
	var deployed = app.battle.units.duplicate(true)
	app.show_menu()
	Chapter.resume_entry(app)
	check(app.mode=="DEPLOYMENT" and app.battle.units.size()==deployed.size(),"restore exact deployment count")
	for unit in deployed: check(app.battle.get_unit(unit.id).cell==unit.cell,"restore position "+unit.id)
	await capture("chapter-deploy")
	app.start_battle()
	check(app.mode=="BATTLE" and not app.story_overlay.visible,"deployment to battle without repeated intro")
	check(Chapter.entry(app).is_empty(),"prebattle checkpoint consumed")
	open_chest()
	check(app.story_overlay.visible and app.story_overlay.lines[0].id=="chapter_c01","open chest invokes exact event")
	check(not app.party.inventory.has("border_relic") and app.battle.pending_loot.get("border_relic")==1,"chest reward still temporary")
	app.story_overlay.reveal()
	await capture("chapter-chest")
	app.story_overlay.finish()
	check(app.mode=="BATTLE" and not app.busy,"chest story resumes combat")
	for unit in app.battle.units:
		if unit.faction=="PLAYER": unit.hp=0
	app.battle.settle()
	app.after_action()
	check(app.story_overlay.lines[0].id=="common_d01","generic defeat")
	app.story_overlay.finish()
	check(app.mode=="RESULT" and not app.battle.settled,"defeat menu without rewards")
	await capture("chapter-defeat")
	app.rewind_battle(1)
	check(app.mode=="BATTLE" and app.battle.opened_chests.is_empty() and not app.story_overlay.visible,"rewind keeps intro read and resets chest")
	open_chest()
	check(app.story_overlay.visible,"rewind chest story repeats")
	app.story_overlay.finish()
	kill_enemies()
	app.after_action()
	check(app.mode=="RESULT" and app.battle.settled,"victory settlement")
	check(app.party.inventory.get("border_relic")==1,"one treasure awarded")
	await capture("chapter-settlement")
	var stored_party = Party.new(app.party.path)
	check(not stored_party.pending_ending.is_empty(),"atomic ending persisted")
	app.party = stored_party
	app.show_menu()
	click("接續已結算的結尾劇情")
	check(app.mode=="ENDING" and app.story_overlay.lines[0].id=="chapter_o01","resume after settlement")
	app.story_overlay.reveal()
	app.story_overlay.advance()
	app.story_overlay.reveal()
	await capture("chapter-ending")
	app.story_overlay.finish()
	check(app.mode=="MENU" and app.party.pending_ending.is_empty(),"ending exits chapter")
	check(app.party.inventory.get("border_relic")==1,"no double reward")
	Chapter.enter(app,level)
	app.story_overlay.finish()
	deploy()
	kill_enemies()
	app.after_action()
	check(app.mode=="BATTLE" and app.battle.result.is_empty(),"enemy annihilation waits for chest")
	open_chest()
	check(app.story_overlay.visible and not app.battle.settled,"last chest story before settlement")
	app.story_overlay.finish()
	check(app.battle.settled,"last chest then settles")
	click("確認結算，觀看結尾")
	app.story_overlay.finish()
	Chapter.enter(app,level)
	app.story_overlay.finish()
	deploy()
	for unit in app.battle.units:
		if unit.faction=="PLAYER": unit.hp=0
	app.battle.settle()
	app.after_action()
	app.story_overlay.finish()
	click("重新再戰")
	check(app.mode=="SQUAD" and not app.story_overlay.visible,"retry skips intro")
	deploy()
	check(app.battle.turn==1 and app.battle.opened_chests.is_empty(),"retry starts fresh")
	for unit in app.battle.units:
		if unit.faction=="PLAYER": check(unit.hp==unit.max_hp and unit.mp==unit.max_mp,"retry restores resources")
	app.queue_free()
	await process_frame
	print("Chapter UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
