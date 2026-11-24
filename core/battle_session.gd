class_name BattleSession
extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
const Catalog = preload("res://core/catalog.gd")

var map: Dictionary = {}
var units: Array = []
var allowed_ids: Array = []
var phase = "MENU"
var turn = 1
var result = ""
var revision = 0

func prepare(new_map: Dictionary, roster_ids: Array, enemy_ids: Array) -> Array[String]:
	var errors = Hex.validate_map(new_map)
	if roster_ids.is_empty():
		errors.append("請選擇至少一名出戰角色。")
	var seen = {}
	for id in roster_ids:
		if not Catalog.roster_ids().has(id) or seen.has(id):
			errors.append("出戰角色不存在或重複：" + str(id))
		seen[id] = true
	var player_spawns = []
	var enemy_spawns = []
	for key in new_map.get("spawnPoints",{}):
		if new_map.spawnPoints[key] == "PLAYER":
			player_spawns.append(key)
		elif new_map.spawnPoints[key] == "ENEMY":
			enemy_spawns.append(key)
	if player_spawns.size() < roster_ids.size():
		errors.append("我方出生點不足：需要 %d 格，目前 %d 格。" % [roster_ids.size(),player_spawns.size()])
	if enemy_ids.is_empty():
		errors.append("請配置至少一名敵人。")
	if enemy_spawns.size() < enemy_ids.size():
		errors.append("敵方出生點不足：需要 %d 格，目前 %d 格。" % [enemy_ids.size(),enemy_spawns.size()])
	for id in enemy_ids:
		if not Catalog.data().enemies.has(id):
			errors.append("未知敵人：" + str(id))
	if not errors.is_empty():
		return errors
	map = new_map.duplicate(true)
	allowed_ids = roster_ids.duplicate()
	units = []
	turn = 1
	result = ""
	phase = "DEPLOYMENT"
	revision += 1
	for i in range(enemy_ids.size()):
		units.append(Catalog.enemy(enemy_ids[i],i,Hex.cell(enemy_spawns[i])))
	return errors

func get_unit(id: String) -> Dictionary:
	for unit in units:
		if unit.id == id and unit.hp > 0:
			return unit
	return {}

func deploy(id: String, at: Vector3i) -> bool:
	if phase != "DEPLOYMENT" or not allowed_ids.has(id):
		return false
	if map.spawnPoints.get(Hex.key(at),"") != "PLAYER" or Hex.terrain_cost(map,at) < 0:
		return false
	var occupant = Rules.unit_at(units,at)
	if not occupant.is_empty() and occupant.faction != "PLAYER":
		return false
	units = units.filter(func(u): return u.id != id and (u.faction != "PLAYER" or u.cell != at))
	units.append(Catalog.player(id,at))
	return true

func recall(at: Vector3i) -> bool:
	if phase != "DEPLOYMENT":
		return false
	var before = units.size()
	units = units.filter(func(u): return u.faction != "PLAYER" or u.cell != at)
	return units.size() != before

func auto_deploy() -> void:
	if phase != "DEPLOYMENT":
		return
	var spawns = []
	for key in map.spawnPoints:
		if map.spawnPoints[key] == "PLAYER":
			spawns.append(Hex.cell(key))
	for i in range(allowed_ids.size()):
		deploy(allowed_ids[i],spawns[i])

func start() -> Array[String]:
	if phase != "DEPLOYMENT":
		return ["目前不在部署階段。"]
	var errors = Rules.validate_deployment(map,units)
	if errors.is_empty():
		turn = 1
		phase = "PLAYER"
	return errors

func can_control(id: String) -> bool:
	var unit = get_unit(id)
	return phase == "PLAYER" and not unit.is_empty() and unit.faction == "PLAYER" and not unit.acted

func reachable(id: String) -> Dictionary:
	var unit = get_unit(id)
	if not can_control(id) or unit.moved:
		return {}
	return Hex.search(map,unit.cell,unit.movement,Rules.occupied(units,id))

func move_unit(id: String, to: Vector3i) -> Array[Vector3i]:
	var search = reachable(id)
	var path = Hex.route(search,to)
	if path.is_empty():
		return path
	var unit = get_unit(id)
	unit.cell = to
	unit.moved = true
	return path

func attack(id: String, target_id: String, skill: bool) -> Dictionary:
	if not can_control(id):
		return {"ok":false}
	var unit = get_unit(id)
	var outcome = Rules.apply_attack(unit,get_unit(target_id),Catalog.action(unit,skill))
	if outcome.ok:
		settle()
	return outcome

func wait_unit(id: String) -> bool:
	if not can_control(id):
		return false
	get_unit(id).acted = true
	settle()
	return true

func end_player_turn() -> void:
	if phase != "PLAYER":
		return
	for unit in units:
		if unit.faction == "PLAYER":
			unit.acted = true
	settle()

func settle() -> void:
	units = units.filter(func(u): return u.hp > 0)
	result = Rules.outcome(units)
	if not result.is_empty():
		phase = "RESULT"
		return
	if phase == "PLAYER" and units.filter(func(u): return u.faction == "PLAYER" and not u.acted).is_empty():
		phase = "ENEMY"

func enemy_plan(id: String) -> Dictionary:
	var unit = get_unit(id)
	if phase != "ENEMY" or unit.is_empty() or unit.faction != "ENEMY":
		return {"path":[], "target_id":"", "cost":0}
	return Rules.plan_ai(map,unit,units,Catalog.action(unit))

func commit_enemy(id: String, plan: Dictionary) -> Dictionary:
	var unit = get_unit(id)
	if phase != "ENEMY" or unit.is_empty() or unit.faction != "ENEMY" or unit.acted:
		return {"ok":false}
	if not plan.path.is_empty():
		# Validate a plan again against current occupancy and movement budget.
		var reachable_result = Hex.search(map,unit.cell,unit.movement,Rules.occupied(units,id))
		var destination: Vector3i = plan.path[-1]
		if not reachable_result.costs.has(Hex.key(destination)):
			return {"ok":false}
		unit.cell = destination
	var target = get_unit(str(plan.target_id))
	var hit = Rules.apply_attack(unit,target,Catalog.action(unit))
	unit.acted = true
	settle()
	return hit

func next_round() -> bool:
	if phase != "ENEMY":
		return false
	for unit in units:
		if unit.faction == "ENEMY" and not unit.acted:
			return false
	turn += 1
	for unit in units:
		unit.acted = false
		unit.moved = false
	phase = "PLAYER"
	return true

func abandon() -> void:
	revision += 1
	phase = "MENU"
	units.clear()
	result = ""
