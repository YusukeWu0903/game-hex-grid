extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
const Catalog = preload("res://core/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func brute(map: Dictionary, actor: Dictionary, units: Array, action: Dictionary) -> Dictionary:
	var result = {}
	var positions = Hex.search(map,actor.cell,actor.movement,Rules.occupied(units,actor.id))
	for key in positions.costs:
		var candidate = actor.duplicate(true)
		candidate.cell = Hex.cell(key)
		candidate.acted = false
		for cell in Hex.cells(int(map.radius)):
			var target = {"hp":1,"faction":"PLAYER","cell":cell}
			if Rules.can_attack(candidate,target,action):
				result[Hex.key(cell)] = true
	return result
func full_grid(map: Dictionary, actor: Dictionary, units: Array, action: Dictionary) -> Dictionary:
	var result = {}
	var positions = Hex.search(map,actor.cell,actor.movement,Rules.occupied(units,actor.id))
	for key in positions.costs:
		var origin = Hex.cell(key)
		for cell in Hex.cells(int(map.radius)):
			var distance = Hex.distance(origin,cell)
			if distance>=action.range_min and distance<=action.range_max:
				result[Hex.key(cell)] = true
	return result

func _initialize() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261125
	for radius in [1,4,12]:
		for terrain_mode in [0,1,2]:
			var map = {"radius":radius,"terrains":{},"spawnPoints":{}}
			for cell in Hex.cells(radius):
				if cell == Vector3i.ZERO:
					continue
				if terrain_mode==1 and rng.randf()<0.35:
					map.terrains[Hex.key(cell)] = "FOREST"
				elif terrain_mode==2 and rng.randf()<0.4:
					map.terrains[Hex.key(cell)] = "MOUNTAIN"
			for template in ["enemy_swordsman_base","enemy_archer_base"]:
				var actor = Catalog.enemy(template,0,Vector3i.ZERO)
				var blocker = Catalog.enemy("enemy_swordsman_base",1,Vector3i(1,-1,0))
				var player = Catalog.player("player_swordsman_01",Vector3i(-1,1,0))
				var units = [actor,blocker,player]
				var action = Catalog.action(actor)
				var actual = Rules.threat_cells(map,actor,units,action)
				check(actual == brute(map,actor,units,action),"threat matches legal attack oracle radius %d terrain %d %s" % [radius,terrain_mode,template])
	# Measure a representative radius-12 archer forecast; timings are local evidence only.
	var map = {"radius":12,"terrains":{},"spawnPoints":{}}
	var actor = Catalog.enemy("enemy_archer_base",0,Vector3i.ZERO)
	var units = [actor]
	var action = Catalog.action(actor)
	var start = Time.get_ticks_usec()
	for i in range(30):
		full_grid(map,actor,units,action)
	var brute_us = Time.get_ticks_usec()-start
	start = Time.get_ticks_usec()
	for i in range(30):
		Rules.threat_cells(map,actor,units,action)
	var optimized_us = Time.get_ticks_usec()-start
	print("THREAT_BENCHMARK: 30 radius-12 archer forecasts; previous full-grid scan %d us; optimized %d us" % [brute_us,optimized_us])
	print("THREAT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
