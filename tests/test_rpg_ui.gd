extends SceneTree
const Catalog = preload("res://core/catalog.gd")
const RPGUI = preload("res://ui/rpg_ui.gd")
var app
var checks=0
var failures=0
var output=""
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	call_deferred("run")
func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
func find_button(node: Node,title: String) -> Button:
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=find_button(child,title)
		if found!=null:return found
	return null
func press(title: String) -> void:
	await process_frame
	await process_frame
	var button=find_button(app.sidebar,title)
	check(button!=null,"button "+title)
	if button==null:return
	var parent=button.get_parent()
	while parent!=null and not parent is ScrollContainer:parent=parent.get_parent()
	if parent is ScrollContainer:parent.ensure_control_visible(button)
	await process_frame
	await click(button.get_global_rect().get_center())
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run() -> void:
	output=OS.get_environment("HEX_TACTICS_TEST_DIR")
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.board.edge_scroll_enabled=false
	var initial_potions=int(app.party.inventory.potion)
	app.begin_deployment(app.store.levels[1])
	app.battle.auto_deploy()
	app.start_battle()
	await create_timer(0.9).timeout
	check(app.battle.units.size()==9,"five players and four enemies deployed")
	await capture("rpg-01-expedition")
	app.battle.get_unit("player_mage_01").cell=Vector3i.ZERO
	app.battle.get_unit("player_swordsman_01").cell=Vector3i(1,-1,0)
	app.battle.get_unit("enemy_0").cell=Vector3i(2,-2,0)
	app.battle.get_unit("enemy_1").cell=Vector3i(2,-1,-1)
	app.battle.get_unit("player_mage_01").hp=1
	app.battle.map.chests={"0,0,0":"wooden"}
	app.battle.history.clear()
	app.battle.capture_round()
	app.select_unit("player_swordsman_01")
	await create_timer(0.9).timeout
	await capture("rpg-02-utility-ring")
	await click(app.radial_actions.utility_buttons.ITEM.get_global_rect().get_center())
	check(app.action_mode=="ITEM","bottle icon enters item mode")
	await press("治療藥水 ×%d" % initial_potions)
	await click(app.board.global_position+app.board.position_of(Vector3i.ZERO))
	check(app.battle.get_unit("player_mage_01").hp==9,"UI item heals selected ally")
	check(app.battle.inventory.potion==initial_potions-1,"UI item consumes one")
	await press("回溯到選定回合")
	await process_frame
	check(app.confirm_dialog.visible,"rewind asks before discarding future")
	var ok=app.confirm_dialog.get_ok_button()
	await click(Vector2(app.confirm_dialog.position)+ok.get_global_rect().get_center())
	await process_frame
	check(app.battle.get_unit("player_mage_01").hp==1 and app.battle.inventory.potion==initial_potions,"confirmed rewind restores HP and inventory")
	app.select_unit("player_mage_01")
	await create_timer(0.9).timeout
	app.cinematic.set_process(false)
	await click(app.radial_actions.buttons.SKILL.get_global_rect().get_center())
	app.on_cell_hovered(Vector3i(2,-2,0))
	check(app.board.area_cells.size()>0,"AoE preview appears")
	await capture("rpg-03-spell-preview")
	await click(app.board.global_position+app.board.position_of(Vector3i(2,-2,0)))
	check(app.cinematic.active and app.cinematic.actor.job=="mage","mage opens cinematic")
	app.cinematic.advance(1.25)
	await capture("rpg-04-magic-impact")
	app.cinematic.skip()
	await process_frame
	check(app.battle.get_unit("player_mage_01").mp==20,"spell MP charged once")
	app.rewind_battle(1)
	app.select_unit("player_knight_01")
	await create_timer(0.9).timeout
	await click(app.radial_actions.buttons.SKILL.get_global_rect().get_center())
	check(app.battle.get_unit("player_knight_01").guard==3,"shield skill activates from icon")
	app.rewind_battle(1)
	app.select_unit("player_swordsman_01")
	await create_timer(0.9).timeout
	await click(app.radial_actions.utility_buttons.CHEST.get_global_rect().get_center())
	await click(app.board.global_position+app.board.position_of(Vector3i.ZERO))
	check(app.battle.opened_chests.has("0,0,0"),"chest icon opens adjacent chest")
	await capture("rpg-05-opened-chest")
	app.rewind_battle(1)
	check(app.battle.opened_chests.is_empty(),"rewind closes chest")
	app.battle.result="DEFEAT"
	app.battle.phase="RESULT"
	app.after_action()
	check(find_button(app.sidebar,"回溯到選定回合")!=null,"defeat offers rewind")
	await capture("rpg-06-defeat-rewind")
	app.rewind_battle(1)
	check(app.mode=="BATTLE" and app.battle.phase=="PLAYER","defeat rewind resumes play")
	app.show_menu()
	RPGUI.show_party(app)
	app.party_selected="player_knight_01"
	RPGUI.show_party(app)
	check(app.mode=="PARTY","party equipment screen")
	await capture("rpg-07-equipment")
	root.size=Vector2i(1100,720)
	await capture("rpg-08-small-window")
	app.queue_free()
	await process_frame
	print("RPG_UI_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
