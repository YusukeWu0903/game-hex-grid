extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
var undo_stack: Array = []
var redo_stack: Array = []
func checkpoint(map: Dictionary) -> void:
	undo_stack.append(map.duplicate(true))
	if undo_stack.size()>60: undo_stack.pop_front()
	redo_stack.clear()
func undo(map: Dictionary) -> Dictionary:
	if undo_stack.is_empty(): return map
	redo_stack.append(map.duplicate(true))
	return undo_stack.pop_back()
func redo(map: Dictionary) -> Dictionary:
	if redo_stack.is_empty(): return map
	undo_stack.append(map.duplicate(true))
	return redo_stack.pop_back()
func paint(map: Dictionary, origin: Vector3i, brush: String, radius: int, fill: bool) -> void:
	var targets: Array = []
	if fill:
		var terrain = map.terrains.get(Hex.key(origin),"PLAIN")
		var visited = {Hex.key(origin):true}
		targets.append(origin)
		var index = 0
		while index<targets.size():
			var c = targets[index]
			index += 1
			for d in Hex.DIRECTIONS:
				var k = Hex.key(c+d)
				if Hex.inside(c+d,map.radius) and not visited.has(k) and map.terrains.get(k,"PLAIN")==terrain:
					visited[k] = true
					targets.append(c+d)
	else:
		for d in Hex.cells(radius):
			if Hex.inside(origin+d,map.radius): targets.append(origin+d)
	for c in targets:
		var k = Hex.key(c)
		if brush in ["PLAYER","ENEMY"]:
			if Hex.terrain_cost(map,c)>0: map.spawnPoints[k] = brush
		elif brush=="CLEAR": map.spawnPoints.erase(k)
		else:
			if brush=="PLAIN": map.terrains.erase(k)
			else: map.terrains[k] = brush
			if brush in ["WATER","MOUNTAIN"]: map.spawnPoints.erase(k)
func resize(map: Dictionary, radius: int) -> void:
	map.radius = clampi(radius,1,Hex.MAX_RADIUS)
	for field in ["terrains","spawnPoints"]:
		for k in map[field].keys():
			if not Hex.inside(Hex.cell(k),map.radius): map[field].erase(k)
