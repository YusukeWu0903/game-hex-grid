extends RefCounted
const Catalog = preload("res://core/catalog.gd")
const Saves = preload("res://core/battle_save.gd")
const Progression = preload("res://core/progression.gd")
var progression: Dictionary = {}
var path: String
var inventory: Dictionary = {}
var loadouts: Dictionary = {}
var settled_ids: Dictionary = {}
var error = ""
var pending_ending: Dictionary = {}
func _init(file_path: String) -> void:
	path = file_path
	inventory = Catalog.data().starter_inventory.duplicate(true)
	loadouts = Catalog.data().default_loadouts.duplicate(true)
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or parsed.get("version")!=1 or not parsed.get("settled_ids") is Dictionary or not valid_bag(parsed.get("inventory")) or not valid_loadouts(parsed.get("loadouts"),parsed.inventory):
			error = "隊伍存檔損毀，請保留原檔並恢復備份；暫停寫入。"
			return
		inventory = parsed.inventory
		if not Progression.valid(parsed.get("progression",{})):
			error = "隊伍經驗資料損毀；暫停寫入。"
			return
		progression = Catalog.normalize_numbers(parsed.get("progression",{}))
		for id in inventory: inventory[id] = int(inventory[id])
		loadouts = parsed.loadouts
		settled_ids = parsed.settled_ids
		var ending = parsed.get("pending_ending",{})
		if not ending is Dictionary or (not ending.is_empty() and (not settled_ids.has(ending.get("battle_id","")) or not Catalog.data().get("chapter_rules",{}).has(ending.get("level_id","")))):
			error = "結尾劇情進度無效；暫停寫入。"
			return
		pending_ending = ending

static func valid_bag(value: Variant) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if not Catalog.data().equipment.has(id) and not Catalog.data().items.has(id): return false
		if not Saves.integer(value[id],0,999999): return false
	return true

static func valid_loadouts(value: Variant, bag: Dictionary) -> bool:
	if not value is Dictionary: return false
	var allocated = {}
	for id in value:
		if not Catalog.roster_ids().has(id) or not value[id] is Dictionary: return false
		var unit = Catalog.player(id,Vector3i.ZERO)
		for slot in value[id]:
			var item_id = value[id][slot]
			var item = Catalog.data().equipment.get(item_id,{})
			if item.is_empty() or item.slot!=slot or not item.jobs.has(unit.job): return false
			allocated[item_id] = int(allocated.get(item_id,0))+1
	for id in allocated:
		if allocated[id]>int(bag.get(id,0)): return false
	return true

func equip(id: String, slot: String, item_id: String) -> String:
	if not error.is_empty(): return error
	var next = loadouts.duplicate(true)
	if not next.has(id): next[id] = {}
	if item_id.is_empty(): next[id].erase(slot)
	else: next[id][slot] = item_id
	if not valid_loadouts(next,inventory): return "職業不符或裝備數量不足。"
	var failure = save_payload(inventory,next,settled_ids)
	if failure.is_empty(): loadouts = next
	return failure

func claim(session: RefCounted) -> String:
	if not error.is_empty(): return error
	if session.phase!="RESULT" or session.result!="VICTORY": return "只有戰鬥勝利才能結算。"
	if settled_ids.has(session.battle_id):
		session.settled = true
		return ""
	if not pending_ending.is_empty(): return "請先完成上一場已結算的結尾劇情。"
	if not valid_bag(session.inventory) or not valid_loadouts(loadouts,session.inventory): return "戰鬥背包資料無效。"
	var next = settled_ids.duplicate()
	next[session.battle_id] = true
	var next_progress = progression.duplicate(true)
	var results = {}
	for id in session.pending_exp:
		if not Catalog.roster_ids().has(id) or not session.allowed_ids.has(id) or not Saves.integer(session.pending_exp[id],0,999999): return "戰鬥經驗資料無效。"
		var before = int(next_progress.get(id,0))
		var after = mini(Progression.threshold(20),before+int(session.pending_exp[id]))
		next_progress[id] = after
		results[id] = {"before":before,"after":after,"gained":after-before}
	var ending = pending_ending.duplicate(true)
	if Catalog.data().get("chapter_rules",{}).has(session.mission.get("levelId","")):
		ending = {"battle_id":session.battle_id,"level_id":session.mission.levelId}
	var failure = save_payload(session.inventory,loadouts,next,next_progress,ending)
	if failure.is_empty():
		inventory = session.inventory.duplicate(true)
		settled_ids = next
		progression = next_progress
		session.experience_results = results
		session.settled = true
		pending_ending = ending
	return failure

func save_payload(bag: Dictionary, gear: Dictionary, ids: Dictionary, experience: Variant = null, ending: Variant = null) -> String:
	return Saves.write_json(path,{"version":1,"inventory":bag,"loadouts":gear,"settled_ids":ids,"progression":progression if experience==null else experience,"pending_ending":pending_ending if ending==null else ending})

func finish_ending() -> String:
	if not error.is_empty(): return error
	var failure = save_payload(inventory,loadouts,settled_ids,null,{})
	if failure.is_empty(): pending_ending = {}
	return failure
