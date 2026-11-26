extends SceneTree
const Catalog = preload("res://core/catalog.gd")
var app
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func fixture() -> void:
	app.level.mapId = "map_tutorial"
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	app.battle.units = [Catalog.player("player_swordsman_01",Vector3i.ZERO),
		Catalog.enemy("enemy_swordsman_base",0,Vector3i(1,-1,0)),
		Catalog.enemy("enemy_swordsman_base",1,Vector3i(0,-1,1)),
		Catalog.enemy("enemy_swordsman_base",2,Vector3i(-1,0,1))]
	app.combat_cinematics = true
	app.reduced_motion = true
	app.cinematic.set_process(false)
	app.battle_ui()
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	fixture()
	var player = app.battle.units[0]
	var save_exists = FileAccess.file_exists(app.battle_save_path())
	var save_before = FileAccess.get_file_as_string(app.battle_save_path()) if save_exists else ""
	app.end_turn()
	check(app.cinematic.active and app.cinematic.actor.id=="enemy_0","first enemy starts presentation")
	check(player.hp==9,"first enemy hits once")
	app.save_battle()
	check(FileAccess.file_exists(app.battle_save_path())==save_exists,"saving blocked during cinematic")
	if save_exists:
		check(FileAccess.get_file_as_string(app.battle_save_path())==save_before,"cinematic cannot overwrite save")
	app.cinematic.skip()
	check(app.cinematic.active and app.cinematic.actor.id=="enemy_1" and player.hp==6,"first skip advances to second attacker once")
	app.cinematic.skip()
	check(app.cinematic.active and app.cinematic.actor.id=="enemy_2" and player.hp==3,"second skip advances to third attacker once")
	app.cinematic.skip()
	check(not app.busy and not app.cinematic.active and app.battle.turn==2 and app.battle.phase=="PLAYER","third skip ends sequence and unlocks next round")
	check(player.hp==3 and not player.acted,"resources and turn flags after multi-enemy sequence")
	fixture()
	player=app.battle.units[0]
	player.hp=6
	app.end_turn()
	app.cinematic.skip()
	check(app.cinematic.actor.id=="enemy_1" and app.cinematic.target_hp==0,"lethal second attacker starts final presentation")
	app.cinematic.skip()
	check(app.mode=="RESULT" and app.battle.result=="DEFEAT","defeat follows lethal presentation")
	check(not app.cinematic.active and app.battle.get_unit("enemy_2").acted==false,"remaining enemy does not act after defeat")
	fixture()
	player=app.battle.units[0]
	app.select_unit(player.id)
	app.choose_action("ATTACK")
	app.on_cell_clicked(app.battle.get_unit("enemy_0").cell,MOUSE_BUTTON_LEFT)
	check(app.cinematic.active,"presentation active before direct tree removal")
	app.queue_free()
	await create_timer(0.3).timeout
	check(not is_instance_valid(app),"closing game during presentation frees controller")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.mode=="MENU" and app.battle.units.is_empty() and not app.busy,"new controller unaffected by previous pending presentation")
	fixture()
	app.cinematic.set_process(true)
	app.reduced_motion=false
	app.end_turn()
	await create_timer(0.05).timeout
	check(app.cinematic.active,"normal-duration enemy presentation starts")
	app.show_menu()
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	var clean_units = app.battle.units.duplicate(true)
	await create_timer(0.4).timeout
	check(app.mode=="BATTLE" and app.battle.turn==1 and app.battle.units==clean_units,"interrupted normal presentation cannot mutate restarted battle")
	app.show_menu()
	app.audio.player.stop()
	app.queue_free()
	await create_timer(0.2).timeout
	print("CINEMATIC_LIFECYCLE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
