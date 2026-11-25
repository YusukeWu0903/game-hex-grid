extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
const Generator = preload("res://core/map_generator.gd")
const Editor = preload("res://core/map_editor.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var start = Time.get_ticks_msec()
	for radius in [1,4,12,24]:
		for seed_value in range(8):
			var map = Generator.generate(radius,seed_value,0.45)
			check(Generator.diagnose(map).errors.is_empty(),"generated connectivity and clusters")
			check(map.spawnPoints.size()==6,"six safe deployment cells")
			check(map == Generator.generate(radius,seed_value,0.45),"seed reproducibility")
			check(Hex.cells(radius).size()==1+3*radius*(radius+1),"hex cell count")
	var map = Generator.generate(4,37)
	var editor = Editor.new()
	var before = map.duplicate(true)
	editor.checkpoint(map)
	editor.paint(map,Vector3i.ZERO,"FOREST",2,false)
	map = editor.undo(map)
	check(map==before,"paint undo restores all terrain and spawns")
	map = editor.redo(map)
	check(map!=before,"redo restores paint")
	editor.checkpoint(map)
	editor.resize(map,1)
	check(Hex.validate_map(map).is_empty(),"shrink removes all out-of-bounds data")
	map = editor.undo(map)
	check(map.radius==4,"undo resize")
	var blank = {"mapId":"blank","name":"blank","radius":4,"terrains":{},"spawnPoints":{}}
	editor.paint(blank,Vector3i.ZERO,"FOREST",0,true)
	check(blank.terrains.size()==61,"flood fill")
	blank.terrains["0,0,0"]="WATER"
	check(not Generator.diagnose(blank).errors.is_empty(),"isolated water rejected")
	blank.terrains={}
	for d in Hex.DIRECTIONS: blank.terrains[Hex.key(d)]="MOUNTAIN"
	check(Generator.diagnose(blank).cells.has("0,0,0"),"enclosed land highlighted")
	print("World: %d checks, %d failures; %d ms" % [checks,failures,Time.get_ticks_msec()-start])
	quit(1 if failures else 0)
