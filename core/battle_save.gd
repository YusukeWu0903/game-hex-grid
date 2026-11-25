class_name BattleSave
extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const Session = preload("res://core/battle_session.gd")
const VERSION = 1
const MAX_BYTES = 2097152

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
		"allowed_ids":session.allowed_ids.duplicate(),"units":units}

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("version") != VERSION:
		return invalid("戰鬥存檔版本不支援。")
	if value.get("phase") != "PLAYER" or not integer(value.get("turn"),1,999999):
		return invalid("只能讀取我方回合的有效戰鬥存檔。")
	if not value.get("saved_at") is String:
		return invalid("存檔時間格式錯誤。")
	var errors = Hex.validate_map(value.get("map"))
	if not errors.is_empty():
		return invalid("存檔地圖無效："+"；".join(errors))
	var level = value.get("level")
	if not level is Dictionary:
		return invalid("存檔缺少關卡資料。")
	for field in ["levelId","name","mapId"]:
		if not level.get(field) is String or level[field].strip_edges().is_empty() or level[field].length()>160:
			return invalid("關卡名稱或識別碼格式錯誤。")
	if level.mapId != value.map.mapId or level.get("winCondition") != "ANNIHILATION" or level.get("loseCondition") != "PLAYER_DEATH":
		return invalid("存檔關卡與地圖或勝敗條件不符。")
	if not level.get("playerIds") is Array or not level.get("enemyIds") is Array or not value.get("allowed_ids") is Array:
		return invalid("存檔出戰名單格式錯誤。")
	for id in level.playerIds + level.enemyIds:
		if not id is String:
			return invalid("存檔角色識別碼格式錯誤。")
	if value.allowed_ids != level.playerIds:
		return invalid("存檔出戰名單不一致。")
	var prepared = Session.new()
	errors = prepared.prepare(value.map,level.playerIds,level.enemyIds)
	if not errors.is_empty():
		return invalid("存檔關卡無法準備："+"；".join(errors))
	if not value.get("units") is Array or value.units.is_empty() or value.units.size()>level.playerIds.size()+level.enemyIds.size():
		return invalid("存檔單位數量無效。")
	var normalized = []
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
		if unit.faction == "PLAYER" and level.playerIds.has(unit.id):
			canonical = Catalog.player(unit.id,Vector3i.ZERO)
		elif unit.faction == "ENEMY":
			for i in range(level.enemyIds.size()):
				if unit.id == "enemy_%d" % i:
					canonical = Catalog.enemy(level.enemyIds[i],i,Vector3i.ZERO)
		if canonical.is_empty():
			return invalid("存檔包含非出戰角色。")
		for field in ["name","job","max_hp","max_mp","movement"]:
			if unit.get(field) != canonical[field]:
				return invalid("存檔角色資料不符目前規則："+field)
		if not integer(unit.get("hp"),1,canonical.max_hp) or not integer(unit.get("mp"),0,canonical.max_mp):
			return invalid("存檔 HP／MP 超出有效範圍。")
		if not unit.get("acted") is bool or not unit.get("moved") is bool:
			return invalid("存檔行動旗標格式錯誤。")
		if not unit.get("cell") is Array or unit.cell.size()!=3:
			return invalid("存檔座標格式錯誤。")
		for coordinate in unit.cell:
			if not integer(coordinate,-12,12):
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
	if player_count==0 or enemy_count==0 or available_count==0:
		return invalid("此存檔已結束或不在可操作的我方回合。")
	return {"ok":true,"message":"","units":normalized,"map":value.map.duplicate(true),
		"level":level.duplicate(true),"allowed_ids":value.allowed_ids.duplicate(),"turn":int(value.turn),"saved_at":value.saved_at}

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return invalid("尚無戰鬥存檔。")
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		return invalid("無法讀取戰鬥存檔。")
	if file.get_length()>MAX_BYTES:
		file.close()
		return invalid("戰鬥存檔超過 2 MB。")
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
	session.revision += 1
