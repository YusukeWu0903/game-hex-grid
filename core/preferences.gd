class_name GamePreferences
extends RefCounted
const Saves = preload("res://core/battle_save.gd")
const DEFAULTS = {"sound":true,"reduced_motion":false,"cinematics":true,"volume":100}
var values = DEFAULTS.duplicate()
var path: String
var error = ""
func _init(file_path: String) -> void:
	path = file_path
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		error = "無法讀取設定，使用預設值。"
		return
	if file.get_length()>16384:
		file.close()
		error = "設定檔過大，使用預設值。"
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary or data.get("version") != 1:
		error = "設定檔無效，使用預設值；原檔保留。"
		return
	for key in ["sound","reduced_motion","cinematics"]:
		if data.get(key) is bool:
			values[key] = data[key]
	if Saves.integer(data.get("volume"),0,100):
		values.volume = int(data.volume)
func save() -> String:
	var payload = values.duplicate()
	payload.version = 1
	error = Saves.write_json(path,payload)
	return error
