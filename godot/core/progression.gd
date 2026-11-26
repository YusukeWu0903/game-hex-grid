extends RefCounted
const Catalog = preload("res://core/catalog.gd")
const CAP = 20

static func threshold(level: int) -> int:
	return int(Catalog.data().progression.thresholds[clampi(level,1,CAP)-1])

static func level_for(exp_value: int) -> int:
	var level = 1
	while level<CAP and exp_value>=threshold(level+1): level += 1
	return level

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if not Catalog.roster_ids().has(id): return false
		var xp = value[id]
		if not (xp is int or xp is float) or not is_finite(float(xp)) or xp!=floorf(float(xp)) or xp<0 or xp>threshold(CAP): return false
	return true

static func apply(unit: Dictionary, level: int) -> void:
	# Apply once to a fresh catalog unit, before equipment.
	unit.level = clampi(level,1,CAP)
	var growth = Catalog.data().progression.growth[unit.job]
	for field in ["max_hp","max_mp","attack_bonus","magic_bonus","defense","resistance"]:
		unit[field] += int(floor(float(growth[field])*(unit.level-1)/100.0))
	unit.hp = unit.max_hp
	unit.mp = unit.max_mp

static func describe(exp_value: int) -> String:
	var level = level_for(exp_value)
	if level==CAP: return "Lv.20 · 已達上限"
	return "Lv.%d · EXP %d／%d" % [level,exp_value-threshold(level),threshold(level+1)-threshold(level)]
