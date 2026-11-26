extends SceneTree
const Catalog = preload("res://core/catalog.gd")
const Rules = preload("res://core/battle_rules.gd")
var app
var checks = 0
var failures = 0
var output = ""
var seen_presentations = {}
var skipped = 0
var natural = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	call_deferred("run")
func click(at: Vector2) -> void:
	var move=InputEventMouseMotion.new()
	move.position=at
	root.push_input(move,true)
	var down=InputEventMouseButton.new()
	down.position=at
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	root.push_input(down,true)
	await process_frame
	var up=InputEventMouseButton.new()
	up.position=at
	up.button_index=MOUSE_BUTTON_LEFT
	root.push_input(up,true)
	await process_frame
func settle_layout() -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
func click_action(action: String) -> void:
	await settle_layout()
	await click(app.radial_actions.buttons[action].get_global_rect().get_center())
func wait_idle() -> bool:
	var start=Time.get_ticks_msec()
	while app.busy:
		if Time.get_ticks_msec()-start>30000:
			check(false,"UI command completes within 30 seconds")
			return false
		if app.cinematic.active:
			var c=app.cinematic
			var marker="%s:%s:%s:%s:%s" % [app.level.mapId,app.battle.turn,c.actor.id,c.target.id,c.target.hp]
			if not seen_presentations.has(marker):
				seen_presentations[marker] = seen_presentations.size()%2==0
				if not seen_presentations[marker]: natural+=1
			if seen_presentations[marker] and c.elapsed>(0.3 if c.reduced else 1.3):
				var key=InputEventKey.new()
				key.keycode=KEY_SPACE
				key.pressed=true
				root.push_input(key,true)
				key=InputEventKey.new()
				key.keycode=KEY_SPACE
				root.push_input(key,true)
				skipped+=1
		await process_frame
	await settle_layout()
	return true
func capture(name: String) -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run() -> void:
	output=OS.get_environment("HEX_TACTICS_TEST_DIR")
	if output.is_empty():
		quit(2)
		return
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.audio.enabled=false
	app.combat_cinematics=true
	for map_id in ["map_tutorial","map_custom"]:
		app.level=app.store.default_level(map_id)
		app.begin_deployment(app.level)
		app.battle.auto_deploy()
		app.start_battle()
		app.reduced_motion=map_id=="map_custom"
		var commands=0
		while app.mode=="BATTLE" and commands<90 and failures==0:
			if not await wait_idle(): break
			if app.mode!="BATTLE": break
			var available=app.battle.units.filter(func(u): return u.faction=="PLAYER" and not u.acted)
			if available.is_empty():
				check(false,"player phase has an available unit")
				break
			var unit=available[0]
			var use_skill=unit.mp>=Catalog.action(unit,true).mp_cost
			var plan=Rules.plan_ai(app.battle.map,unit,app.battle.units,Catalog.action(unit,use_skill))
			await click(app.board.global_position+app.board.position_of(unit.cell))
			check(app.selection==unit.id and app.radial_actions.visible,"real unit click opens ring")
			if not plan.path.is_empty():
				await click_action("MOVE")
				await click(app.board.global_position+app.board.position_of(plan.path[-1]))
				if not await wait_idle(): break
				check(unit.cell==plan.path[-1] and unit.moved,"actual movement input commits planned cell")
			if not plan.target_id.is_empty():
				var target=app.battle.get_unit(plan.target_id)
				await click_action("SKILL" if use_skill else "ATTACK")
				await click(app.board.global_position+app.board.position_of(target.cell))
				check(app.busy and app.cinematic.active,"actual target input opens cinematic")
			else:
				await click_action("WAIT")
			commands+=1
			if not await wait_idle(): break
			print("UI_PLAYTHROUGH: %s turn=%d commands=%d mode=%s" % [map_id,app.battle.turn,commands,app.mode])
		check(app.mode=="RESULT","full GUI battle reaches result "+map_id)
		check(not app.busy and not app.cinematic.active,"result has no pending presentation")
		await capture("playthrough-"+map_id+"-result")
	check(skipped>0 and natural>0,"both skipped and natural presentations exercised")
	print("UI_PLAYTHROUGH_PRESENTATIONS: %d skipped, %d natural" % [skipped,natural])
	app.show_menu()
	app.queue_free()
	await create_timer(0.2).timeout
	print("UI_PLAYTHROUGH_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
