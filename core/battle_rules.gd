class_name BattleRules
extends RefCounted
const Hex = preload("res://core/hex_rules.gd")

static func occupied(units: Array, except_id: String = "") -> Dictionary:
	var result = {}
	for unit in units:
		if int(unit.get("hp",0)) > 0 and str(unit.get("id","")) != except_id:
			result[Hex.key(unit.cell)] = true
	return result

static func unit_at(units: Array, cell: Vector3i) -> Dictionary:
	for unit in units:
		if int(unit.get("hp",0)) > 0 and unit.cell == cell:
			return unit
	return {}

static func attack_error(actor: Dictionary, target: Dictionary, action: Dictionary) -> String:
	if actor.is_empty():
		return "尚未選擇可行動角色。"
	if target.is_empty():
		return "請選擇敵方角色。"
	if int(actor.get("hp",0)) <= 0 or int(target.get("hp",0)) <= 0:
		return "角色已被擊倒。"
	if actor.get("faction") == target.get("faction"):
		return "不能攻擊友軍。"
	if actor.get("acted",false):
		return "本回合已行動。"
	if int(actor.get("mp",0)) < int(action.get("mp_cost",0)):
		return "MP 不足：目前 %d／需要 %d。" % [int(actor.get("mp",0)),int(action.get("mp_cost",0))]
	var distance = Hex.distance(actor.cell,target.cell)
	if distance<int(action.get("range_min",1)):
		return "目標太近：距離 %d／最短射程 %d。" % [distance,int(action.get("range_min",1))]
	if distance>int(action.get("range_max",1)):
		return "目標太遠：距離 %d／最遠射程 %d。" % [distance,int(action.get("range_max",1))]
	return ""

static func can_attack(actor: Dictionary, target: Dictionary, action: Dictionary) -> bool:
	return attack_error(actor,target,action).is_empty()

# Revalidate at execution time. A rejected command has no side effects.
static func apply_attack(actor: Dictionary, target: Dictionary, action: Dictionary) -> Dictionary:
	if not can_attack(actor,target,action):
		return {"ok":false, "damage":0}
	var damage = int(action.get("damage",0))
	if damage <= 0 or int(action.get("mp_cost",0)) < 0:
		return {"ok":false, "damage":0}
	actor.mp = int(actor.mp) - int(action.get("mp_cost",0))
	target.hp = maxi(0,int(target.hp)-damage)
	actor.acted = true
	return {"ok":true, "damage":damage, "killed":target.hp == 0}

static func validate_deployment(map: Dictionary, units: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_cells = {}
	var seen_ids = {}
	var player_count = 0
	var enemy_count = 0
	for unit in units:
		var id = str(unit.get("id",""))
		if id.is_empty() or seen_ids.has(id):
			errors.append("單位 ID 缺失或重複：" + id)
		seen_ids[id] = true
		if not unit.get("cell") is Vector3i:
			errors.append("單位座標無效：" + id)
			continue
		var key = Hex.key(unit.cell)
		if seen_cells.has(key):
			errors.append("單位重疊：" + key)
		seen_cells[key] = true
		if Hex.terrain_cost(map,unit.cell) < 0:
			errors.append("單位位於不可通行格：" + id)
		if map.get("spawnPoints",{}).get(key,"") != unit.get("faction"):
			errors.append("單位必須位於同陣營出生點：" + id)
		if int(unit.get("hp",0)) <= 0:
			errors.append("不能部署 HP 為零的單位：" + id)
		if unit.get("faction") == "PLAYER":
			player_count += 1
		elif unit.get("faction") == "ENEMY":
			enemy_count += 1
		else:
			errors.append("不支援的單位陣營：" + id)
	if player_count == 0:
		errors.append("至少部署一名我方單位。")
	if enemy_count == 0:
		errors.append("至少配置一名敵方單位。")
	return errors

static func outcome(units: Array) -> String:
	var players = 0
	var enemies = 0
	for unit in units:
		if int(unit.get("hp",0)) <= 0:
			continue
		if unit.get("faction") == "PLAYER":
			players += 1
		elif unit.get("faction") == "ENEMY":
			enemies += 1
	# Do not grant victory to an empty or invalid battle.
	if players == 0:
		return "DEFEAT"
	if enemies == 0:
		return "VICTORY"
	return ""

# Evaluate reachable firing positions instead of walking a fixed number of cells
# towards an occupied target. Ties preserve deterministic iteration order.
static func plan_ai(map: Dictionary, actor: Dictionary, units: Array, action: Dictionary) -> Dictionary:
	var none = {"path":[], "target_id":"", "cost":0}
	if int(actor.get("hp",0)) <= 0 or actor.get("acted",false):
		return none
	var targets = []
	for unit in units:
		if int(unit.get("hp",0)) > 0 and unit.faction != actor.faction:
			targets.append(unit)
	if targets.is_empty():
		return none
	var reachable = Hex.search(map,actor.cell,int(actor.get("movement",0)),occupied(units,str(actor.id)))
	var best = {}
	var best_score = -INF
	for cell_key in reachable.costs:
		var destination = Hex.cell(cell_key)
		var spent = int(reachable.costs[cell_key])
		var candidate = actor.duplicate(true)
		candidate.cell = destination
		for target in targets:
			var distance = Hex.distance(destination,target.cell)
			var score = -float(distance) * 10.0 - spent
			var target_id = ""
			if can_attack(candidate,target,action):
				# Favor a legal attack, then a kill, then low movement expenditure.
				score = 10000.0 - spent * 10.0 - float(target.hp)
				if int(target.hp) <= int(action.get("damage",0)):
					score += 1000.0
				target_id = str(target.id)
			elif distance < int(action.get("range_min",1)):
				score -= 100.0
			if score > best_score:
				best_score = score
				best = {"path":Hex.route(reachable,destination), "target_id":target_id, "cost":spent}
	if not best.is_empty() and not str(best.target_id).is_empty():
		return best
	# When no attack is available this turn, route to an eventual firing cell.
	# Greedy hex distance can stop forever at the near side of a mountain wall.
	var strategic = approach_plan(map,actor,units,targets,action)
	return strategic if not strategic.is_empty() else (best if not best.is_empty() else none)

static func approach_plan(map: Dictionary, actor: Dictionary, units: Array, targets: Array, action: Dictionary) -> Dictionary:
	var search = Hex.search(map,actor.cell,Hex.cells(int(map.radius)).size()*2,occupied(units,str(actor.id)))
	var best_cell = ""
	var best_cost = INF
	var best_hp = INF
	for key in search.costs:
		var candidate = actor.duplicate(true)
		candidate.cell = Hex.cell(key)
		for target in targets:
			if not can_attack(candidate,target,action):
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

# Forecast the next enemy activation using current occupancy and normal attacks.
# This is potential reach, not a promise that AI will choose a particular target.
static func threat_cells(map: Dictionary, actor: Dictionary, units: Array, action: Dictionary) -> Dictionary:
	var result = {}
	if actor.is_empty() or int(actor.get("hp",0)) <= 0:
		return result
	var positions = Hex.search(map,actor.cell,int(actor.movement),occupied(units,str(actor.id)))
	var offsets = Hex.cells(int(action.range_max)).filter(func(offset): return Hex.distance(Vector3i.ZERO,offset)>=int(action.range_min))
	for origin_key in positions.costs:
		var origin = Hex.cell(origin_key)
		for offset in offsets:
			var target: Vector3i = origin+offset
			if Hex.inside(target,int(map.radius)):
				result[Hex.key(target)] = true
	return result
