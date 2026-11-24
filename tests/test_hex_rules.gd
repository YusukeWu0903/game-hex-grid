extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
var failures: Array[String] = []
var count = 0

func check(condition: bool, label: String) -> void:
	count += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	var map = {"mapId":"test", "name":"Test", "radius":4, "terrains":{}, "spawnPoints":{}}
	check(Hex.cells(4).size() == 61, "radius 4 has 61 cells")
	check(Hex.distance(Vector3i.ZERO, Vector3i(2,-1,-1)) == 2, "cube distance")
	for c in Hex.cells(4):
		check(Hex.from_pixel(Hex.to_pixel(c, 55.0),55.0) == c, "coordinate round trip " + Hex.key(c))
	var range_result = Hex.search(map, Vector3i.ZERO, 3)
	check(range_result.costs.has("3,-3,0"), "three plain steps reachable")
	check(not range_result.costs.has("4,-4,0"), "four plain steps exceed budget")
	for c in Hex.cells(4):
		map.terrains[Hex.key(c)] = "FOREST"
	range_result = Hex.search(map, Vector3i.ZERO, 3)
	check(range_result.costs.has("1,-1,0"), "one forest step reachable")
	check(not range_result.costs.has("2,-2,0"), "two forest steps exceed budget")
	map.terrains = {"1,-1,0":"WATER", "0,1,-1":"MOUNTAIN"}
	range_result = Hex.search(map, Vector3i.ZERO, 3, {"-1,1,0":true})
	check(not range_result.costs.has("1,-1,0"), "water blocks")
	check(not range_result.costs.has("0,1,-1"), "mountain blocks")
	check(not range_result.costs.has("-1,1,0"), "occupied cell blocks")
	var path = Hex.route(range_result, Vector3i(2,-2,0))
	var cost = 0
	var last = Vector3i.ZERO
	for c in path:
		check(Hex.distance(last,c) == 1, "route uses neighbors")
		cost += Hex.terrain_cost(map,c)
		last = c
	check(cost <= 3 and last == Vector3i(2,-2,0), "detour within budget")
	check(Hex.validate_map(map).is_empty(), "valid map accepted")
	check(not Hex.validate_map({"radius":"bad"}).is_empty(), "bad schema rejected")
	map.spawnPoints = {"1,-1,0":"PLAYER"}
	check(not Hex.validate_map(map).is_empty(), "water spawn rejected")
	for filename in ["map_tutorial", "map_001"]:
		var original = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + filename + ".json"))
		check(Hex.validate_map(original).is_empty(), "legacy map accepted " + filename)
	print("HEX_RULES_TESTS: %d checks, %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)
