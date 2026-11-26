class_name BattleSession
extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
const Mission = preload("res://core/mission_rules.gd")
const Catalog = preload("res://core/catalog.gd")

var map: Dictionary = {}
var units: Array = []
var allowed_ids: Array = []
var phase = "MENU"
var turn = 1
var result = ""
var result_reason = ""
var mission: Dictionary = {}
var revision = 0
var inventory: Dictionary = {}
var pending_loot: Dictionary = {}
var opened_chests: Dictionary = {}
var defeated_ids: Dictionary = {}
var loadouts: Dictionary = {}
var history: Array = []
var rng = RandomNumberGenerator.new()
var battle_id = ""
var settled = false

func prepare(new_map: Dictionary, roster_ids: Array, enemy_ids: Array, config: Dictionary = {}) -> Array[String]:
	var errors = Hex.validate_map(new_map)
	errors.append_array(Catalog.validate_chest_tables(new_map))
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
	if not config.is_empty():
		errors.append_array(Mission.validate(config,new_map))
		errors.append_array(Mission.selection_errors(config,roster_ids))
	if not errors.is_empty():
		return errors
	mission = config.duplicate(true)
	result_reason = ""
	map = new_map.duplicate(true)
	allowed_ids = roster_ids.duplicate()
	units = []
	turn = 1
	result = ""
	phase = "DEPLOYMENT"
	inventory = Catalog.data().get("starter_inventory",{}).duplicate(true)
	pending_loot = {}
	opened_chests = {}
	defeated_ids = {}
	loadouts = {}
	history = []
	rng.randomize()
	battle_id = Crypto.new().generate_random_bytes(16).hex_encode()
	settled = false
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
	var unit = Catalog.player(id,at)
	Catalog.equip_unit(unit,loadouts.get(id,{}))
	units.append(unit)
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
	for id in Mission.required(mission):
		if get_unit(id).is_empty(): errors.append("尚未部署必出角色："+Catalog.player(id,Vector3i.ZERO).name)
	if errors.is_empty():
		turn = 1
		phase = "PLAYER"
		capture_round()
		check_mission()
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
	check_mission()
	return path

func attack(id: String, target_id: String, skill: bool) -> Dictionary:
	if not can_control(id):
		return {"ok":false}
	var unit = get_unit(id)
	var outcome = resolve_attack(unit,get_unit(target_id),Catalog.action(unit,skill))
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
	for unit in units:
		if unit.hp<=0 and unit.faction=="ENEMY" and not defeated_ids.has(unit.id):
			defeated_ids[unit.id] = true
			roll_loot(str(unit.get("loot_table","")))
	units = units.filter(func(u): return u.hp > 0)
	if check_mission(): return
	if phase == "PLAYER" and units.filter(func(u): return u.faction == "PLAYER" and not u.acted).is_empty():
		phase = "ENEMY"

func enemy_plan(id: String) -> Dictionary:
	var unit = get_unit(id)
	if phase != "ENEMY" or unit.is_empty() or unit.faction != "ENEMY":
		return {"path":[], "target_id":"", "cost":0}
	var skill_action = Catalog.action(unit,true)
	var use_skill = unit.job=="mage" and unit.mp>=skill_action.mp_cost
	var plan = Rules.plan_ai(map,unit,units,Catalog.action(unit,use_skill))
	plan.skill = use_skill
	return plan

func commit_enemy(id: String, plan: Dictionary) -> Dictionary:
	var unit = get_unit(id)
	if phase != "ENEMY" or unit.is_empty() or unit.faction != "ENEMY" or unit.acted:
		return {"ok":false}
	unit.guard = 0
	if not plan.path.is_empty():
		# Validate a plan again against current occupancy and movement budget.
		var reachable_result = Hex.search(map,unit.cell,unit.movement,Rules.occupied(units,id))
		var destination: Vector3i = plan.path[-1]
		if not reachable_result.costs.has(Hex.key(destination)):
			return {"ok":false}
		unit.cell = destination
	var target = get_unit(str(plan.target_id))
	var hit = resolve_attack(unit,target,Catalog.action(unit,bool(plan.get("skill",false))))
	if not hit.ok and unit.job=="knight" and unit.mp>=Catalog.action(unit,true).mp_cost:
		unit.guard = int(Catalog.action(unit,true).get("guard",3))
		unit.mp -= int(Catalog.action(unit,true).mp_cost)
	unit.acted = true
	settle()
	return hit

func next_round() -> bool:
	if phase != "ENEMY":
		return false
	for unit in units:
		if unit.faction == "ENEMY" and not unit.acted:
			return false
	if check_mission(true): return true
	turn += 1
	for unit in units:
		unit.acted = false
		unit.moved = false
		if unit.faction=="PLAYER": unit.guard = 0
	phase = "PLAYER"
	capture_round()
	return true

func abandon() -> void:
	revision += 1
	phase = "MENU"
	units.clear()
	result = ""

func resolve_attack(actor: Dictionary, target: Dictionary, action: Dictionary) -> Dictionary:
	if not Rules.can_attack(actor,target,action) or action.get("effect","")=="guard": return {"ok":false,"damage":0}
	var victims = [target]
	if int(action.get("radius",0))>0:
		victims = units.filter(func(u): return u.faction!=actor.faction and u.hp>0 and Hex.distance(u.cell,target.cell)<=int(action.radius))
	var primary = Rules.apply_attack(actor,target,action)
	if not primary.ok: return primary
	primary.hits = [{"id":target.id,"cell":target.cell,"damage":primary.damage}]
	for other in victims:
		if other.id==target.id: continue
		var damage = Rules.damage_for(actor,other,action)
		other.hp = maxi(0,other.hp-damage)
		primary.hits.append({"id":other.id,"cell":other.cell,"damage":damage})
	return primary

func guard_unit(id: String) -> bool:
	if not can_control(id): return false
	var unit = get_unit(id)
	var action = Catalog.action(unit,true)
	if action.get("effect","")!="guard" or unit.mp<int(action.mp_cost): return false
	unit.mp -= int(action.mp_cost)
	unit.guard = int(action.guard)
	unit.acted = true
	settle()
	return true

func use_item(actor_id: String, target_id: String, item_id: String) -> bool:
	if not can_control(actor_id) or int(inventory.get(item_id,0))<=0: return false
	var item = Catalog.data().items.get(item_id,{})
	var actor = get_unit(actor_id)
	var target = get_unit(target_id)
	if item.is_empty() or target.is_empty() or target.faction!="PLAYER" or Hex.distance(actor.cell,target.cell)>int(item.range): return false
	if (int(item.hp)==0 or target.hp>=target.max_hp) and (int(item.mp)==0 or target.mp>=target.max_mp): return false
	target.hp = mini(target.max_hp,target.hp+int(item.hp))
	target.mp = mini(target.max_mp,target.mp+int(item.mp))
	inventory[item_id] -= 1
	# Pending loot is consumed first; settlement always uses remaining inventory.
	if int(pending_loot.get(item_id,0))>0: pending_loot[item_id] -= 1
	actor.acted = true
	settle()
	return true

func open_chest(id: String, cell: Vector3i) -> bool:
	var key = Hex.key(cell)
	if not can_control(id) or opened_chests.has(key) or not map.get("chests",{}).has(key): return false
	var actor = get_unit(id)
	if Hex.distance(actor.cell,cell)>1: return false
	var definition = Catalog.data().chest_tables.get(map.chests[key],{})
	if definition.is_empty(): return false
	opened_chests[key] = true
	roll_loot(definition.loot_table)
	actor.acted = true
	settle()
	return true

func roll_loot(table_id: String) -> void:
	for row in Catalog.data().loot_tables.get(table_id,[]):
		if rng.randf()<float(row.chance):
			var count = rng.randi_range(int(row.min),int(row.max))
			inventory[row.item] = int(inventory.get(row.item,0))+count
			pending_loot[row.item] = int(pending_loot.get(row.item,0))+count

func round_state() -> Dictionary:
	return {"turn":turn,"units":units.duplicate(true),"inventory":inventory.duplicate(true),"pending_loot":pending_loot.duplicate(true),"opened_chests":opened_chests.duplicate(true),"defeated_ids":defeated_ids.duplicate(true),"rng_state":str(rng.state)}

func capture_round() -> void:
	history.append(round_state())

func rewind_to(round_number: int) -> bool:
	if settled or not phase in ["PLAYER","RESULT"]: return false
	for i in range(history.size()):
		if int(history[i].turn)!=round_number: continue
		var state = history[i].duplicate(true)
		units = state.units
		inventory = state.inventory
		pending_loot = state.pending_loot
		opened_chests = state.opened_chests
		defeated_ids = state.defeated_ids
		rng.state = int(state.rng_state)
		turn = round_number
		phase = "PLAYER"
		result = ""
		result_reason = ""
		history.resize(i+1)
		revision += 1
		return true
	return false

func export_rpg() -> Dictionary:
	var value = round_state()
	value.erase("units")
	value.history = history.duplicate(true)
	for state in value.history:
		for unit in state.units: unit.cell = [unit.cell.x,unit.cell.y,unit.cell.z]
	value.battle_id = battle_id
	value.loadouts = loadouts.duplicate(true)
	return value

func import_rpg(value: Dictionary) -> void:
	inventory = value.get("inventory",{}).duplicate(true)
	pending_loot = value.get("pending_loot",{}).duplicate(true)
	for bag in [inventory,pending_loot]:
		for id in bag: bag[id] = int(bag[id])
	opened_chests = value.get("opened_chests",{}).duplicate(true)
	defeated_ids = value.get("defeated_ids",{}).duplicate(true)
	loadouts = value.get("loadouts",{}).duplicate(true)
	battle_id = value.get("battle_id",Crypto.new().generate_random_bytes(16).hex_encode())
	rng.state = int(value.get("rng_state","1"))
	history = value.get("history",[]).duplicate(true)
	for state in history:
		state.turn = int(state.turn)
		for bag in [state.inventory,state.pending_loot]:
			for id in bag: bag[id] = int(bag[id])
		for unit in state.units:
			if unit.cell is Array: unit.cell = Vector3i(int(unit.cell[0]),int(unit.cell[1]),int(unit.cell[2]))
			for field in ["hp","max_hp","mp","max_mp","movement","attack_bonus","magic_bonus","defense","resistance","guard"]:
				if unit.has(field): unit[field] = int(unit[field])
	settled = false
	if history.is_empty(): capture_round()

func check_mission(round_end: bool = false) -> bool:
	var verdict = Mission.evaluate(mission,units,turn,defeated_ids,round_end)
	result = verdict.result
	result_reason = verdict.reason
	if not result.is_empty():
		phase = "RESULT"
		return true
	return false
