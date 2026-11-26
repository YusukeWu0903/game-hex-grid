extends RefCounted
const Mission = preload("res://core/mission_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const Hex = preload("res://core/hex_rules.gd")
const Progression = preload("res://core/progression.gd")
static func open(app, config: Dictionary, map_override: Dictionary = {}) -> void:
	app.invalidate_animation()
	app.squad_config = config.duplicate(true)
	app.squad_map = map_override.duplicate(true)
	app.squad_ids = Mission.required(config)
	for id in config.playerIds:
		if app.squad_ids.size()<Mission.limit(config) and not app.squad_ids.has(id): app.squad_ids.append(id)
	render(app)
static func render(app) -> void:
	app.mode = "SQUAD"
	app.clear_sidebar()
	app.label("戰前出戰清單",22)
	app.label(app.squad_config.name,18)
	app.label(Mission.description(app.squad_config),14)
	app.label("已選 %d／上限 %d" % [app.squad_ids.size(),Mission.limit(app.squad_config)],18)
	var required = Mission.required(app.squad_config)
	for id in app.squad_config.playerIds:
		var unit = Catalog.player(id,Vector3i.ZERO)
		Progression.apply(unit,Progression.level_for(int(app.party.progression.get(id,0))))
		Catalog.equip_unit(unit,app.party.loadouts.get(id,{}))
		var box = CheckBox.new()
		box.text = "%s Lv.%d · %s%s" % [unit.name,unit.level,Catalog.data().jobs[unit.job].name," · 必出" if required.has(id) else ""]
		box.button_pressed = app.squad_ids.has(id)
		box.disabled = required.has(id)
		box.tooltip_text = "HP %d · MP %d · 移動 %d\n物防 %d · 魔防 %d" % [unit.max_hp,unit.max_mp,unit.movement,unit.defense,unit.resistance]
		box.toggled.connect(func(on):
			if on:
				if app.squad_ids.size()>=Mission.limit(app.squad_config):
					box.set_pressed_no_signal(false)
					app.notice("已達上限，請先取消另一名角色。")
					return
				app.squad_ids.append(id)
			else: app.squad_ids.erase(id)
			render(app))
		app.sidebar.add_child(box)
	app.button("確認出戰並部署",func(): app.begin_deployment(app.squad_config,app.squad_map,app.squad_ids),not Mission.selection_errors(app.squad_config,app.squad_ids).is_empty())
	app.button("返回選單",app.show_menu)
	app.board.map = app.store.map_by_id(app.squad_config.mapId) if app.squad_map.is_empty() else app.squad_map
	app.board.units = []
	app.board.show_coordinates = false
	app.board.reset_camera()
	app.board.show_spawns = true
	app.board.objective_cells = goal_cells(app.squad_config,app.board.map)
	app.board.queue_redraw()
	app.state_label.text = "出戰編成"
	app.context_label.text = app.squad_config.name
	app.detail_label.text = "勾選本場出戰角色；必出／保護角色不可取消。裝備請先在主選單整備。"
	app.notice("確認名單後，再安排出生位置。")
	app.Chapter.checkpoint(app,"SQUAD")
static func goal_cells(level: Dictionary, map: Dictionary) -> Dictionary:
	var result = {}
	if level.get("winCondition")!="REACH" or not level.get("goalCell") is Array or level.goalCell.size()!=3 or map.is_empty(): return result
	var c = level.goalCell
	var center = Vector3i(int(c[0]),int(c[1]),int(c[2]))
	for offset in Hex.cells(int(level.get("goalRadius",0))):
		var at = center+offset
		if Hex.terrain_cost(map,at)>=0: result[Hex.key(at)] = true
	return result
static func number(app, caption: String, key: String, fallback: int, lo: int, hi: int) -> void:
	app.label(caption,14)
	var input = SpinBox.new()
	input.min_value = lo
	input.max_value = hi
	input.step = 1
	input.value = int(app.editing_level.get(key,fallback))
	input.value_changed.connect(func(value):
		app.editing_level[key] = int(value)
		if key=="goalRadius": refresh_goal(app))
	app.sidebar.add_child(input)
static func editor(app) -> void:
	var level = app.editing_level
	app.label("出戰與任務規則",20)
	number(app,"最多出戰人數","deployLimit",level.playerIds.size(),1,64)
	for field in ["requiredIds","protectedIds"]:
		app.label("必出角色" if field=="requiredIds" else "保護對象（倒下即敗北，亦為必出）",14)
		for id in level.playerIds:
			var check = CheckBox.new()
			check.text = Catalog.player(id,Vector3i.ZERO).name
			check.button_pressed = level.get(field,[]).has(id)
			check.toggled.connect(func(on):
				if not app.editing_level.has(field): app.editing_level[field] = []
				if on and not app.editing_level[field].has(id): app.editing_level[field].append(id)
				elif not on: app.editing_level[field].erase(id))
			app.sidebar.add_child(check)
	app.label("勝利條件",18)
	var picker = OptionButton.new()
	var captions = ["敵方全滅","擊敗指定敵人","存活指定回合","抵達指定區域","指定寶箱與敵方全滅"]
	for caption in captions: picker.add_item(caption)
	picker.select(maxi(0,Mission.TYPES.find(level.get("winCondition","ANNIHILATION"))))
	picker.item_selected.connect(func(index):
		app.editing_level.winCondition = Mission.TYPES[index]
		if index==1: app.editing_level.targetEnemyIndex = 0
		if index==2: app.editing_level.surviveTurns = 3
		if index==3:
			app.editing_level.goalCell = [0,0,0]
			app.editing_level.goalRadius = 0
		app.render_level_editor())
	app.sidebar.add_child(picker)
	match level.get("winCondition"):
		"CHEST_AND_ALL":
			app.label("寶箱座標（x,y,z）與必得寶物 ID",14)
			for field in ["requiredChest","requiredTreasure"]:
				var input = LineEdit.new()
				input.text = str(level.get(field,""))
				input.placeholder_text = "0,0,0" if field=="requiredChest" else "border_relic"
				input.text_changed.connect(func(value): app.editing_level[field] = value)
				app.sidebar.add_child(input)
		"TARGET":
			var targets = OptionButton.new()
			targets.add_item("請指定目標")
			for i in range(level.enemyIds.size()): targets.add_item("第 %d 名 · %s" % [i+1,Catalog.data().enemies.get(level.enemyIds[i],{}).get("name","未知")])
			targets.select(clampi(int(level.get("targetEnemyIndex",-1))+1,0,level.enemyIds.size()))
			targets.item_selected.connect(func(index): app.editing_level.targetEnemyIndex = index-1)
			app.sidebar.add_child(targets)
		"SURVIVE": number(app,"完成幾次敵方回合","surviveTurns",3,1,9999)
		"REACH":
			app.label("抵達區中心（x,y,z，總和須為0）",14)
			var coordinates = LineEdit.new()
			var c = level.get("goalCell",[0,0,0])
			if not c is Array or c.size()!=3: c = [0,0,0]
			coordinates.text = "%s,%s,%s" % [c[0],c[1],c[2]]
			coordinates.text_changed.connect(func(value):
				var parts = value.split(",")
				var parsed = []
				for part in parts:
					if not part.strip_edges().is_valid_int():
						app.editing_level.goalCell = []
						refresh_goal(app)
						return
					parsed.append(int(part))
				app.editing_level.goalCell = parsed
				refresh_goal(app))
			app.sidebar.add_child(coordinates)
			number(app,"區域半徑（0＝單格）","goalRadius",0,0,6)
			app.label("保存或試玩時驗證；戰鬥以青綠色外框標示。",13)
	number(app,"回合上限（0＝不限）","turnLimit",0,0,9999)
	app.label("我方全滅必定失敗；保護對象倒下優先判敗。\n存活與超時在敵方回合結束判定。",13)

static func refresh_goal(app) -> void:
	app.board.objective_cells = goal_cells(app.editing_level,app.board.map)
	app.board.queue_redraw()
