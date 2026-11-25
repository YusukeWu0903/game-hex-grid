class_name HexRules
extends RefCounted

const DIRECTIONS = [Vector3i(1,-1,0), Vector3i(1,0,-1), Vector3i(0,1,-1), Vector3i(-1,1,0), Vector3i(-1,0,1), Vector3i(0,-1,1)]
const TERRAINS = ["PLAIN", "FOREST", "SWAMP", "HILLS", "MOUNTAIN", "WATER"]

static func key(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]

static func cell(value: String) -> Vector3i:
	var p = value.split(",")
	return Vector3i(int(p[0]), int(p[1]), int(p[2]))

static func distance(a: Vector3i, b: Vector3i) -> int:
	var d = a - b
	return int((absi(d.x) + absi(d.y) + absi(d.z)) / 2)

static func cells(radius: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x in range(-radius, radius + 1):
		for y in range(maxi(-radius, -x-radius), mini(radius, -x+radius) + 1):
			result.append(Vector3i(x, y, -x-y))
	return result

static func inside(c: Vector3i, radius: int) -> bool:
	return c.x + c.y + c.z == 0 and maxi(absi(c.x), maxi(absi(c.y), absi(c.z))) <= radius

static func terrain_cost(map: Dictionary, c: Vector3i) -> int:
	if not inside(c, int(map.get("radius", 0))):
		return -1
	var terrain = map.get("terrains", {}).get(key(c), "PLAIN")
	match terrain:
		"MOUNTAIN", "WATER": return -1
		"FOREST", "SWAMP", "HILLS": return 2
		_: return 1

# Dijkstra is shared by player range, AI destinations and route reconstruction.
# All costs are logical terrain costs, never screen distances.
static func heap_less(a: Array, b: Array) -> bool:
	return a[0]<b[0] or (a[0]==b[0] and a[1]<b[1])

static func heap_push(heap: Array, entry: Array) -> void:
	var index = heap.size()
	heap.append(entry)
	while index>0:
		var parent = (index-1)/2
		if not heap_less(entry,heap[parent]):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry

static func heap_pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return first
	var index = 0
	while index*2+1<heap.size():
		var child = index*2+1
		if child+1<heap.size() and heap_less(heap[child+1],heap[child]):
			child += 1
		if not heap_less(heap[child],last):
			break
		heap[index] = heap[child]
		index = child
	heap[index] = last
	return first

static func search(map: Dictionary, start: Vector3i, budget: int, blocked: Dictionary = {}) -> Dictionary:
	var start_key = key(start)
	var costs = {start_key:0}
	var previous = {}
	var insertion_order = {start_key:0}
	var queue: Array = [[0,0,start]]
	while not queue.is_empty():
		var entry = heap_pop(queue)
		var current: Vector3i = entry[2]
		var current_key = key(current)
		var current_cost = int(entry[0])
		if current_cost != int(costs[current_key]):
			continue
		for direction in DIRECTIONS:
			var next: Vector3i = current+direction
			var next_key = key(next)
			var step = terrain_cost(map,next)
			if step<0 or blocked.has(next_key):
				continue
			var total = current_cost+step
			if total>budget:
				continue
			if not costs.has(next_key) or total<int(costs[next_key]):
				if not insertion_order.has(next_key):
					insertion_order[next_key] = insertion_order.size()
				costs[next_key] = total
				previous[next_key] = current_key
				# Reuse first-discovery order when decreasing a cost. This preserves
				# the old queue's deterministic ties while avoiding linear scans.
				heap_push(queue,[total,insertion_order[next_key],next])
	return {"costs":costs,"previous":previous,"start":start_key}

static func route(search_result: Dictionary, target: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var cursor = key(target)
	if not search_result.get("costs", {}).has(cursor):
		return result
	var start = search_result.get("start", "")
	while cursor != start:
		result.push_front(cell(cursor))
		if not search_result.get("previous", {}).has(cursor):
			return []
		cursor = search_result.previous[cursor]
	return result

static func to_pixel(c: Vector3i, size: float) -> Vector2:
	return Vector2(size * sqrt(3.0) * (c.x + c.z / 2.0), size * 1.5 * c.z)

static func from_pixel(p: Vector2, size: float) -> Vector3i:
	var q = (sqrt(3.0) / 3.0 * p.x - p.y / 3.0) / size
	var r = (2.0 / 3.0 * p.y) / size
	var s = -q-r
	var x = roundi(q)
	var y = roundi(s)
	var z = roundi(r)
	var dx = absf(x-q)
	var dy = absf(y-s)
	var dz = absf(z-r)
	if dx > dy and dx > dz:
		x = -y-z
	elif dy > dz:
		y = -x-z
	else:
		z = -x-y
	return Vector3i(x,y,z)

static func validate_map(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return ["地圖必須是 JSON 物件。"]
	for field in ["mapId", "name"]:
		if not value.get(field) is String or str(value.get(field, "")).strip_edges().is_empty():
			errors.append("缺少有效的 " + field)
	var radius = value.get("radius", 0)
	if not (radius is int or radius is float) or float(radius) != floorf(float(radius)) or float(radius) < 1 or float(radius) > 12:
		errors.append("地圖半徑必須是 1 至 12 的整數。")
		return errors
	for field in ["terrains", "spawnPoints"]:
		var entries = value.get(field)
		if not entries is Dictionary:
			errors.append(field + " 必須是物件。")
			continue
		for entry_key in entries:
			if not entry_key is String:
				errors.append("座標鍵必須是字串。")
				continue
			var parts = entry_key.split(",")
			if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
				errors.append("無效座標：" + entry_key)
				continue
			var c = cell(entry_key)
			if not inside(c, int(radius)) or key(c) != entry_key:
				errors.append("座標超界或格式不符：" + entry_key)
			if field == "terrains" and not TERRAINS.has(entries[entry_key]):
				errors.append("未知地形：" + str(entries[entry_key]))
			if field == "spawnPoints" and not ["PLAYER","ENEMY"].has(entries[entry_key]):
				errors.append("出生點陣營必須為 PLAYER 或 ENEMY。")
	if errors.is_empty():
		for entry_key in value.spawnPoints:
			if terrain_cost(value, cell(entry_key)) < 0:
				errors.append("出生點不可位於山脈或水域：" + entry_key)
	return errors
