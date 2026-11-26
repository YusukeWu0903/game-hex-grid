class_name BattleSave
extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const Mission = preload("res://core/mission_rules.gd")
const Session = preload("res://core/battle_session.gd")
const Progression = preload("res://core/progression.gd")
const VERSION = 2
const MAX_BYTES = 33554432

static func invalid(message: String) -> Dictionary:
	return {"ok":false,"message":message}

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

static func snapshot(session: RefCounted, level: Dictionary) -> Dictionary:
	var units = session.units.duplicate(true)
	for unit in units:
		unit.cell = [unit.cell.x,unit.cell.y,unit.cell.z]
	return {"version":VERSION,"saved_at":Time.get_datetime_string_from_system(),"phase":session.phase,
		"turn":session.turn,"map":session.map.duplicate(true),"level":level.duplicate(true),
		"allowed_ids":session.allowed_ids.duplicate(),"units":units,"rpg":session.export_rpg()}

static func validate(value: Variant, shared_static: bool = false) -> Dictionary:
	if not value is Dictionary or (value.get("version") != 1 and value.get("version") != VERSION):
		return invalid("戰鬥存檔版本不支援。")
	if value.get("phase") != "PLAYER" or not integer(value.get("turn"),1,999999):
		return invalid("只能讀取我方回合的有效戰鬥存檔。")
	if not value.get("saved_at") is String:
		return invalid("存檔時間格式錯誤。")
	var errors: Array[String] = []
	if not shared_static: errors = Hex.validate_map(value.get("map"))
	if not errors.is_empty():
		return invalid("存檔地圖無效："+"；".join(errors))
	var level = value.get("level")
	if not level is Dictionary:
		return invalid("存檔缺少關卡資料。")
	for field in ["levelId","name","mapId"]:
		if not level.get(field) is String or level[field].strip_edges().is_empty() or level[field].length()>160:
			return invalid("關卡名稱或識別碼格式錯誤。")
	if level.mapId != value.map.mapId:
		return invalid("存檔關卡與地圖或勝敗條件不符。")
	if not level.get("playerIds") is Array or not level.get("enemyIds") is Array or not value.get("allowed_ids") is Array:
		return invalid("存檔出戰名單格式錯誤。")
	for id in level.playerIds + level.enemyIds:
		if not id is String:
			return invalid("存檔角色識別碼格式錯誤。")
	if not Mission.validate(level,value.map).is_empty() or not Mission.selection_errors(level,value.allowed_ids).is_empty():
		return invalid("存檔出戰名單不一致。")
	if int(level.get("turnLimit",0))>0 and int(value.turn)>int(level.turnLimit): return invalid("存檔已超過任務回合上限。")
	if level.get("winCondition")=="SURVIVE" and int(value.turn)>int(level.get("surviveTurns",0)): return invalid("存活任務回合無效。")
	if not shared_static:
		var prepared = Session.new()
		errors = prepared.prepare(value.map,value.allowed_ids,level.enemyIds,level)
		if not errors.is_empty():
			return invalid("存檔關卡無法準備："+"；".join(errors))
	if not value.get("units") is Array or value.units.is_empty() or value.units.size()>level.playerIds.size()+level.enemyIds.size():
		return invalid("存檔單位數量無效。")
	var normalized = []
	var saved_rpg = value.get("rpg",{})
	if not saved_rpg is Dictionary or not Progression.valid(saved_rpg.get("progression",{})): return invalid("角色經驗資料無效。")
	var progress = saved_rpg.get("progression",{})
	var seen_ids = {}
	var seen_cells = {}
	var player_count = 0
	var enemy_count = 0
	var available_count = 0
	for unit in value.units:
		if not unit is Dictionary or not unit.get("id") is String or not unit.get("faction") is String:
			return invalid("存檔單位格式錯誤。")
		if seen_ids.has(unit.id):
			return invalid("存檔單位 ID 重複。")
		seen_ids[unit.id] = true
		var canonical = {}
		if unit.faction == "PLAYER" and value.allowed_ids.has(unit.id):
			canonical = Catalog.player(unit.id,Vector3i.ZERO)
			Progression.apply(canonical,Progression.level_for(int(progress.get(unit.id,0))))
		elif unit.faction == "ENEMY":
			for i in range(level.enemyIds.size()):
				if unit.id == "enemy_%d" % i:
					canonical = Catalog.enemy(level.enemyIds[i],i,Vector3i.ZERO)
					Progression.apply(canonical,int(level.enemyLevels[i]) if level.has("enemyLevels") else 1)
		if canonical.is_empty():
			return invalid("存檔包含非出戰角色。")
		var equipment = unit.get("equipment",{})
		if not equipment is Dictionary: return invalid("裝備欄位格式錯誤。")
		for slot in equipment:
			var gear = Catalog.data().equipment.get(equipment[slot],{})
			if gear.is_empty() or gear.slot!=slot or not gear.jobs.has(canonical.job): return invalid("裝備限制錯誤。")
		Catalog.equip_unit(canonical,equipment)
		if not integer(unit.get("guard",0),0,100): return invalid("防守狀態無效。")
		canonical.guard = int(unit.get("guard",0))
		if canonical.guard!=0 and canonical.guard!=int(Catalog.action(canonical,true).get("guard",0)): return invalid("防守加成不符職業。")
		for field in ["level","name","job","max_hp","max_mp","movement","attack_bonus","magic_bonus","defense","resistance"]:
			if unit.get(field,canonical[field]) != canonical[field]:
				return invalid("存檔角色資料不符目前規則："+field)
		if not integer(unit.get("hp"),1,canonical.max_hp) or not integer(unit.get("mp"),0,canonical.max_mp):
			return invalid("存檔 HP／MP 超出有效範圍。")
		if not unit.get("acted") is bool or not unit.get("moved") is bool:
			return invalid("存檔行動旗標格式錯誤。")
		if not unit.get("cell") is Array or unit.cell.size()!=3:
			return invalid("存檔座標格式錯誤。")
		for coordinate in unit.cell:
			if not integer(coordinate,-24,24):
				return invalid("存檔座標超界。")
		var cell = Vector3i(int(unit.cell[0]),int(unit.cell[1]),int(unit.cell[2]))
		if Hex.terrain_cost(value.map,cell)<0 or seen_cells.has(Hex.key(cell)):
			return invalid("存檔角色重疊或位於不可通行格。")
		seen_cells[Hex.key(cell)] = true
		canonical.cell = cell
		canonical.hp = int(unit.hp)
		canonical.mp = int(unit.mp)
		canonical.acted = unit.acted
		canonical.moved = unit.moved
		normalized.append(canonical)
		if unit.faction == "PLAYER":
			player_count += 1
			if not unit.acted:
				available_count += 1
		else:
			enemy_count += 1
			if unit.acted or unit.moved:
				return invalid("我方回合的敵方行動旗標錯誤。")
	if player_count==0 or available_count==0:
		return invalid("此存檔已結束或不在可操作的我方回合。")
	var rpg = value.get("rpg",{})
	if value.version==VERSION:
		var rpg_error = validate_rpg(rpg,value)
		if not rpg_error.is_empty(): return invalid(rpg_error)
	if not Mission.evaluate(level,normalized,int(value.turn),rpg.get("defeated_ids",{})).result.is_empty():
		return invalid("此存檔的關卡目標已結束。")
	return {"ok":true,"message":"","rpg":rpg.duplicate(true),"units":normalized,"map":value.map.duplicate(true),
		"level":level.duplicate(true),"allowed_ids":value.allowed_ids.duplicate(),"turn":int(value.turn),"saved_at":value.saved_at}

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return invalid("尚無戰鬥存檔。")
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		return invalid("無法讀取戰鬥存檔。")
	if file.get_length()>MAX_BYTES:
		file.close()
		return invalid("戰鬥存檔超過 32 MB。")
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		return invalid("戰鬥存檔 JSON 損毀；原檔保留。")
	return validate(json.data)

static func write(path: String, payload: Dictionary) -> String:
	var result = validate(payload)
	if not result.ok:
		return result.message
	if JSON.stringify(payload,"\t").to_utf8_buffer().size()>MAX_BYTES:
		return "戰鬥歷史超過存檔 32 MB 上限；原存檔保留。"
	return write_json(path,payload)

static func write_json(path: String, payload: Dictionary) -> String:
	var error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return "無法建立保存目錄："+error_string(error)
	var temp = path+".tmp"
	var file = FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		return "無法寫入保存檔。"
	file.store_string(JSON.stringify(payload,"\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return "寫入失敗；原存檔保留。"
	var backup = path+".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK:
			return "無法更新備份；原存檔保留。"
		if DirAccess.rename_absolute(path,backup)!=OK:
			return "無法建立備份；原存檔保留。"
	if DirAccess.rename_absolute(temp,path)!=OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup,path)
		return "無法完成保存。"
	return ""

static func restore(session: RefCounted, loaded: Dictionary) -> void:
	# Only called after validation, so no partially restored live state is exposed.
	session.map = loaded.map.duplicate(true)
	session.units = loaded.units.duplicate(true)
	session.allowed_ids = loaded.allowed_ids.duplicate()
	session.turn = loaded.turn
	session.phase = "PLAYER"
	session.result = ""
	session.result_reason = ""
	session.mission = loaded.level.duplicate(true)
	session.revision += 1
	session.import_rpg(loaded.get("rpg",{}))

static func validate_rpg(rpg: Variant, payload: Dictionary) -> String:
	if not rpg is Dictionary: return "缺少戰鬥擴充資料。"
	if not preload("res://core/story_dialogue.gd").valid(rpg.get("story",{"seen":[],"log":[]}),str(payload.level.get("levelId",""))): return "劇情紀錄無效。"
	if not Progression.valid(rpg.get("progression",{})): return "角色經驗資料無效。"
	if not rpg.get("pending_exp",{}) is Dictionary: return "暫存經驗格式無效。"
	for id in rpg.get("pending_exp",{}):
		if not payload.allowed_ids.has(id) or not integer(rpg.pending_exp[id],0,999999): return "暫存經驗資料無效。"
	for field in ["inventory","pending_loot","opened_chests","defeated_ids","loadouts"]:
		if not rpg.get(field) is Dictionary: return "擴充欄位無效："+field
	for field in ["inventory","pending_loot"]:
		for id in rpg[field]:
			if not Catalog.data().items.has(id) and not Catalog.data().equipment.has(id): return "未知背包物品。"
			if not integer(rpg[field][id],0,999999): return "背包數量無效。"
	for id in rpg.pending_loot:
		if int(rpg.pending_loot[id])>int(rpg.inventory.get(id,0)): return "暫存戰利品超出背包。"
	for key in rpg.opened_chests:
		if not payload.map.get("chests",{}).has(key) or rpg.opened_chests[key]!=true: return "已開箱資料無效。"
	for id in rpg.defeated_ids:
		if not id is String or not id.begins_with("enemy_") or not id.trim_prefix("enemy_").is_valid_int() or not rpg.defeated_ids[id] is bool or not rpg.defeated_ids[id]: return "擊殺紀錄無效。"
		if int(id.trim_prefix("enemy_"))<0 or int(id.trim_prefix("enemy_"))>=payload.level.enemyIds.size(): return "擊殺角色超出關卡名單。"
	var allocation = {}
	for id in rpg.loadouts:
		if not Catalog.roster_ids().has(id) or not rpg.loadouts[id] is Dictionary: return "隊伍裝備資料無效。"
		var player = Catalog.player(id,Vector3i.ZERO)
		for slot in rpg.loadouts[id]:
			var item_id = rpg.loadouts[id][slot]
			var gear = Catalog.data().equipment.get(item_id,{})
			if gear.is_empty() or gear.slot!=slot or not gear.jobs.has(player.job): return "隊伍裝備限制錯誤。"
			allocation[item_id] = int(allocation.get(item_id,0))+1
	for id in allocation:
		if allocation[id]>int(rpg.inventory.get(id,0)): return "裝備數量不足。"
	if not rpg.get("rng_state") is String or not rpg.rng_state.is_valid_int(): return "隨機狀態無效。"
	if not rpg.get("battle_id") is String or rpg.battle_id.is_empty(): return "缺少戰鬥識別碼。"
	if not rpg.get("history") is Array: return "回溯紀錄無效。"
	var last_turn = 0
	for state in rpg.history:
		if not state is Dictionary or not integer(state.get("turn"),1,int(payload.turn)) or int(state.turn)<=last_turn: return "回溯回合順序無效。"
		last_turn = int(state.turn)
		var candidate = payload.duplicate(false)
		candidate.turn = state.turn
		candidate.units = state.get("units")
		candidate.rpg = state.duplicate(true)
		candidate.rpg.battle_id = rpg.battle_id
		candidate.rpg.loadouts = rpg.loadouts
		candidate.rpg.progression = rpg.get("progression",{})
		candidate.rpg.history = []
		var checked = validate(candidate,true)
		if not checked.ok: return "回溯紀錄："+checked.message
	return ""
