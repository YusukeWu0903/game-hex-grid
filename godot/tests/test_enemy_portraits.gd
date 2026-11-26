extends SceneTree
const Catalog = preload("res://core/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.cinematic.set_process(false)
	for window in [Vector2i(1440,900),Vector2i(1100,720)]:
		root.size = window
		await process_frame
		for job in ["swordsman","archer","mage","knight"]:
			var player = Catalog.player("player_%s_01" % job,Vector3i.ZERO)
			var enemy = Catalog.enemy("enemy_%s_base" % job,0,Vector3i(1,-1,0))
			var path = "res://assets/portraits/%s_enemy.png" % job
			var texture = load(path) as Texture2D
			check(texture!=null and texture.get_image().get_pixel(0,0).a<0.02,"transparent class portrait")
			for enemy_attack in [false,true]:
				for stage in [0.65,1.25,2.0]:
					var actor = enemy if enemy_attack else player
					var target = player if enemy_attack else enemy
					app.cinematic.begin(actor,target,Catalog.action(actor),4,5,false)
					app.cinematic.advance(stage)
					await process_frame
					await RenderingServer.frame_post_draw
					check(app.cinematic.portrait_cache.has(path) and app.cinematic.portrait_bounds.has(path),"class fallback uses cached visible bounds")
					var name = "%s-%d-%s-%.2f.png" % [job,window.x,"enemy" if enemy_attack else "hero",stage]
					check(root.get_texture().get_image().save_png(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join(name))==OK,"actual cinematic captured")
					app.cinematic.skip()
	app.queue_free()
	await process_frame
	print("Enemy portraits: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
