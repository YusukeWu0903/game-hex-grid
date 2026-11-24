extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
var count = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	count += 1
	if not condition:
		failures.append(label)
		push_error(label)

func make_unit(id: String, faction: String, cell: Vector3i) -> Dictionary:
	return {"id":id, "faction":faction, "cell":cell, "hp":12, "mp":20, "acted":false, "movement":3}

func _initialize() -> void:
	var sword = {"range_min":1,"range_max":1,"mp_cost":0,"damage":4}
	var bow = {"range_min":2,"range_max":3,"mp_cost":0,"damage":3}
	var skill = {"range_min":2,"range_max":4,"mp_cost":15,"damage":6}
	var p = make_unit("P","PLAYER",Vector3i.ZERO)
	var e = make_unit("E","ENEMY",Vector3i(1,-1,0))
	check(Rules.can_attack(p,e,sword), "adjacent sword attack")
	check(not Rules.can_attack(p,e,bow), "bow minimum range")
	e.cell = Vector3i(2,-2,0)
	check(Rules.can_attack(p,e,bow), "bow range 2")
	e.cell = Vector3i(3,-3,0)
	check(Rules.can_attack(p,e,bow), "bow range 3")
	e.cell = Vector3i(4,-4,0)
	check(not Rules.can_attack(p,e,bow), "bow rejects range 4")
	p.mp = 14
	var result = Rules.apply_attack(p,e,skill)
	check(not result.ok and e.hp == 12 and p.mp == 14 and not p.acted, "insufficient MP is side effect free")
	p.mp = 15
	result = Rules.apply_attack(p,e,skill)
	check(result.ok and e.hp == 6 and p.mp == 0 and p.acted, "skill pays MP and deals exact damage")
	check(not Rules.apply_attack(p,e,skill).ok, "cannot act twice")
	p.acted = false
	e.cell = Vector3i(1,-1,0)
	e.faction = "PLAYER"
	check(not Rules.can_attack(p,e,sword), "friendly fire rejected")
	e.faction = "ENEMY"
	var map = {"mapId":"test","name":"Test","radius":4,"terrains":{},"spawnPoints":{"0,0,0":"PLAYER","1,-1,0":"ENEMY"}}
	check(Rules.validate_deployment(map,[p,e]).is_empty(), "valid deployment")
	e.cell = Vector3i.ZERO
	check(not Rules.validate_deployment(map,[p,e]).is_empty(), "overlap rejected")
	e.cell = Vector3i(1,-1,0)
	var plan = Rules.plan_ai(map,e,[p,e],bow)
	check(not plan.path.is_empty() and plan.target_id == "P", "adjacent archer retreats to shooting range")
	var end: Vector3i = plan.path[-1]
	check(Hex.distance(end,p.cell) >= 2 and Hex.distance(end,p.cell) <= 3, "retreat ends in legal range")
	for c in Hex.cells(4):
		map.terrains[Hex.key(c)] = "FOREST"
	e.cell = Vector3i(-3,3,0)
	p.cell = Vector3i(3,-3,0)
	plan = Rules.plan_ai(map,e,[p,e],sword)
	var cost = 0
	for c in plan.path:
		cost += Hex.terrain_cost(map,c)
	check(cost <= e.movement and cost == plan.cost, "AI observes forest budget")
	check(plan.path.size() <= 1, "movement 3 allows at most one forest step")
	check(Rules.outcome([p,e]) == "", "ongoing battle")
	e.hp = 0
	check(Rules.outcome([p,e]) == "VICTORY", "victory")
	p.hp = 0
	e.hp = 12
	check(Rules.outcome([p,e]) == "DEFEAT", "defeat")
	check(Rules.outcome([]) == "DEFEAT", "empty battle is not victory")
	print("BATTLE_RULES_TESTS: %d checks, %d failures" % [count,failures.size()])
	quit(0 if failures.is_empty() else 1)
