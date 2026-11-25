extends SceneTree
const Hex=preload("res://core/hex_rules.gd")
var checks=0
var failures=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func reference_search(map: Dictionary, start: Vector3i, budget: int, blocked: Dictionary = {}) -> Dictionary:
	var costs = {Hex.key(start): 0}
	var previous = {}
	var queue: Array[Vector3i] = [start]
	while not queue.is_empty():
		var best = 0
		for i in range(1, queue.size()):
			if costs[Hex.key(queue[i])] < costs[Hex.key(queue[best])]:
				best = i
		var current = queue[best]
		queue.remove_at(best)
		for direction in Hex.DIRECTIONS:
			var next: Vector3i = current + direction
			var next_key = Hex.key(next)
			var step = Hex.terrain_cost(map, next)
			if step < 0 or blocked.has(next_key):
				continue
			var total = int(costs[Hex.key(current)]) + step
			if total > budget:
				continue
			if not costs.has(next_key) or total < int(costs[next_key]):
				costs[next_key] = total
				previous[next_key] = Hex.key(current)
				if not queue.has(next):
					queue.append(next)
	return {"costs": costs, "previous": previous, "start": Hex.key(start)}

func _initialize() -> void:
	var rng=RandomNumberGenerator.new()
	rng.seed=2026112517
	for radius in [1,4,12]:
		for variant in range(5):
			var map={"radius":radius,"terrains":{},"spawnPoints":{}}
			var blocked={}
			for cell in Hex.cells(radius):
				if cell==Vector3i.ZERO: continue
				var roll=rng.randf()
				if roll<0.12: map.terrains[Hex.key(cell)]="MOUNTAIN"
				elif roll<0.35: map.terrains[Hex.key(cell)]="FOREST"
				elif roll<0.45: blocked[Hex.key(cell)]=true
			for budget in [0,2,3,12,938]:
				var expected=reference_search(map,Vector3i.ZERO,budget,blocked)
				var actual=Hex.search(map,Vector3i.ZERO,budget,blocked)
				check(actual==expected,"heap preserves costs and predecessor ties radius %d variant %d budget %d" % [radius,variant,budget])
	var map={"radius":12,"terrains":{},"spawnPoints":{}}
	var start=Time.get_ticks_usec()
	for i in range(30): reference_search(map,Vector3i.ZERO,938)
	var reference_us=Time.get_ticks_usec()-start
	start=Time.get_ticks_usec()
	for i in range(30): Hex.search(map,Vector3i.ZERO,938)
	var heap_us=Time.get_ticks_usec()-start
	print("PATH_BENCHMARK 30 full radius12 searches: reference=%d us heap=%d us" % [reference_us,heap_us])
	print("PATH_HEAP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
