extends RefCounted
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const TYPES = ["ANNIHILATION","TARGET","SURVIVE","REACH"]
static func integer(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=lo and value<=hi
static func required(level: Dictionary) -> Array:
	var ids: Array = level.get("requiredIds",[]).duplicate()
	for id in level.get("protectedIds",[]):
		if not ids.has(id): ids.append(id)
	return ids
static func limit(level: Dictionary) -> int:
	return int(level.get("deployLimit",level.get("playerIds",[]).size()))
static func validate(level: Dictionary, map: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	if not TYPES.has(level.get("winCondition")) or level.get("loseCondition")!="PLAYER_DEATH": errors.append("勝敗條件類型無效。")
	var pool = level.get("playerIds",[])
	if not pool is Array or pool.is_empty(): return ["候選角色清單無效。"]
	var pool_seen = {}
	for id in pool:
		if not id is String or not Catalog.roster_ids().has(id) or pool_seen.has(id): errors.append("候選角色清單無效或重複。")
		pool_seen[id] = true
	if not integer(level.get("deployLimit",pool.size()),1,64): errors.append("出戰上限必須為 1–64 的整數。")
	for field in ["requiredIds","protectedIds"]:
		var ids = level.get(field,[])
		if not ids is Array:
			errors.append(field+" 必須為角色清單。")
			continue
		var seen = {}
		for id in ids:
			if not id is String or not pool.has(id) or seen.has(id): errors.append("必出／保護角色不在可選名單或重複。")
			seen[id] = true
	if not errors.is_empty(): return errors
	if required(level).size()>limit(level): errors.append("必出角色超過出戰上限。")
	if not map.is_empty() and limit(level)>map.spawnPoints.values().count("PLAYER"): errors.append("出戰上限超過我方出生格數量。")
	if not integer(level.get("turnLimit",0),0,9999): errors.append("回合上限必須為 0–9999；0 表示不限。")
	if not errors.is_empty(): return errors
	match level.get("winCondition"):
		"TARGET":
			if not integer(level.get("targetEnemyIndex",-1),0,level.get("enemyIds",[]).size()-1): errors.append("請指定有效的敵方目標序號。")
		"SURVIVE":
			if not integer(level.get("surviveTurns",0),1,9999): errors.append("存活回合必須為 1–9999。")
			elif int(level.get("turnLimit",0))>0 and int(level.turnLimit)<int(level.surviveTurns): errors.append("回合上限不能早於存活目標。")
		"REACH":
			var cell = level.get("goalCell",[])
			if not cell is Array or cell.size()!=3:
				errors.append("抵達區域需要三個立方體座標。")
			else:
				for n in cell:
					if not integer(n,-24,24): errors.append("抵達座標必須是有效整數。")
				if errors.is_empty():
					var at = Vector3i(int(cell[0]),int(cell[1]),int(cell[2]))
					if at.x+at.y+at.z!=0 or (not map.is_empty() and Hex.terrain_cost(map,at)<0): errors.append("抵達區域中心必須是可走地圖格。")
			if not integer(level.get("goalRadius",0),0,6): errors.append("抵達區域半徑必須為 0–6。")
	return errors
static func selection_errors(level: Dictionary, ids: Array) -> Array[String]:
	var errors: Array[String] = []
	if ids.is_empty() or ids.size()>limit(level): errors.append("請選擇 1–%d 名出戰角色。" % limit(level))
	var seen = {}
	for id in ids:
		if not level.playerIds.has(id) or seen.has(id): errors.append("出戰名單包含無效或重複角色。")
		seen[id] = true
	for id in required(level):
		if not ids.has(id): errors.append("缺少必出角色："+Catalog.player(id,Vector3i.ZERO).name)
	return errors
static func evaluate(level: Dictionary, units: Array, turn: int, defeated: Dictionary, round_end: bool = false) -> Dictionary:
	var players = units.filter(func(u): return u.faction=="PLAYER" and u.hp>0)
	var enemies = units.filter(func(u): return u.faction=="ENEMY" and u.hp>0)
	if players.is_empty(): return {"result":"DEFEAT","reason":"我方全軍覆沒。"}
	for id in level.get("protectedIds",[]):
		if players.filter(func(u): return u.id==id).is_empty(): return {"result":"DEFEAT","reason":"保護對象已倒下："+Catalog.player(id,Vector3i.ZERO).name}
	var victory = false
	match level.get("winCondition","ANNIHILATION"):
		"ANNIHILATION": victory = enemies.is_empty()
		"TARGET": victory = defeated.has("enemy_%d" % int(level.get("targetEnemyIndex",0)))
		"SURVIVE": victory = round_end and turn>=int(level.get("surviveTurns",1))
		"REACH":
			var c = level.get("goalCell",[0,0,0])
			var center = Vector3i(int(c[0]),int(c[1]),int(c[2]))
			for unit in players:
				if Hex.distance(unit.cell,center)<=int(level.get("goalRadius",0)): victory = true
	if victory: return {"result":"VICTORY","reason":victory_text(level)}
	if round_end and int(level.get("turnLimit",0))>0 and turn>=int(level.turnLimit): return {"result":"DEFEAT","reason":"已達回合上限，尚未完成目標。"}
	return {"result":"","reason":""}
static func victory_text(level: Dictionary) -> String:
	match level.get("winCondition","ANNIHILATION"):
		"TARGET":
			var index = int(level.get("targetEnemyIndex",-1))
			var enemies = level.get("enemyIds",[])
			var name = Catalog.data().enemies.get(enemies[index],{}).get("name","未知") if index>=0 and index<enemies.size() else "未指定"
			return "擊敗第 %d 名 · %s" % [index+1,name]
		"SURVIVE": return "存活至第 %d 回合結束" % int(level.get("surviveTurns",1))
		"REACH": return "任一我方抵達 %s（半徑 %d）" % [str(level.get("goalCell",[0,0,0])),int(level.get("goalRadius",0))]
	return "擊敗全部敵軍"
static func description(level: Dictionary) -> String:
	var text = "勝利："+victory_text(level)+"\n敗北：我方全滅"
	for id in level.get("protectedIds",[]): text += "／"+Catalog.player(id,Vector3i.ZERO).name+"倒下"
	if int(level.get("turnLimit",0))>0: text += "／第%d回合結束未完成" % int(level.turnLimit)
	return text
