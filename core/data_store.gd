class_name GameDataStore
extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
var maps: Array = []
var levels: Array = []
var last_error = ""
var storage_path: String

func _init(custom_path: String = "") -> void:
	if not custom_path.is_empty():
		storage_path = custom_path
	else:
		var env_path = OS.get_environment("HEX_TACTICS_DATA_DIR")
		if not env_path.is_empty():
			storage_path = env_path.path_join("library.json")
		elif OS.has_feature("editor"):
			storage_path = ProjectSettings.globalize_path("res://user_data/library.json")
		else:
			storage_path = "user://library.json"
	load_library()

func default_level(map_id: String = "map_custom") -> Dictionary:
	return {"levelId":"level_default","name":"邊境演練","mapId":map_id,
		"playerIds":Catalog.roster_ids(),
		"enemyIds":["enemy_swordsman_base","enemy_archer_base","enemy_heavy_guard"],
		"winCondition":"ANNIHILATION","loseCondition":"PLAYER_DEATH"}

func load_library() -> void:
	maps = []
	levels = []
	for filename in ["map_tutorial","map_001"]:
		maps.append(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/"+filename+".json")))
	levels.append(default_level())
	if not FileAccess.file_exists(storage_path):
		return
	var value = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
	if not value is Dictionary or value.get("version") != 1 or not value.get("maps") is Array or not value.get("levels") is Array:
		last_error = "存檔格式不符，已載入內建資料；原檔保留。"
		return
	for map_value in value.maps:
		var errors = Hex.validate_map(map_value)
		if not errors.is_empty():
			last_error = "存檔包含無效地圖，已跳過；原檔保留。"
			continue
		upsert(maps,map_value,"mapId")
	for level in value.levels:
		if validate_level(level,false).is_empty():
			upsert(levels,level,"levelId")
		else:
			last_error = "存檔包含無效關卡，已跳過；原檔保留。"

func map_by_id(id: String) -> Dictionary:
	for map in maps:
		if map.mapId == id:
			return map
	return {}

func upsert(list: Array, value: Dictionary, id_key: String) -> void:
	for i in range(list.size()):
		if list[i][id_key] == value[id_key]:
			list[i] = value.duplicate(true)
			return
	list.append(value.duplicate(true))

func validate_level(value: Variant, require_playable: bool = true) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return ["關卡必須是 JSON 物件。"]
	for key in ["levelId","name","mapId"]:
		if not value.get(key) is String or str(value.get(key,"")).strip_edges().is_empty():
			errors.append("關卡缺少 " + key)
	if not errors.is_empty():
		return errors
	var map = map_by_id(value.mapId)
	if map.is_empty() and require_playable:
		errors.append("找不到地圖：" + value.mapId)
	if value.get("winCondition","") != "ANNIHILATION" or value.get("loseCondition","") != "PLAYER_DEATH":
		errors.append("此版本僅支援敵方全滅／我方全滅。")
	for key in ["playerIds","enemyIds"]:
		if not value.get(key) is Array or value[key].is_empty():
			errors.append(key + " 必須包含至少一個單位。")
	if not errors.is_empty():
		return errors
	var seen = {}
	for id in value.playerIds:
		if not id is String or not Catalog.roster_ids().has(id) or seen.has(str(id)):
			errors.append("無效或重複的出戰 ID：" + str(id))
		seen[str(id)] = true
	for id in value.enemyIds:
		if not id is String or not Catalog.data().enemies.has(id):
			errors.append("無效敵人：" + str(id))
	if not map.is_empty() and require_playable:
		var p_count = map.spawnPoints.values().count("PLAYER")
		var e_count = map.spawnPoints.values().count("ENEMY")
		if value.playerIds.size() > p_count:
			errors.append("我方出生點不足。")
		if value.enemyIds.size() > e_count:
			errors.append("敵方出生點不足。")
	return errors

func save_map(value: Dictionary) -> Array[String]:
	var errors = Hex.validate_map(value)
	if not errors.is_empty():
		return errors
	var old_maps = maps.duplicate(true)
	upsert(maps,value,"mapId")
	if not persist():
		maps = old_maps
		return [last_error]
	return errors

func save_level(value: Dictionary) -> Array[String]:
	var errors = validate_level(value)
	if not errors.is_empty():
		return errors
	var old_levels = levels.duplicate(true)
	upsert(levels,value,"levelId")
	if not persist():
		levels = old_levels
		return [last_error]
	return errors

func persist() -> bool:
	var payload = {"version":1,"maps":maps,"levels":levels}
	var directory = storage_path.get_base_dir()
	var err = DirAccess.make_dir_recursive_absolute(directory)
	if err != OK:
		last_error = "無法建立保存目錄：" + error_string(err)
		return false
	var temp_path = storage_path + ".tmp"
	var file = FileAccess.open(temp_path,FileAccess.WRITE)
	if file == null:
		last_error = "無法寫入存檔：" + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload,"\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "寫入存檔失敗：" + error_string(write_error)
		return false
	if FileAccess.file_exists(storage_path):
		var backup = storage_path + ".bak"
		if FileAccess.file_exists(backup):
			if DirAccess.remove_absolute(backup) != OK:
				last_error = "無法更新存檔備份。"
				return false
		if DirAccess.rename_absolute(storage_path,backup) != OK:
			last_error = "無法保留原存檔。"
			return false
	var commit_error = DirAccess.rename_absolute(temp_path,storage_path)
	if commit_error != OK:
		if FileAccess.file_exists(storage_path+".bak"):
			DirAccess.rename_absolute(storage_path+".bak",storage_path)
		last_error = "無法完成保存：" + error_string(commit_error)
		return false
	last_error = ""
	return true

func import_map(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false,"message":"找不到檔案。"}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return {"ok":false,"message":"地圖檔案無法讀取或超過 1 MB。"}
	var parser = JSON.new()
	var parse_error = parser.parse(file.get_as_text())
	if parse_error != OK:
		return {"ok":false,"message":"JSON 格式錯誤，第 %d 行。" % parser.get_error_line()}
	var value = parser.data
	var errors = Hex.validate_map(value)
	if not errors.is_empty():
		return {"ok":false,"message":"\n".join(errors)}
	return {"ok":true,"map":value}

func export_map(path: String, value: Dictionary) -> String:
	var errors = Hex.validate_map(value)
	if not errors.is_empty():
		return "\n".join(errors)
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return "無法建立匯出檔案。"
	file.store_string(JSON.stringify(value,"\t"))
	file.flush()
	return "" if file.get_error() == OK else "匯出失敗。"
