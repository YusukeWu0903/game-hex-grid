extends SceneTree
const Catalog = preload("res://core/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	root.size = Vector2i(1440,900)
	call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.cinematic.set_process(false)
	var enemy = Catalog.enemy("enemy_swordsman_base",0,Vector3i(1,-1,0))
	for id in ["player_swordsman_01","player_swordsman_02","player_archer_01","player_mage_01","player_knight_01"]:
		var texture = load("res://assets/portraits/%s.png" % id) as Texture2D
		check(texture!=null,"unique adopted portrait exists")
		var bitmap = texture.get_image()
		check(bitmap.get_pixel(0,0).a==0,"portrait corner transparent")
		var player = Catalog.player(id,Vector3i.ZERO)
		app.cinematic.begin(player,enemy,Catalog.action(player),4,8,false)
		app.cinematic.advance(0.65)
		await process_frame
		await RenderingServer.frame_post_draw
		check(app.cinematic.portrait_cache.has("res://assets/portraits/%s.png" % id),"cinematic uses character-specific texture")
		var path = OS.get_environment("HEX_TACTICS_TEST_DIR").path_join(id+"-duel.png")
		check(root.get_texture().get_image().save_png(path)==OK,"portrait scene captured")
		app.cinematic.skip()
	# Exercise adopted portraits on both sides, at rest, lunge and recovery.
	for window_size in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size = window_size
		await process_frame
		await process_frame
		for reverse in [false,true]:
			var mage = Catalog.player("player_mage_01",Vector3i.ZERO)
			var knight = Catalog.player("player_knight_01",Vector3i(1,-1,0))
			var left = knight if reverse else mage
			var right = mage if reverse else knight
			right.faction = "ENEMY"
			for stage in [0.65,1.25,2.0]:
				app.cinematic.begin(left,right,Catalog.action(left),4,8,false)
				app.cinematic.advance(stage)
				await process_frame
				await RenderingServer.frame_post_draw
				var shot = "pair-%d-%s-%.2f.png" % [window_size.x,"knight-left" if reverse else "mage-left",stage]
				check(root.get_texture().get_image().save_png(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join(shot))==OK,"both sides and animation state captured")
				app.cinematic.skip()
			# Actual enemy attack uses the opposite motion direction.
			app.cinematic.begin(right,left,Catalog.action(right),4,5,false)
			app.cinematic.advance(1.25)
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("enemy-attack-%d-%s.png" % [window_size.x,str(reverse)]))==OK,"enemy attack captured")
			app.cinematic.skip()
	app.queue_free()
	await process_frame
	print("Portraits: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
