extends RefCounted
const Hex = preload("res://core/hex_rules.gd")

static func groups(map: Dictionary, terrain: String = "LAND") -> Array:
	var pending = {}
	for c in Hex.cells(map.radius):
		if (terrain == "LAND" and Hex.terrain_cost(map,c)>0) or map.terrains.get(Hex.key(c),"PLAIN") == terrain:
			pending[c] = true
	var result = []
	while not pending.is_empty():
		var group = [pending.keys()[0]]
		pending.erase(group[0])
		var index = 0
		while index < group.size():
			var c = group[index]
			index += 1
			for d in Hex.DIRECTIONS:
				var k = c+d
				if pending.has(k):
					group.append(k)
					pending.erase(k)
		result.append(group)
	return result

static func diagnose(map: Dictionary) -> Dictionary:
	var errors = Hex.validate_map(map)
	var marks = {}
	if not errors.is_empty(): return {"errors":errors,"cells":marks}
	var land = groups(map)
	if land.size() != 1:
		errors.append("所有可走區必須連通，目前有 %d 個區域。" % land.size())
		land.sort_custom(func(a,b): return a.size()>b.size())
		for i in range(1,land.size()):
			for c in land[i]: marks[Hex.key(c)] = true
	for terrain in ["MOUNTAIN","WATER"]:
		for group in groups(map,terrain):
			if group.size()<3:
				errors.append("%s 群落至少需要 3 格。" % terrain)
				for c in group: marks[Hex.key(c)] = true
	return {"errors":errors,"cells":marks}

static func generate(radius: int, seed_value: int, obstacle_ratio: float = 0.25) -> Dictionary:
	radius = clampi(radius,1,Hex.MAX_RADIUS)
	var map = {"mapId":"generated_%d_%d" % [radius,seed_value],"name":"荒野 %d" % seed_value,"radius":radius,"terrains":{},"spawnPoints":{},"generator":{"version":1,"seed":seed_value,"obstacle_ratio":obstacle_ratio}}
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.13
	var candidates = Hex.cells(radius)
	var walkable = {}
	for c in candidates: walkable[c] = true
	candidates.sort_custom(func(a,b): return noise.get_noise_2d(a.x,a.z)<noise.get_noise_2d(b.x,b.z))
	var budget = int(candidates.size()*clampf(obstacle_ratio,0.0,0.45))
	var placed = 0
	# Only accept whole clusters that preserve connected walkable land.
	for c in candidates:
		if placed>=budget: break
		var cluster = [c,c+Hex.DIRECTIONS[0],c+Hex.DIRECTIONS[1]]
		var valid = true
		for point in cluster:
			if not Hex.inside(point,radius) or map.terrains.has(Hex.key(point)) or absi(point.x)>=radius-1:
				valid = false
		if not valid: continue
		var terrain = "WATER" if noise.get_noise_2d(c.x+91,c.z-71)<0 else "MOUNTAIN"
		for point in cluster: walkable.erase(point)
		if not connected(walkable):
			for point in cluster: walkable[point] = true
		else:
			for point in cluster: map.terrains[Hex.key(point)] = terrain
			placed += 3
	for c in candidates:
		var k = Hex.key(c)
		if map.terrains.has(k): continue
		var n = noise.get_noise_2d(c.x+43,c.z+19)
		if n>0.25: map.terrains[k] = "FOREST"
		elif n< -0.32: map.terrains[k] = "HILLS"
		elif n< -0.22: map.terrains[k] = "SWAMP"
	var land = Hex.cells(radius)
	land.sort_custom(func(a,b): return a.x<b.x if a.x!=b.x else a.z<b.z)
	for faction in ["PLAYER","ENEMY"]:
		var count = 0
		for c in land:
			var k = Hex.key(c)
			if Hex.terrain_cost(map,c)>0 and not map.spawnPoints.has(k):
				map.spawnPoints[k] = faction
				count += 1
				if count==3: break
		land.reverse()
	return map

static func connected(walkable: Dictionary) -> bool:
	if walkable.is_empty(): return false
	var queue = [walkable.keys()[0]]
	var seen = {queue[0]:true}
	var index = 0
	while index<queue.size():
		var c = queue[index]
		index += 1
		for d in Hex.DIRECTIONS:
			var next = c+d
			if walkable.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size()==walkable.size()
