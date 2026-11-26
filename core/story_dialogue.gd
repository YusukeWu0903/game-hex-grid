extends RefCounted
# Native port of DialogueFlowSession / DialogueReading's linear playback contract.
const Catalog = preload("res://core/catalog.gd")

static func fresh() -> Dictionary:
	return {"seen":[],"log":[]}

static func events(level_id: String) -> Array:
	return Catalog.data().get("dialogue_events",[]).filter(func(e): return e.level_id == level_id)

static func collect(battle) -> Array:
	var queue: Array = []
	for event in events(str(battle.mission.get("levelId",""))):
		if battle.story.seen.has(event.id): continue
		var matches = false
		match event.trigger:
			"CHEST": matches = battle.opened_chests.has("%d,%d,%d" % [int(event.q),int(event.r),-int(event.q)-int(event.r)])
			"START": matches = battle.turn == 1 and battle.phase == "PLAYER"
			"TURN": matches = battle.turn == int(event.turn) and battle.phase == "PLAYER"
			"VICTORY", "DEFEAT": matches = battle.result == event.trigger
			"AREA":
				if battle.phase != "PLAYER": continue
				var center = Vector3i(int(event.q),int(event.r),-int(event.q)-int(event.r))
				for unit in battle.units:
					if unit.faction != "PLAYER" or (event.actor != "" and unit.id != event.actor): continue
					var delta: Vector3i = unit.cell-center
					if maxi(abs(delta.x),maxi(abs(delta.y),abs(delta.z))) <= int(event.radius): matches = true
		if matches:
			battle.story.seen.append(event.id)
			queue.append_array(Catalog.data().get("dialogues",{}).get(event.script_id,[]))
			break # Keep each event/section independently skippable; re-evaluate after it ends.
	return queue

static func record(state: Dictionary, line_id: String) -> void:
	if not state.log.has(line_id): state.log.append(line_id)

static func section(id: String) -> Array:
	return Catalog.data().get("dialogues",{}).get(id,[]).duplicate(true)

static func trigger(level_id: String, kind: String, state: Dictionary) -> Array:
	var queue: Array = []
	for event in events(level_id):
		if event.trigger != kind or state.seen.has(event.id): continue
		state.seen.append(event.id)
		queue.append_array(section(event.script_id))
	return queue

static func valid(state: Variant, level_id: String) -> bool:
	if not state is Dictionary or not state.get("seen") is Array or not state.get("log") is Array: return false
	var allowed_events = events(level_id)
	var ids = allowed_events.map(func(e): return e.id)
	var lines: Array = []
	for e in allowed_events:
		if state.seen.has(e.id):
			for line in Catalog.data().get("dialogues",{}).get(e.script_id,[]): lines.append(line.id)
	if state.seen.size()>ids.size() or state.log.size()>lines.size(): return false
	var unique = {}
	for id in state.seen:
		if not id is String or not ids.has(id) or unique.has(id): return false
		unique[id] = true
	unique.clear()
	for id in state.log:
		if not id is String or not lines.has(id) or unique.has(id): return false
		unique[id] = true
	return true
