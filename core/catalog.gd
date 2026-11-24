class_name GameCatalog
extends RefCounted
const DATA_PATH = "res://data/catalog.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data

static func roster() -> Array:
	return data().roster

static func roster_ids() -> Array:
	return roster().map(func(row): return row.id)

static func unit_from(template: Dictionary, id: String, faction: String, cell: Vector3i) -> Dictionary:
	var job = data().jobs[template.job]
	return {"id":id, "name":template.name, "job":template.job, "faction":faction,
		"cell":cell, "hp":int(template.max_hp), "max_hp":int(template.max_hp),
		"mp":int(job.max_mp), "max_mp":int(job.max_mp), "movement":int(job.movement),
		"acted":false, "moved":false}

static func player(id: String, cell: Vector3i) -> Dictionary:
	for row in roster():
		if row.id == id:
			return unit_from(row,id,"PLAYER",cell)
	return {}

static func enemy(template_id: String, index: int, cell: Vector3i) -> Dictionary:
	if not data().enemies.has(template_id):
		return {}
	return unit_from(data().enemies[template_id],"enemy_%d" % index,"ENEMY",cell)

static func action(unit: Dictionary, skill: bool = false) -> Dictionary:
	var job = data().jobs[unit.job]
	if skill:
		return job.skill.duplicate(true)
	return {"name":"攻擊", "range_min":int(job.range_min), "range_max":int(job.range_max),
		"mp_cost":0, "damage":4 if unit.faction == "PLAYER" else 3}
