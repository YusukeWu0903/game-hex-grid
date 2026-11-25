extends SceneTree
const Rules = preload("res://core/battle_rules.gd")
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const Store = preload("res://core/data_store.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var store = Store.new(OS.get_environment("HEX_TACTICS_TEST_DIR").path_join("ai-library.json"))
	var map = store.map_by_id("map_custom")
	var actor = Catalog.enemy("enemy_assassin",1,Vector3i(1,-1,0))
	var blocker = Catalog.enemy("enemy_heavy_guard",0,Vector3i.ZERO)
	var target = Catalog.player("player_swordsman_01",Vector3i(-2,1,1))
	var units = [actor,blocker,target]
	var original = units.duplicate(true)
	var plan = Rules.plan_ai(map,actor,units,Catalog.action(actor))
	check(not plan.path.is_empty(),"previously stalled near-wall fixture now moves")
	check(units==original,"AI planning has no side effects")
	var reached = false
	for turn in range(12):
		plan = Rules.plan_ai(map,actor,units,Catalog.action(actor))
		var cost = 0
		var previous = actor.cell
		var legal = true
		for cell in plan.path:
			cost += Hex.terrain_cost(map,cell)
			legal = legal and Hex.distance(previous,cell)==1 and Hex.terrain_cost(map,cell)>0 and not Rules.occupied(units,actor.id).has(Hex.key(cell))
			previous = cell
		check(legal and cost<=actor.movement,"detour stays adjacent, unoccupied and within budget")
		if not plan.path.is_empty():
			actor.cell = plan.path[-1]
		if not plan.target_id.is_empty():
			reached = Rules.can_attack(actor,target,Catalog.action(actor))
			break
	check(reached,"detour eventually reaches a valid attack against stationary target")
	var sealed = {"radius":4,"terrains":{},"spawnPoints":{}}
	actor.cell = Vector3i.ZERO
	target.cell = Vector3i(3,-3,0)
	for direction in Hex.DIRECTIONS:
		sealed.terrains[Hex.key(direction)] = "MOUNTAIN"
	plan = Rules.plan_ai(sealed,actor,[actor,target],Catalog.action(actor))
	check(plan.path.is_empty() and plan.target_id.is_empty(),"sealed unit waits rather than crossing mountains")
	actor.acted = true
	check(Rules.plan_ai(map,actor,units,Catalog.action(actor)).path.is_empty(),"acted unit cannot seek another detour")
	print("AI_DETOUR_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
