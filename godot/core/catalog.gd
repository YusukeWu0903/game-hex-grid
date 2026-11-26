class_name GameCatalog
extends RefCounted
const DATA_PATH = "res://data/catalog.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = normalize_numbers(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)))
	return _data

static func roster() -> Array:
	return data().roster

static func normalize_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value: value[key] = normalize_numbers(value[key])
	elif value is Array:
		for i in range(value.size()): value[i] = normalize_numbers(value[i])
	elif value is float and value == floorf(value):
		return int(value)
	return value

static func roster_ids() -> Array:
	return roster().map(func(row): return row.id)

static func unit_from(template: Dictionary, id: String, faction: String, cell: Vector3i) -> Dictionary:
	var job = data().jobs[template.job]
	return {"id":id, "name":template.name, "job":template.job, "faction":faction,
		"cell":cell, "hp":int(template.max_hp), "max_hp":int(template.max_hp),
		"mp":int(job.max_mp), "max_mp":int(job.max_mp), "movement":int(job.movement),
		"acted":false, "moved":false,"equipment":{},"attack_bonus":0,"magic_bonus":0,
		"defense":int(job.get("defense",0)),"resistance":int(job.get("resistance",0)),"guard":0,
		"loot_table":template.get("loot_table",""),"template_id":template.get("id","")}

static func player(id: String, cell: Vector3i) -> Dictionary:
	for row in roster():
		if row.id == id:
			return unit_from(row,id,"PLAYER",cell)
	return {}

static func enemy(template_id: String, index: int, cell: Vector3i) -> Dictionary:
	if not data().enemies.has(template_id):
		return {}
	var unit = unit_from(data().enemies[template_id],"enemy_%d" % index,"ENEMY",cell)
	unit.template_id = template_id
	return unit

static func action(unit: Dictionary, skill: bool = false) -> Dictionary:
	var job = data().jobs[unit.job]
	if skill:
		return job.skill.duplicate(true)
	return {"name":"魔彈" if unit.job=="mage" else "攻擊", "range_min":int(job.range_min), "range_max":int(job.range_max),
		"mp_cost":int(job.get("attack_mp_cost",0)), "damage":int(job.get("attack_damage",4)) if unit.faction == "PLAYER" else int(job.get("enemy_damage",3)),"damage_type":job.get("damage_type","physical")}

static func item_name(id: String) -> String:
	return str(data().get("items",{}).get(id,data().get("equipment",{}).get(id,{"name":id})).name)

static func equip_unit(unit: Dictionary, equipment: Dictionary) -> void:
	unit.equipment = equipment.duplicate()
	for slot in equipment:
		var item = data().equipment.get(equipment[slot],{})
		if item.is_empty() or item.slot!=slot or not item.jobs.has(unit.job): continue
		unit.attack_bonus += int(item.attack)
		unit.magic_bonus += int(item.magic)
		unit.defense += int(item.defense)
		unit.resistance += int(item.resistance)
		unit.max_hp += int(item.hp)
		unit.max_mp += int(item.mp)
	unit.hp = unit.max_hp
	unit.mp = unit.max_mp

static func validate_chest_tables(map_value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if map_value is Dictionary and map_value.get("chests",{}) is Dictionary:
		for table_id in map_value.get("chests",{}).values():
			if not data().get("chest_tables",{}).has(table_id):
				errors.append("未知寶箱表：" + str(table_id))
	return errors
