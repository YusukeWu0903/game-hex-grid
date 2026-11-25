extends SceneTree
const Rules=preload("res://core/battle_rules.gd")
const Hex=preload("res://core/hex_rules.gd")
const Catalog=preload("res://core/catalog.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func reference_approach(map: Dictionary, actor: Dictionary, units: Array, targets: Array, action: Dictionary) -> Dictionary:
	var search = Hex.search(map,actor.cell,Hex.cells(int(map.radius)).size()*2,Rules.occupied(units,str(actor.id)))
	var best_cell = ""
	var best_cost = INF
	var best_hp = INF
	for key in search.costs:
		var candidate = actor.duplicate(true)
		candidate.cell = Hex.cell(key)
		for target in targets:
			if not Rules.can_attack(candidate,target,action):
				continue
			var cost = int(search.costs[key])
			if cost<best_cost or (cost==best_cost and target.hp<best_hp):
				best_cost = cost
				best_hp = target.hp
				best_cell = key
	if best_cell.is_empty():
		return {}
	var route = Hex.route(search,Hex.cell(best_cell))
	var prefix: Array[Vector3i] = []
	var spent = 0
	for cell in route:
		var cost = Hex.terrain_cost(map,cell)
		if spent+cost>int(actor.movement):
			break
		prefix.append(cell)
		spent += cost
	return {"path":prefix,"target_id":"","cost":spent}

func _initialize() -> void:
	var rng=RandomNumberGenerator.new()
	rng.seed=2026112539
	for radius in [4,12]:
		for template in ["enemy_swordsman_base","enemy_archer_base"]:
			for variant in range(5):
				var map={"radius":radius,"terrains":{},"spawnPoints":{}}
				for cell in Hex.cells(radius):
					var roll=rng.randf()
					if roll<0.08: map.terrains[Hex.key(cell)]="MOUNTAIN"
					elif roll<0.3: map.terrains[Hex.key(cell)]="FOREST"
				var actor=Catalog.enemy(template,0,Vector3i(-radius,radius,0))
				var targets=[Catalog.player("player_swordsman_01",Vector3i(radius,-radius,0)),
					Catalog.player("player_swordsman_02",Vector3i(radius-1,-radius,1)),
					Catalog.player("player_archer_01",Vector3i(radius,-radius+1,-1))]
				var units=[actor]+targets
				for unit in units: map.terrains.erase(Hex.key(unit.cell))
				var action=Catalog.action(actor)
				check(Rules.approach_plan(map,actor,units,targets,action)==reference_approach(map,actor,units,targets,action),"optimized approach keeps route and ties %s %d %d" % [template,radius,variant])
	print("AI_EQUIVALENCE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
