extends Control
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Board = preload("res://ui/hex_board.gd")
const Audio = preload("res://ui/game_audio.gd")
const RadialActions = preload("res://ui/radial_actions.gd")

var store
var battle
var board
var audio
var radial_actions
var sidebar: VBoxContainer
var state_label: Label
var status_label: Label
var detail_label: Label
var message_label: Label
var context_label: Label
var mode = "MENU"
var selection = ""
var action_mode = "MOVE"
var busy = false
var generation = 0
var active_tween: Tween
var reduced_motion = false
var level: Dictionary = {}
var editing_map: Dictionary = {}
var editing_level: Dictionary = {}
var brush = "PLAIN"
var selected_map_index = 0
var current_notice = ""
var saved_notice = ""
var file_dialog: FileDialog
var confirm_dialog: ConfirmationDialog
var confirm_action: Callable
var name_input: LineEdit
var map_picker: OptionButton
var level_picker: OptionButton
var hover_cell = Vector3i(999,999,999)
var attack_button: Button
var skill_button: Button
var move_button: Button
var wait_button: Button

func _ready() -> void:
	get_window().min_size = Vector2i(1100,720)
	store = Store.new()
	battle = Session.new()
	build_theme()
	build_shell()
	level = store.levels[0].duplicate(true)
	show_menu()
	if not store.last_error.is_empty():
		notice(store.last_error)
	set_process_unhandled_key_input(true)

func build_theme() -> void:
	var t = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei","Noto Sans CJK TC","Arial"])
	t.default_font = font
	t.default_font_size = 16
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#1c2b3b")
		style.border_color = Color("#385065")
		if state == "hover": style.bg_color = Color("#2a4257")
		if state == "pressed": style.bg_color = Color("#31596b")
		if state == "focus": style.border_color = Color("#e3c68c")
		if state == "disabled": style.bg_color = Color("#131e29")
		style.set_border_width_all(1 if state != "focus" else 2)
		style.set_corner_radius_all(5)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		t.set_stylebox(state,"Button",style)
		t.set_stylebox(state,"OptionButton",style)
	t.set_color("font_color","Label",Color("#d9e3ec"))
	t.set_color("font_color","Button",Color("#e5edf4"))
	t.set_color("font_disabled_color","Button",Color("#76889a"))
	t.set_constant("separation","VBoxContainer",9)
	t.set_constant("separation","HBoxContainer",10)
	theme = t

func build_shell() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(key,20)
	add_child(margin)
	var root = VBoxContainer.new()
	margin.add_child(root)
	var top = HBoxContainer.new()
	root.add_child(top)
	var title = Label.new()
	title.text = "HEX TACTICS"
	title.add_theme_font_size_override("font_size",25)
	title.add_theme_color_override("font_color",Color("#ecd5a7"))
	top.add_child(title)
	state_label = Label.new()
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(state_label)
	var sound = CheckButton.new()
	sound.text = "音效"
	sound.button_pressed = true
	top.add_child(sound)
	var motion = CheckButton.new()
	motion.text = "減少動態"
	top.add_child(motion)
	motion.toggled.connect(func(value): reduced_motion = value)
	audio = Audio.new()
	add_child(audio)
	sound.toggled.connect(func(value): audio.enabled = value)
	root.add_child(HSeparator.new())
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 290
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.custom_minimum_size.x = 280
	scroll.add_child(sidebar)
	var board_column = VBoxContainer.new()
	board_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(board_column)
	context_label = Label.new()
	context_label.add_theme_color_override("font_color",Color("#b6c3cf"))
	context_label.text = "六角戰棋"
	board_column.add_child(context_label)
	board = Board.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(400,400)
	board_column.add_child(board)
	radial_actions = RadialActions.new()
	board.add_child(radial_actions)
	radial_actions.board = board
	radial_actions.action_requested.connect(on_radial_action)
	board.cell_clicked.connect(on_cell_clicked)
	board.cell_hovered.connect(on_cell_hovered)
	detail_label = Label.new()
	detail_label.custom_minimum_size.y = 44
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_column.add_child(detail_label)
	root.add_child(HSeparator.new())
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 26
	root.add_child(status_label)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; 地圖 JSON"])
	file_dialog.file_selected.connect(on_file_selected)
	add_child(file_dialog)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "確認"
	confirm_dialog.ok_button_text = "確定"
	confirm_dialog.cancel_button_text = "取消"
	confirm_dialog.confirmed.connect(func(): if confirm_action.is_valid(): confirm_action.call())
	add_child(confirm_dialog)

func clear_sidebar() -> void:
	for child in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()
	attack_button = null
	skill_button = null
	move_button = null
	wait_button = null

func label(text: String, font_size: int = 16) -> Label:
	var item = Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	sidebar.add_child(item)
	return item

func button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var item = Button.new()
	item.text = text
	item.disabled = disabled
	item.custom_minimum_size.y = 42
	item.pressed.connect(func():
		audio.play("click")
		callback.call())
	sidebar.add_child(item)
	return item

func notice(text: String) -> void:
	current_notice = text
	status_label.text = text

func confirm(text: String, callback: Callable) -> void:
	confirm_action = callback
	confirm_dialog.dialog_text = text
	confirm_dialog.popup_centered(Vector2i(460,160))

func invalidate_animation() -> void:
	generation += 1
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	board.visual_positions.clear()
	if radial_actions != null:
		radial_actions.hide()
	board.effects.clear()
	busy = false

func show_menu() -> void:
	invalidate_animation()
	battle.abandon()
	mode = "MENU"
	selection = ""
	board.selected_id = ""
	board.units = []
	board.reachable = {}
	board.target_cells = {}
	board.path = []
	board.show_spawns = false
	board.show_coordinates = false
	var preview = store.map_by_id(level.get("mapId","map_custom"))
	board.map = preview if not preview.is_empty() else store.maps[0]
	state_label.text = "作戰準備"
	context_label.text = "六角戰場"
	clear_sidebar()
	label("選擇關卡",22)
	level_picker = OptionButton.new()
	for i in range(store.levels.size()):
		level_picker.add_item(store.levels[i].name)
		if store.levels[i].levelId == level.get("levelId",""):
			level_picker.select(i)
	sidebar.add_child(level_picker)
	level_picker.item_selected.connect(func(index):
		level = store.levels[index].duplicate(true)
		show_menu())
	var map = store.map_by_id(level.mapId)
	label(map.get("name","未知地圖"),18)
	label("敵軍全滅即勝利\n我方全滅即失敗")
	label("可出戰 %d 人 · 敵方 %d 人" % [level.playerIds.size(),level.enemyIds.size()])
	button("開始部署",func(): begin_deployment(level))
	sidebar.add_child(HSeparator.new())
	button("關卡編輯",func(): open_level_editor(level))
	button("地圖編輯",func(): open_map_editor(board.map))
	label("滑鼠滾輪縮放棋盤",13)
	detail_label.text = "兩種職業，六種地形。每回合先移動，再攻擊或待機。"
	notice("選擇關卡，開始部署。")
	board.queue_redraw()

func begin_deployment(config: Dictionary) -> void:
	var errors = store.validate_level(config)
	if not errors.is_empty():
		notice("\n".join(errors))
		return
	invalidate_animation()
	var prepared = battle.prepare(store.map_by_id(config.mapId),config.playerIds,config.enemyIds)
	if not prepared.is_empty():
		notice("\n".join(prepared))
		return
	level = config.duplicate(true)
	mode = "DEPLOYMENT"
	selection = ""
	action_mode = "MOVE"
	refresh_deployment()
	notice("選擇左側角色，再點我方出生格；右鍵可收回已部署角色。")

func refresh_deployment() -> void:
	clear_sidebar()
	label("戰前部署",22)
	label(level.name,18)
	for id in battle.allowed_ids:
		var data = Catalog.player(id,Vector3i.ZERO)
		var deployed = not battle.get_unit(id).is_empty()
		var caption = ("%s  %s" % [data.name,Catalog.data().jobs[data.job].name])
		if deployed: caption += " · 已部署"
		var item = button(caption,func():
			selection = id
			refresh_deployment()
			notice("將 %s 放入我方出生格。" % data.name))
		item.toggle_mode = true
		item.button_pressed = selection == id
	label("出戰時恢復全部 HP／MP",13)
	button("自動部署",func():
		battle.auto_deploy()
		selection = ""
		refresh_deployment())
	var count = battle.units.filter(func(u): return u.faction == "PLAYER").size()
	button("開始戰鬥  %d 人" % count,start_battle,count == 0)
	button("返回選單",show_menu)
	sync_board()
	state_label.text = "部署階段"
	context_label.text = "%s  ·  藍色我方／紅色敵方出生點" % battle.map.name
	detail_label.text = "點左側角色後再選位置；右鍵收回。敵方配置已顯示。"

func start_battle() -> void:
	if mode != "DEPLOYMENT":
		return
	var errors = battle.start()
	if not errors.is_empty():
		notice("\n".join(errors))
		return
	mode = "BATTLE"
	selection = ""
	battle_ui()
	notice("第 1 回合：選擇我方角色。")

func selected_unit() -> Dictionary:
	return battle.get_unit(selection)

func battle_ui() -> void:
	clear_sidebar()
	if mode == "RESULT":
		show_result_controls()
		return
	label("第 %d 回合" % battle.turn,23)
	label("我方回合" if battle.phase == "PLAYER" else "敵方行動中",18)
	var selected = selected_unit()
	if selected.is_empty():
		label("選擇我方角色")
	else:
		label(selected.name + " · " + Catalog.data().jobs[selected.job].name,20)
		label("HP %d / %d    MP %d / %d" % [selected.hp,selected.max_hp,selected.mp,selected.max_mp])
		label("已行動" if selected.acted else ("已移動 · 尚可行動" if selected.moved else "尚未移動或行動"),14)
	sidebar.add_child(HSeparator.new())
	for unit in battle.units:
		if unit.faction == "PLAYER":
			button("%s  HP %d/%d%s" % [unit.name,unit.hp,unit.max_hp," · 完成" if unit.acted else ""],
				func(): select_unit(unit.id),busy or battle.phase != "PLAYER" or unit.acted)
	button("結束我方回合",func(): confirm("讓尚未行動的角色全部待機？",end_turn),busy or battle.phase != "PLAYER")
	button("返回選單",func(): confirm("離開這場戰鬥？下次出戰會恢復全部 HP／MP。",show_menu))
	label("右鍵 / Esc：返回或取消\n滾輪：縮放",13)
	sync_board()

func sync_radial_actions() -> void:
	move_button = radial_actions.buttons.MOVE
	attack_button = radial_actions.buttons.ATTACK
	skill_button = radial_actions.buttons.SKILL
	wait_button = radial_actions.buttons.WAIT
	var selected = selected_unit()
	if mode == "BATTLE" and action_mode == "COMMAND" and not busy and battle.can_control(selection):
		radial_actions.configure(selected)
	else:
		radial_actions.hide()

func on_radial_action(action: String) -> void:
	if busy or mode != "BATTLE" or not battle.can_control(selection):
		return
	audio.play("click")
	match action:
		"WAIT": wait_selected()
		"CANCEL": cancel_selection()
		_: choose_action(action)

func select_unit(id: String) -> void:
	if busy or not battle.can_control(id):
		return
	selection = id
	action_mode = "COMMAND"
	battle_ui()
	notice("在角色周圍選擇指令；滑鼠停留可查看名稱與消耗。")

func choose_action(value: String) -> void:
	if busy or not battle.can_control(selection) or value not in ["MOVE","ATTACK","SKILL"]:
		return
	var unit = selected_unit()
	if value == "MOVE" and unit.moved:
		return
	if value == "SKILL" and unit.mp < Catalog.action(unit,true).mp_cost:
		notice("MP 不足，無法施放技能。")
		return
	action_mode = value
	battle_ui()
	notice("點選可達格移動；右鍵 / Esc 返回行動選單。" if value == "MOVE" else "點選紅色範圍內的敵人；右鍵 / Esc 返回行動選單。")

func cancel_selection() -> void:
	if busy:
		return
	if action_mode in ["MOVE","ATTACK","SKILL"] and not selection.is_empty():
		action_mode = "COMMAND"
		notice("已返回角色行動選單；尚未消耗的行動保留。")
	else:
		selection = ""
		action_mode = "MOVE"
		notice("已取消選取；已完成的移動會保留。")
	battle_ui()

func wait_selected() -> void:
	if busy:
		return
	if battle.wait_unit(selection):
		selection = ""
		after_action()

func end_turn() -> void:
	if busy or mode != "BATTLE":
		return
	battle.end_player_turn()
	selection = ""
	after_action()

func after_action() -> void:
	if battle.phase == "RESULT":
		mode = "RESULT"
		busy = false
		selection = ""
		if battle.result == "VICTORY":
			audio.play("victory")
		battle_ui()
		return
	battle_ui()
	if battle.phase == "ENEMY":
		run_enemy_turn()

func sync_board() -> void:
	if mode in ["BATTLE","DEPLOYMENT","RESULT"]:
		board.map = battle.map
		board.units = battle.units
	board.selected_id = selection
	board.show_spawns = mode in ["DEPLOYMENT","MAP_EDITOR"]
	board.show_coordinates = mode == "MAP_EDITOR"
	board.reachable = {}
	board.target_cells = {}
	board.path = []
	if mode == "BATTLE":
		state_label.text = "第 %d 回合  ·  %s" % [battle.turn,"我方回合" if battle.phase == "PLAYER" else "敵方回合"]
		context_label.text = "%s  ·  目標：擊敗全部敵人" % battle.map.name
		detail_label.text = "選擇角色，在棋子周圍下達指令；右鍵 / Esc 返回或取消。"
		var unit = selected_unit()
		if not busy and not unit.is_empty() and battle.can_control(selection):
			if action_mode == "MOVE":
				board.reachable = battle.reachable(selection).get("costs",{})
				board.reachable.erase(Hex.key(unit.cell))
			elif action_mode in ["ATTACK","SKILL"]:
				var action = Catalog.action(unit,action_mode == "SKILL")
				if unit.mp >= action.mp_cost:
					for cell in Hex.cells(int(battle.map.radius)):
						var distance = Hex.distance(unit.cell,cell)
						if distance >= action.range_min and distance <= action.range_max:
							board.target_cells[Hex.key(cell)] = true
	sync_radial_actions()
	board.queue_redraw()

func on_cell_hovered(cell: Vector3i) -> void:
	hover_cell = cell
	if not Hex.inside(cell,int(board.map.get("radius",0))):
		detail_label.text = ""
		return
	var terrain = board.map.terrains.get(Hex.key(cell),"PLAIN")
	var terrain_names = {"PLAIN":"平地","FOREST":"森林","SWAMP":"沼澤","HILLS":"丘陵","MOUNTAIN":"山脈","WATER":"水域"}
	var cost = Hex.terrain_cost(board.map,cell)
	var detail = "%s · %s" % [terrain_names.get(terrain,terrain),"不可通行" if cost < 0 else "移動成本 %d" % cost]
	var target = Rules.unit_at(board.units,cell)
	if not target.is_empty():
		detail += "  |  %s  HP %d/%d  MP %d/%d" % [target.name,target.hp,target.max_hp,target.mp,target.max_mp]
	if mode == "BATTLE" and not busy and battle.can_control(selection):
		var unit = selected_unit()
		if action_mode == "MOVE":
			board.path = Hex.route(battle.reachable(selection),cell)
		elif action_mode in ["ATTACK","SKILL"] and not target.is_empty():
			var action = Catalog.action(unit,action_mode == "SKILL")
			if Rules.can_attack(unit,target,action):
				detail += "  |  預計 %d 傷害 → HP %d" % [action.damage,maxi(0,target.hp-action.damage)]
	detail_label.text = detail
	board.queue_redraw()

func on_cell_clicked(cell: Vector3i, mouse_button: int) -> void:
	if mode == "MAP_EDITOR":
		if mouse_button == MOUSE_BUTTON_LEFT:
			paint_cell(cell)
		return
	if mode == "DEPLOYMENT":
		if mouse_button == MOUSE_BUTTON_RIGHT:
			battle.recall(cell)
			refresh_deployment()
		elif mouse_button == MOUSE_BUTTON_LEFT:
			if selection.is_empty():
				notice("先選擇左側要部署的角色。")
			elif battle.deploy(selection,cell):
				selection = ""
				refresh_deployment()
			else:
				notice("請選擇可通行的我方出生格。")
		return
	if mode != "BATTLE" or busy or battle.phase != "PLAYER":
		return
	if mouse_button == MOUSE_BUTTON_RIGHT:
		cancel_selection()
		return
	if mouse_button != MOUSE_BUTTON_LEFT:
		return
	var clicked = Rules.unit_at(battle.units,cell)
	if not clicked.is_empty() and clicked.faction == "PLAYER" and action_mode not in ["ATTACK","SKILL"]:
		select_unit(clicked.id)
		return
	if not battle.can_control(selection):
		return
	if action_mode == "MOVE":
		var unit = selected_unit()
		var origin: Vector3i = unit.cell
		var path = battle.move_unit(selection,cell)
		if path.is_empty():
			notice("無法移動到這裡；請選擇範圍內的空格。")
			return
		busy = true
		var token = generation
		var id = selection
		battle_ui()
		await animate_movement(id,origin,path,token)
		if token != generation:
			return
		busy = false
		action_mode = "COMMAND"
		battle_ui()
		notice("移動完成。從角色周圍選擇攻擊、技能或待機。")
	elif action_mode in ["ATTACK","SKILL"]:
		var result = battle.attack(selection,str(clicked.get("id","")),action_mode == "SKILL")
		if not result.ok:
			notice("目標無效、超出射程或 MP 不足；行動未消耗。")
			return
		board.add_damage(cell,int(result.damage))
		audio.play("hit")
		selection = ""
		action_mode = "MOVE"
		after_action()

func animate_movement(id: String, origin: Vector3i, path: Array, token: int) -> void:
	var previous = board.position_of(origin)
	board.visual_positions[id] = previous
	for cell in path:
		if token != generation:
			return
		var next = board.position_of(cell)
		if reduced_motion:
			board.visual_positions[id] = next
		else:
			active_tween = create_tween()
			active_tween.tween_method(func(value):
				if token == generation:
					board.visual_positions[id] = value
					board.queue_redraw(),previous,next,0.12)
			audio.play("move")
			await get_tree().create_timer(0.13).timeout
		previous = next
	if token == generation:
		board.visual_positions.erase(id)
		board.queue_redraw()

func run_enemy_turn() -> void:
	if busy or mode != "BATTLE":
		return
	busy = true
	var token = generation
	battle_ui()
	notice("敵方正在行動。")
	var ids = battle.units.filter(func(u): return u.faction == "ENEMY").map(func(u): return u.id)
	for id in ids:
		if token != generation or battle.phase != "ENEMY":
			break
		var unit = battle.get_unit(id)
		if unit.is_empty():
			continue
		var plan = battle.enemy_plan(id)
		await animate_movement(id,unit.cell,plan.path,token)
		if token != generation:
			return
		var target = battle.get_unit(str(plan.target_id))
		var target_cell: Vector3i = target.get("cell",Vector3i.ZERO)
		var result = battle.commit_enemy(id,plan)
		if result.get("ok",false):
			board.add_damage(target_cell,int(result.damage))
			audio.play("hit")
		battle_ui()
		if not reduced_motion:
			await get_tree().create_timer(0.2).timeout
	if token != generation:
		return
	busy = false
	if battle.phase == "RESULT":
		after_action()
	else:
		battle.next_round()
		selection = ""
		action_mode = "MOVE"
		battle_ui()
		notice("第 %d 回合：我方行動。" % battle.turn)

func show_result_controls() -> void:
	var victory = battle.result == "VICTORY"
	label("戰鬥勝利" if victory else "戰鬥失敗",28)
	label("VICTORY" if victory else "DEFEAT",18)
	label("完成於第 %d 回合" % battle.turn)
	label("敵軍已全數擊敗。" if victory else "我方已全軍覆沒。")
	label("下次出戰將恢復全部 HP／MP。",14)
	button("重新部署",func(): begin_deployment(level))
	button("返回選單",show_menu)
	sync_board()
	state_label.text = "戰鬥結束"
	context_label.text = level.name
	detail_label.text = "本場戰鬥已結束；重新部署可開始新的一場。"
	notice("戰鬥結束。可重新部署或返回選單。")

func open_level_editor(config: Dictionary) -> void:
	invalidate_animation()
	mode = "LEVEL_EDITOR"
	editing_level = config.duplicate(true)
	render_level_editor()

func render_level_editor() -> void:
	clear_sidebar()
	label("關卡編輯",22)
	name_input = LineEdit.new()
	name_input.text = editing_level.name
	name_input.placeholder_text = "關卡名稱"
	sidebar.add_child(name_input)
	name_input.text_changed.connect(func(value): editing_level.name = value)
	map_picker = OptionButton.new()
	for i in range(store.maps.size()):
		map_picker.add_item(store.maps[i].name)
		if store.maps[i].mapId == editing_level.mapId:
			map_picker.select(i)
	sidebar.add_child(map_picker)
	map_picker.item_selected.connect(func(index):
		editing_level.mapId = store.maps[index].mapId
		render_level_editor())
	label("我方出戰名單",18)
	for row in Catalog.roster():
		var item = CheckBox.new()
		item.text = row.name+" · "+Catalog.data().jobs[row.job].name
		item.button_pressed = editing_level.playerIds.has(row.id)
		item.toggled.connect(func(value):
			if value and not editing_level.playerIds.has(row.id):
				editing_level.playerIds.append(row.id)
			elif not value:
				editing_level.playerIds.erase(row.id))
		sidebar.add_child(item)
	label("敵方陣容",18)
	for i in range(editing_level.enemyIds.size()):
		var row_box = HBoxContainer.new()
		sidebar.add_child(row_box)
		var picker = OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var enemy_ids = Catalog.data().enemies.keys()
		for j in range(enemy_ids.size()):
			picker.add_item(Catalog.data().enemies[enemy_ids[j]].name)
			if enemy_ids[j] == editing_level.enemyIds[i]:
				picker.select(j)
		picker.item_selected.connect(func(index): editing_level.enemyIds[i] = enemy_ids[index])
		row_box.add_child(picker)
		var remove = Button.new()
		remove.text = "−"
		remove.tooltip_text = "移除此敵人"
		remove.pressed.connect(func():
			editing_level.enemyIds.remove_at(i)
			render_level_editor())
		row_box.add_child(remove)
	button("加入敵人",func():
		editing_level.enemyIds.append("enemy_swordsman_base")
		render_level_editor())
	label("勝利：敵方全滅\n失敗：我方全滅",14)
	button("儲存關卡",save_level)
	button("另存新關卡",func():
		editing_level.levelId = "level_%d" % Time.get_ticks_usec()
		save_level())
	button("試玩部署",func():
		var errors = store.validate_level(editing_level)
		if errors.is_empty(): begin_deployment(editing_level)
		else: notice("\n".join(errors)))
	button("編輯這張地圖",func(): open_map_editor(store.map_by_id(editing_level.mapId)))
	button("返回選單",show_menu)
	board.map = store.map_by_id(editing_level.mapId)
	board.units = []
	board.show_spawns = true
	board.show_coordinates = false
	board.reachable = {}
	board.target_cells = {}
	board.path = []
	board.selected_id = ""
	board.queue_redraw()
	state_label.text = "關卡編輯"
	context_label.text = "配置出戰名單與敵軍"
	detail_label.text = "所選角色將成為部署階段唯一可用的名單。"
	notice("編輯後儲存，或直接試玩部署。")

func save_level() -> void:
	var errors = store.save_level(editing_level)
	if errors.is_empty():
		level = editing_level.duplicate(true)
		notice("關卡已儲存。")
	else:
		notice("\n".join(errors))

func open_map_editor(map: Dictionary) -> void:
	invalidate_animation()
	mode = "MAP_EDITOR"
	editing_map = map.duplicate(true)
	selection = ""
	brush = "PLAIN"
	render_map_editor()

func render_map_editor() -> void:
	clear_sidebar()
	label("地圖編輯",22)
	var picker = OptionButton.new()
	for i in range(store.maps.size()):
		picker.add_item(store.maps[i].name)
		if store.maps[i].mapId == editing_map.mapId:
			picker.select(i)
	sidebar.add_child(picker)
	picker.item_selected.connect(func(index):
		confirm("載入另一張地圖？尚未儲存的編輯將捨棄。",func(): open_map_editor(store.maps[index])))
	name_input = LineEdit.new()
	name_input.text = editing_map.name
	sidebar.add_child(name_input)
	name_input.text_changed.connect(func(value): editing_map.name = value)
	label("地形筆刷",18)
	var names = {"PLAIN":"平地 · 1","FOREST":"森林 · 2","SWAMP":"沼澤 · 2","HILLS":"丘陵 · 2","MOUNTAIN":"山脈 · 禁行","WATER":"水域 · 禁行","PLAYER":"我方出生點","ENEMY":"敵方出生點","CLEAR":"清除出生點"}
	var brushes = GridContainer.new()
	brushes.columns = 2
	sidebar.add_child(brushes)
	for key in names:
		var item = Button.new()
		item.text = names[key]
		item.toggle_mode = true
		item.button_pressed = brush == key
		item.pressed.connect(func():
			brush = key
			render_map_editor())
		brushes.add_child(item)
	button("儲存地圖",save_map)
	button("匯出 JSON",func():
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.current_file = str(editing_map.mapId)+".json"
		file_dialog.popup_centered_ratio(0.7))
	button("匯入 JSON",func():
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.popup_centered_ratio(0.7))
	button("新增空白地圖",func():
		confirm("建立新地圖？尚未儲存的編輯將捨棄。",func():
			open_map_editor({"mapId":"map_%d" % Time.get_ticks_usec(),"name":"新地圖","radius":4,"terrains":{},"spawnPoints":{}})))
	button("返回關卡編輯",func():
		confirm("離開地圖編輯？請先儲存要保留的變更。",func(): open_level_editor(editing_level if not editing_level.is_empty() else level)))
	button("返回選單",func():
		confirm("返回選單？未儲存的編輯將捨棄。",show_menu))
	board.map = editing_map
	board.units = []
	board.selected_id = ""
	board.reachable = {}
	board.target_cells = {}
	board.path = []
	board.show_spawns = true
	board.show_coordinates = true
	board.queue_redraw()
	state_label.text = "地圖編輯"
	context_label.text = "%s  ·  半徑 %d" % [editing_map.name,editing_map.radius]
	detail_label.text = "點擊格子繪製。出生點只能放在可通行地形。"

func paint_cell(cell: Vector3i) -> void:
	var key = Hex.key(cell)
	if brush in ["PLAYER","ENEMY"]:
		if Hex.terrain_cost(editing_map,cell) < 0:
			notice("出生點不能放在山脈或水域。")
			return
		editing_map.spawnPoints[key] = brush
	elif brush == "CLEAR":
		editing_map.spawnPoints.erase(key)
	else:
		if brush == "PLAIN":
			editing_map.terrains.erase(key)
		else:
			editing_map.terrains[key] = brush
		if brush in ["MOUNTAIN","WATER"]:
			editing_map.spawnPoints.erase(key)
	board.queue_redraw()

func save_map() -> void:
	var errors = store.save_map(editing_map)
	if errors.is_empty():
		notice("地圖已儲存。")
	else:
		notice("\n".join(errors))

func on_file_selected(path: String) -> void:
	if mode != "MAP_EDITOR":
		return
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		var result = store.import_map(path)
		if result.ok:
			open_map_editor(result.map)
			notice("已載入地圖；按「儲存地圖」後才會寫入資料庫。")
		else:
			notice(result.message)
	else:
		var error = store.export_map(path,editing_map)
		notice("地圖已匯出。" if error.is_empty() else error)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or mode != "BATTLE" or busy:
		return
	if confirm_dialog.visible or file_dialog.visible:
		return
	var shortcuts = {KEY_M:"MOVE",KEY_A:"ATTACK",KEY_S:"SKILL",KEY_W:"WAIT",KEY_ESCAPE:"CANCEL"}
	if shortcuts.has(event.keycode):
		on_radial_action(shortcuts[event.keycode])
		get_viewport().set_input_as_handled()
