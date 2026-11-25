extends SceneTree
const Catalog = preload("res://core/catalog.gd")
func _initialize() -> void:
	root.size = Vector2i(1100,720)
	call_deferred("capture")
func capture() -> void:
	var output = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if output.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.audio.enabled = false
	app.cinematic.set_process(false)
	var sword = Catalog.player("player_swordsman_01",Vector3i.ZERO)
	var archer = Catalog.player("player_archer_01",Vector3i.ZERO)
	var foe = Catalog.enemy("enemy_swordsman_base",0,Vector3i.ZERO)
	var bow = Catalog.enemy("enemy_archer_base",0,Vector3i.ZERO)
	var cases = [[sword,foe,false,4,8],[bow,sword,false,3,9],[archer,foe,true,6,0]]
	var frame = 0
	for entry in cases:
		app.cinematic.begin(entry[0],entry[1],Catalog.action(entry[0],entry[2]),entry[3],entry[4],false)
		for index in range(53):
			app.cinematic.advance(0.049)
			await process_frame
			await RenderingServer.frame_post_draw
			var error = root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame))
			if error != OK:
				quit(3)
				return
			frame += 1
		app.cinematic.skip()
	app.queue_free()
	await create_timer(0.2).timeout
	print("Captured %d gameplay presentation frames" % frame)
	quit()
