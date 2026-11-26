extends SceneTree
const Preferences = preload("res://core/preferences.gd")
const Saves = preload("res://core/battle_save.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var directory = OS.get_environment("HEX_TACTICS_TEST_DIR")
	if directory.is_empty():
		quit(2)
		return
	var path = directory.path_join("preferences-invalid.json")
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var preferences = Preferences.new(path)
	check(preferences.values==Preferences.DEFAULTS and not preferences.error.is_empty(),"corrupt preferences fall back to defaults with warning")
	check(FileAccess.get_file_as_string(path)=="{broken","corrupt settings original preserved")
	check(Saves.write_json(path,{"version":1,"sound":"false","reduced_motion":0,"cinematics":false,"volume":999}).is_empty(),"prepare malformed fields")
	preferences=Preferences.new(path)
	check(preferences.values.sound and not preferences.values.reduced_motion and preferences.values.volume==100,"invalid individual fields use defaults")
	check(not preferences.values.cinematics,"valid fields still load")
	preferences.values.volume=0
	preferences.values.sound=false
	check(preferences.save().is_empty(),"zero-volume preferences save")
	check(Preferences.new(path).values.volume==0 and not Preferences.new(path).values.sound,"zero and false are retained")
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.preferences.values.volume=25
	app.preferences.values.cinematics=false
	app.preferences.values.reduced_motion=true
	app.settings_timer.start()
	var app_path=app.preferences.path
	app.queue_free()
	await create_timer(0.2).timeout
	var reopened=Preferences.new(app_path)
	check(reopened.values.volume==25 and not reopened.values.cinematics and reopened.values.reduced_motion,"closing before debounce flushes changed preferences")
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(not app.combat_cinematics and app.reduced_motion,"next game instance applies preferences")
	check(absf(app.audio.player.volume_db-(-18+linear_to_db(0.25)))<0.01,"saved volume applied to audio output")
	app.audio.set_volume(0)
	check(app.audio.player.volume_db<=-80,"zero volume mutes output")
	app.queue_free()
	await create_timer(0.2).timeout
	# Restore test defaults for the following UI suites in the same isolated run.
	var reset=Preferences.new(app_path)
	reset.values=Preferences.DEFAULTS.duplicate()
	check(reset.save().is_empty(),"restore isolated test preferences")
	print("PREFERENCES_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
