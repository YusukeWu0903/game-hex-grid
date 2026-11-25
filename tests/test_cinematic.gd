extends SceneTree
const Catalog = preload("res://core/catalog.gd")
var app
var checks = 0
var failures = 0
var output = ""
var impact_count = 0
var finish_count = 0
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
		check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)
func fixture() -> void:
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	app.battle.units = [Catalog.player("player_swordsman_01",Vector3i.ZERO),Catalog.enemy("enemy_swordsman_base",0,Vector3i(1,-1,0))]
	app.battle_ui()
func run() -> void:
	output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.level.mapId = "map_tutorial"
	app.cinematic.set_process(false)
	app.cinematic.impact.connect(func(): impact_count += 1)
	app.cinematic.finished.connect(func(): finish_count += 1)
	fixture()
	var player = app.battle.units[0]
	var enemy = app.battle.units[1]
	var old_hp = enemy.hp
	app.select_unit(player.id)
	app.choose_action("ATTACK")
	app.on_cell_clicked(enemy.cell,MOUSE_BUTTON_LEFT)
	check(app.cinematic.active and app.busy,"valid attack opens cinematic and locks battle")
	check(enemy.hp == old_hp-4,"authoritative damage applies once")
	app.on_cell_clicked(enemy.cell,MOUSE_BUTTON_LEFT)
	check(enemy.hp == old_hp-4,"repeated click cannot repeat damage")
	check(not app.radial_actions.visible,"radial menu hidden during cinematic")
	app.cinematic.advance(0.6)
	await capture("cinematic-01-player-entry")
	app.cinematic.advance(0.65)
	check(impact_count == 1 and app.cinematic.impacted,"impact signal once")
	await capture("cinematic-02-player-hit")
	# Avoid starting enemy AI in this presentation fixture.
	app.battle.phase = "PLAYER"
	app.cinematic.skip()
	check(not app.cinematic.active and not app.busy,"skip returns control")
	check(enemy.hp == old_hp-4 and impact_count == 1,"skip never reapplies damage or impact")
	app.cinematic.skip()
	check(finish_count == 1,"double skip only finishes once")
	fixture()
	player = app.battle.units[0]
	enemy = app.battle.units[1]
	app.cinematic.begin(enemy,player,Catalog.action(enemy),3,player.hp-3,false)
	app.cinematic.advance(1.25)
	await capture("cinematic-03-enemy-hit")
	check(app.cinematic.actor.faction == "ENEMY" and app.cinematic.target.faction == "PLAYER","reverse attack retains faction sides")
	app.cinematic.skip()
	var archer = Catalog.enemy("enemy_archer_base",0,Vector3i(2,-2,0))
	app.cinematic.begin(archer,player,Catalog.action(archer),3,player.hp-3,false)
	app.cinematic.advance(1.08)
	await capture("cinematic-04-arrow")
	app.cinematic.skip()
	archer.hp = 7
	app.cinematic.begin(player,archer,Catalog.action(player,true),7,0,false)
	app.cinematic.advance(1.5)
	await capture("cinematic-05-skill-kill")
	check(app.cinematic.target_hp == 0 and app.cinematic.action.mp_cost == 10,"skill and lethal data retained")
	root.size = Vector2i(1100,720)
	await capture("cinematic-06-small")
	app.cinematic.skip()
	root.size = Vector2i(1440,900)
	app.cinematic.begin(player,enemy,Catalog.action(player),4,enemy.hp-4,true)
	app.cinematic.advance(0.3)
	check(app.cinematic.impacted and app.cinematic.active,"reduced motion retains impact information")
	await capture("cinematic-07-reduced")
	app.cinematic.advance(0.6)
	check(not app.cinematic.active,"reduced motion ends sooner")
	fixture()
	player = app.battle.units[0]
	enemy = app.battle.units[1]
	enemy.hp = 4
	app.select_unit(player.id)
	app.choose_action("ATTACK")
	app.on_cell_clicked(enemy.cell,MOUSE_BUTTON_LEFT)
	check(app.mode == "BATTLE" and app.battle.phase == "RESULT","lethal result waits for presentation")
	app.cinematic.skip()
	check(app.mode == "RESULT" and app.battle.result == "VICTORY","lethal cinematic then result screen")
	fixture()
	player = app.battle.units[0]
	enemy = app.battle.units[1]
	app.select_unit(player.id)
	app.choose_action("SKILL")
	app.on_cell_clicked(enemy.cell,MOUSE_BUTTON_LEFT)
	check(player.mp == player.max_mp-10,"skill cost charged exactly once")
	app.show_menu()
	check(app.mode == "MENU" and not app.busy and not app.cinematic.active,"leaving cancels pending cinematic safely")
	await process_frame
	check(app.mode == "MENU" and app.battle.units.is_empty(),"aborted continuation cannot restart battle")
	fixture()
	player = app.battle.units[0]
	enemy = app.battle.units[1]
	app.reduced_motion = true
	app.end_turn()
	await process_frame
	check(app.cinematic.active and app.cinematic.actor.faction == "ENEMY","real enemy AI invokes cinematic")
	check(player.hp == player.max_hp-3,"enemy damage applied exactly once")
	app.cinematic.skip()
	await process_frame
	check(app.battle.phase == "PLAYER" and app.battle.turn == 2 and not app.busy,"enemy presentation returns to next round")
	app.show_menu()
	app.audio.player.stop()
	app.queue_free()
	await create_timer(0.2).timeout
	print("CINEMATIC_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
