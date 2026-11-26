extends RefCounted
const Story = preload("res://core/story_dialogue.gd")
const MissionUI = preload("res://ui/mission_ui.gd")
const Catalog = preload("res://core/catalog.gd")
const Saves = preload("res://core/battle_save.gd")
const Hex = preload("res://core/hex_rules.gd")
const Mission = preload("res://core/mission_rules.gd")

static func enabled(level: Dictionary) -> bool:
	return Catalog.data().get("chapter_rules",{}).has(level.get("levelId",""))

static func enter(app, config: Dictionary) -> void:
	if not app.party.pending_ending.is_empty():
		ending(app)
		return
	app.intro_story = Story.fresh()
	if not enabled(config):
		MissionUI.open(app,config)
		return
	app.invalidate_animation()
	app.level = config.duplicate(true)
	app.mode = "INTRO"
	app.busy = true
	app.board.map = app.store.map_by_id(config.mapId)
	app.board.units = []
	app.board.show_spawns = false
	app.board.camera_locked = true
	app.board.queue_redraw()
	app.clear_sidebar()
	app.label(config.name,22)
	app.state_label.text = "開場劇情"
	app.story_continuation = func(): MissionUI.open(app,config)
	checkpoint(app,"INTRO")
	var queue = Story.trigger(config.levelId,"INTRO",app.intro_story)
	if queue.is_empty(): app.story_finished()
	else: app.story_overlay.play(queue,app.intro_story)

static func ending(app) -> void:
	if app.party.pending_ending.is_empty(): return
	var id = str(app.party.pending_ending.level_id)
	app.invalidate_animation()
	app.mode = "ENDING"
	app.busy = true
	app.board.camera_locked = true
	app.state_label.text = "結尾劇情"
	app.clear_sidebar()
	app.label("作戰完成",24)
	var state = Story.fresh()
	app.story_continuation = func(): finish_ending(app)
	var queue = Story.trigger(id,"OUTRO",state)
	if queue.is_empty(): app.story_finished()
	else: app.story_overlay.play(queue,state)

static func finish_ending(app) -> void:
	var failure = app.party.finish_ending()
	if failure.is_empty():
		app.intro_story = Story.fresh()
		app.show_menu()
	else:
		app.busy = false
		app.clear_sidebar()
		app.label("結尾進度尚未保存",22)
		app.label(failure)
		app.button("重試保存並退出",func(): finish_ending(app))

static func result_buttons(app) -> void:
	if app.battle.result == "VICTORY":
		app.button("確認結算，觀看結尾",func(): ending(app),not app.battle.settled)
		return
	app.button("退出關卡",app.show_menu)
	app.button("重新再戰",func():
		app.intro_story = Story.fresh()
		Story.trigger(app.level.levelId,"INTRO",app.intro_story)
		MissionUI.open(app,app.level,app.battle.map.duplicate(true)))
	app.button("重看開場並重新佈陣",func(): enter(app,app.level))

static func progress_text(battle) -> String:
	var level = battle.mission
	var opened = battle.opened_chests.has(level.get("requiredChest","")) and int(battle.pending_loot.get(level.get("requiredTreasure",""),0))>0
	var count = battle.units.filter(func(u): return u.faction=="ENEMY" and u.hp>0).size()
	return "%s 中央寶箱：%s\n%s 全滅敵軍：剩餘 %d" % ["✓" if opened else "□",Catalog.item_name(level.get("requiredTreasure","")),"✓" if count==0 else "□",count]

static func checkpoint_path(app) -> String:
	return app.store.storage_path.get_base_dir().path_join("chapter_entry.json")

static func checkpoint(app, stage: String) -> void:
	var config: Dictionary = app.squad_config if stage=="SQUAD" else app.level
	if not enabled(config): return
	var data = {"version":1,"stage":stage}
	if stage in ["INTRO","SQUAD","DEPLOY"]:
		data.level = config.duplicate(true)
		data.map = app.battle.map.duplicate(true) if stage=="DEPLOY" else (app.squad_map.duplicate(true) if stage=="SQUAD" and not app.squad_map.is_empty() else app.store.map_by_id(config.mapId).duplicate(true))
		data.story = app.intro_story.duplicate(true)
		data.ids = app.squad_ids.duplicate() if stage=="SQUAD" else (app.battle.allowed_ids.duplicate() if stage=="DEPLOY" else [])
		data.deployed = []
		if stage=="DEPLOY":
			for unit in app.battle.units:
				if unit.faction=="PLAYER": data.deployed.append({"id":unit.id,"cell":[unit.cell.x,unit.cell.y,unit.cell.z]})
	# Avoid disk writes for UI refreshes that do not change preparation state.
	var path = checkpoint_path(app)
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path)==JSON.stringify(data,"\t"): return
	var failure = Saves.write_json(path,data)
	if not failure.is_empty(): app.notice("戰前進度保存失敗："+failure)

static func entry(app) -> Dictionary:
	var path = checkpoint_path(app)
	if not FileAccess.file_exists(path): return {}
	var file = FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>2*1024*1024: return {}
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version")!=1 or not data.get("stage") in ["INTRO","SQUAD","DEPLOY"]: return {}
	if not data.get("level") is Dictionary or not data.get("map") is Dictionary or not enabled(data.level): return {}
	if not Hex.validate_map(data.map).is_empty() or not Catalog.validate_chest_tables(data.map).is_empty() or not Mission.validate(data.level,data.map).is_empty(): return {}
	if not Story.valid(data.get("story"),str(data.level.get("levelId",""))) or not data.get("ids") is Array or not data.get("deployed") is Array: return {}
	if data.stage=="DEPLOY" and not Mission.selection_errors(data.level,data.ids).is_empty(): return {}
	var seen = {}
	for id in data.ids:
		if not data.level.playerIds.has(id) or seen.has(id): return {}
		seen[id] = true
	seen.clear()
	var cells = {}
	for unit in data.deployed:
		if not unit is Dictionary or not data.ids.has(unit.get("id")) or seen.has(unit.id): return {}
		if not unit.get("cell") is Array or unit.cell.size()!=3: return {}
		for n in unit.cell:
			if not Mission.integer(n,-24,24): return {}
		var cell = Vector3i(int(unit.cell[0]),int(unit.cell[1]),int(unit.cell[2]))
		var key = Hex.key(cell)
		if cells.has(key) or data.map.spawnPoints.get(key)!="PLAYER" or Hex.terrain_cost(data.map,cell)<0: return {}
		seen[unit.id] = true
		cells[key] = true
	return data

static func resume_entry(app) -> void:
	var data = entry(app)
	if data.is_empty():
		app.notice("戰前進度無效或已結束，原檔保留。")
		return
	app.intro_story = data.story.duplicate(true)
	app.level = data.level.duplicate(true)
	if data.stage=="INTRO": enter(app,data.level)
	elif data.stage=="SQUAD":
		MissionUI.open(app,data.level,data.map)
		app.squad_ids = data.ids.duplicate()
		MissionUI.render(app)
	else:
		app.begin_deployment(data.level,data.map,data.ids)
		for unit in data.deployed: app.battle.deploy(unit.id,Vector3i(int(unit.cell[0]),int(unit.cell[1]),int(unit.cell[2])))
		app.refresh_deployment()
