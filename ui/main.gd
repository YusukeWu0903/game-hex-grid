extends Control
const MapGenerator = preload("res://core/map_generator.gd")
const MapEditor = preload("res://core/map_editor.gd")
var map_editor = MapEditor.new()
var brush_radius = 0
var fill_brush = false
var generator_seed = 20261125
var generator_ratio = 0.25
var editor_radius = 4
var generator_preview: Dictionary = {}
var stroke_active = false
var performance_label: Label
var performance_clock = 0.0
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
const Catalog = preload("res://core/catalog.gd")
const Party = preload("res://core/party_store.gd")
const Mission = preload("res://core/mission_rules.gd")
const MissionUI = preload("res://ui/mission_ui.gd")
var squad_config: Dictionary = {}
var squad_map: Dictionary = {}
var squad_ids: Array = []
const RPGUI = preload("res://ui/rpg_ui.gd")
var party
var selected_item = ""
var party_selected = "player_swordsman_01"
const Session = preload("res://core/battle_session.gd")
const Store = preload("res://core/data_store.gd")
const Board = preload("res://ui/hex_board.gd")
const Audio = preload("res://ui/game_audio.gd")
const Preferences = preload("res://core/preferences.gd")
const Saves = preload("res://core/battle_save.gd")
const Cinematic = preload("res://ui/combat_cinematic.gd")
const RadialActions = preload("res://ui/radial_actions.gd")

var preferences
var settings_timer: Timer
var store
var battle
var board
var audio
var cinematic
var combat_cinematics = true
var radial_actions
var sidebar: VBoxContainer
var state_label: Label
var status_label: Label
var detail_label: Label
var message_label: Label
var context_label: Label
var mode = "MENU"
var inspected_id = ""
var show_all_threats = false
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
var help_dialog: AcceptDialog
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
	Engine.max_fps = 60
	get_window().min_size = Vector2i(1100,720)
	store = Store.new()
	party = Party.new(store.storage_path.get_base_dir().path_join("party.json"))
	preferences = Preferences.new(store.storage_path.get_base_dir().path_join("settings.json"))
	reduced_motion = preferences.values.reduced_motion
	combat_cinematics = preferences.values.cinematics
	battle = Session.new()
	build_theme()
	build_shell()
	level = store.levels[0].duplicate(true)
	show_menu()
	if not store.last_error.is_empty():
		notice(store.last_error)
	if not preferences.error.is_empty():
		notice(preferences.error)
	set_process_unhandled_key_input(true)

func build_theme() -> void:
	var t = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei","Noto Sans CJK TC","Arial"])
	t.default_font = font
	t.default_font_size = 16
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#303c37")
		style.border_color = Color("#7e8063")
		if state == "hover": style.bg_color = Color("#465448")
		if state == "pressed": style.bg_color = Color("#59644d")
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
	var dialog_panel = StyleBoxFlat.new()
	dialog_panel.bg_color = Color("#222f2d")
	dialog_panel.border_color = Color("#7e8063")
	dialog_panel.set_border_width_all(1)
	dialog_panel.content_margin_left = 18
	dialog_panel.content_margin_right = 18
	dialog_panel.content_margin_top = 16
	dialog_panel.content_margin_bottom = 16
	t.set_stylebox("panel","AcceptDialog",dialog_panel)
	var window_border = dialog_panel.duplicate()
	window_border.expand_margin_top = 28
	t.set_stylebox("embedded_border","Window",window_border)
	t.set_color("title_color","Window",Color("#e4d4b7"))
	t.set_font("normal_font","RichTextLabel",font)
	t.set_font("bold_font","RichTextLabel",font)
	t.set_font_size("normal_font_size","RichTextLabel",18)
	t.set_font_size("bold_font_size","RichTextLabel",19)
	t.set_color("default_color","RichTextLabel",Color("#d9e3ec"))
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
	sound.button_pressed = preferences.values.sound
	top.add_child(sound)
	var motion = CheckButton.new()
	motion.text = "減少動態"
	motion.button_pressed = reduced_motion
	top.add_child(motion)
	motion.toggled.connect(func(value):
		reduced_motion = value
		preferences.values.reduced_motion = value
		persist_preferences())
	audio = Audio.new()
	add_child(audio)
	audio.enabled = preferences.values.sound
	audio.set_volume(preferences.values.volume)
	sound.toggled.connect(func(value):
		audio.enabled = value
		if not value: audio.player.stop()
		preferences.values.sound = value
		persist_preferences())
	var volume = HSlider.new()
	volume.custom_minimum_size.x = 85
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 5
	volume.value = preferences.values.volume
	volume.tooltip_text = "音效音量 %d%%" % preferences.values.volume
	volume.accessibility_name = "音效音量"
	top.add_child(volume)
	settings_timer = Timer.new()
	settings_timer.one_shot = true
	settings_timer.wait_time = 0.3
	settings_timer.timeout.connect(persist_preferences)
	add_child(settings_timer)
	volume.value_changed.connect(func(value):
		preferences.values.volume = int(value)
		audio.set_volume(value)
		volume.tooltip_text = "音效音量 %d%%" % int(value)
		settings_timer.start())
	var cinema_toggle = CheckButton.new()
	cinema_toggle.text = "戰鬥演出"
	cinema_toggle.button_pressed = combat_cinematics
	cinema_toggle.toggled.connect(func(value):
		combat_cinematics = value
		preferences.values.cinematics = value
		persist_preferences())
	top.add_child(cinema_toggle)
	var help_button = Button.new()
	help_button.text = "?"
	help_button.tooltip_text = "操作與地形說明 [F1]"
	help_button.accessibility_name = "操作與地形說明"
	help_button.pressed.connect(show_help)
	top.add_child(help_button)
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
	performance_label = Label.new()
	performance_label.position = Vector2(12,12)
	performance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	performance_label.add_theme_color_override("font_color",Color.WHITE)
	performance_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	performance_label.add_theme_constant_override("shadow_offset_x",2)
	performance_label.add_theme_constant_override("shadow_offset_y",2)
	performance_label.visible = false
	board.add_child(performance_label)
	radial_actions = RadialActions.new()
	board.add_child(radial_actions)
	radial_actions.board = board
	radial_actions.action_requested.connect(on_radial_action)
	board.cell_clicked.connect(on_cell_clicked)
	board.cell_hovered.connect(on_cell_hovered)
	board.stroke_finished.connect(func(): stroke_active = false)
	board.cell_dragged.connect(func(cell):
		if mode == "MAP_EDITOR" and not fill_brush: paint_cell(cell))
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
	cinematic = Cinematic.new()
	add_child(cinematic)
	cinematic.impact.connect(func(): audio.play("hit"))
	help_dialog = AcceptDialog.new()
	help_dialog.title = "操作與戰鬥規則"
	help_dialog.ok_button_text = "返回遊戲"
	add_child(help_dialog)
	var help = RichTextLabel.new()
	help.custom_minimum_size = Vector2(620,440)
	help.bbcode_enabled = true
	help.text = """[b]每回合的行動[/b]
每名角色可先移動一次，再攻擊、使用技能或待機一次。攻擊後行動結束。
取消選取不消耗行動；已完成的移動不會撤回。每場新戰鬥恢復全部 HP／MP。

[b]角色周圍五鍵[/b]
上：移動 [M]　右上：攻擊 [A]　右下：技能 [S]
左下：待機 [W]　左上：取消 [Esc]
選指令後點目的地或敵人。右鍵 / Esc 返回行動選單，再按一次取消選取。
滑鼠停留在圖示上可查看效果、消耗及停用原因。

[b]觀察戰場[/b]
未選攻擊目標時，點敵人或已行動的我方可查看資料。
[T] 顯示全部敵方威脅；紫紅色格與小圓點表示移動後可能普攻到的位置。
範圍依目前占位計算，不保證 AI 選擇該位置；單位移動後會重新計算。
滾輪縮放；中鍵拖曳平移；[F] 定位所選角色；[Home] 重置視角。
右下小地圖可定位；邊緣捲動；[F3] 開關效能監視（60 FPS 上限）。

[b]地形[/b]
[color=#acbccf]■ 平地[/color]：移動成本 1
[color=#7eb39b]■ 森林[/color]、[color=#b4b984]■ 沼澤[/color]、[color=#c5a882]■ 丘陵[/color]：移動成本 2
[color=#a6adb8]■ 山脈[/color]、[color=#6ea8ca]■ 水域[/color]：不可通行
單位不能穿越其他單位。地形目前不加防禦，也不遮擋箭矢。

[b]攻擊與技能[/b]
合法攻擊必中、固定傷害；沒有反擊、暴擊或高低差加成。
劍士：普攻射程 1；重擊消耗 10 MP、傷害 7。
弓箭手：普攻射程 2–3；強力射擊消耗 15 MP、傷害 6、射程 2–4。
我方普攻傷害 4，敵方普攻傷害 3。敵方目前僅使用普通攻擊。

[b]演出與保存[/b]
戰鬥演出中可按 Space / Esc 跳過；跳過仍正常結算一次。
頂端可調整音效、音量、減少動態及演出開關，設定會保存。
可在我方回合、沒有動畫時儲存戰鬥 [Ctrl+S]，從主選單「繼續戰鬥」讀取。
讀檔保留資源與行動狀態；上一份存檔可從主選單「讀取上一份備份」恢復。
敵方全滅即勝利，我方全滅即失敗。
"""
	help_dialog.add_child(help)

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
	if cinematic != null:
		cinematic.abort()
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	board.visual_positions.clear()
	if radial_actions != null:
		radial_actions.hide()
	board.effects.clear()
	board.opened_chests = {}
	board.area_cells = {}
	board.objective_cells = {}
	board.objective_roles = {}
	board.threat_cells.clear()
	board.inspected_id = ""
	inspected_id = ""
	board.camera_locked = false
	board.dragging = false
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
	board.area_cells = {}
	board.objective_cells = {}
	board.objective_roles = {}
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
	label(Mission.description(level))
	label("可出戰 %d 人 · 敵方 %d 人" % [level.playerIds.size(),level.enemyIds.size()])
	button("開始部署",func(): MissionUI.open(self,level))
	button("繼續戰鬥",load_battle,not FileAccess.file_exists(battle_save_path()))
	if FileAccess.file_exists(battle_save_path()+".bak"):
		button("讀取上一份備份",func(): load_battle(true))
	sidebar.add_child(HSeparator.new())
	button("隊伍／裝備／道具",func(): RPGUI.show_party(self))
	button("關卡編輯",func(): open_level_editor(level))
	button("地圖編輯",func(): open_map_editor(board.map))
	label("滑鼠滾輪縮放棋盤",13)
	detail_label.text = "四種職業，六種地形。每回合先移動，再攻擊或待機。"
	notice("選擇關卡，開始部署。")
	board.queue_redraw()

func begin_deployment(config: Dictionary, map_override: Dictionary = {}, selected_ids: Array = []) -> void:
	var errors: Array[String] = []
	if map_override.is_empty():
		errors = store.validate_level(config)
	if not errors.is_empty():
		notice("\n".join(errors))
		return
	if selected_ids.is_empty() and config.playerIds.size()>Mission.limit(config):
		MissionUI.open(self,config,map_override)
		return
	var roster = config.playerIds if selected_ids.is_empty() else selected_ids
	invalidate_animation()
	var prepared = battle.prepare(store.map_by_id(config.mapId) if map_override.is_empty() else map_override,roster,config.enemyIds,config)
	if not prepared.is_empty():
		notice("\n".join(prepared))
		return
	battle.inventory = party.inventory.duplicate(true)
	battle.loadouts = party.loadouts.duplicate(true)
	battle.progression = party.progression.duplicate(true)
	level = config.duplicate(true)
	board.reset_camera()
	mode = "DEPLOYMENT"
	selection = ""
	action_mode = "MOVE"
	refresh_deployment()
	if int(battle.map.radius)>4:
		for key in battle.map.spawnPoints:
			if battle.map.spawnPoints[key]=="PLAYER":
				board.focus_cell(Hex.cell(key))
				break
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
	if battle.phase=="RESULT":
		after_action()
		return
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
	label(Mission.description(level),14)
	RPGUI.add_rewind(self)
	var selected = battle.get_unit(inspected_id) if not inspected_id.is_empty() else selected_unit()
	if selected.is_empty():
		label("選擇我方角色；點敵人查看資料")
	else:
		label(selected.name + " · " + Catalog.data().jobs[selected.job].name,20)
		label("HP %d / %d    MP %d / %d" % [selected.hp,selected.max_hp,selected.mp,selected.max_mp])
		label("已行動" if selected.acted else ("已移動 · 尚可行動" if selected.moved else "尚未移動或行動"),14)
		label("我方" if selected.faction == "PLAYER" else "敵方 · 下次行動威脅以紫紅色標示",14)
		var normal = Catalog.action(selected)
		label("移動 %d  ·  普攻威力 %d
射程 %d–%d 格" % [selected.movement,normal.damage,normal.range_min,normal.range_max],14)
		if selected.faction == "PLAYER":
			var skill = Catalog.action(selected,true)
			if skill.get("effect","")=="guard": label("盾牆：物防／魔防 +%d，維持到下次我方回合" % skill.guard,14)
			label("%s · %d MP
威力 %d · 射程 %d–%d 格" % [skill.name,skill.mp_cost,skill.damage,skill.range_min,skill.range_max],14)
		else:
			label("敵方依法術資源與職業規劃行動。",13)

	RPGUI.battle_controls(self)
	sidebar.add_child(HSeparator.new())
	for unit in battle.units:
		if unit.faction == "PLAYER":
			button("%s  HP %d/%d%s" % [unit.name,unit.hp,unit.max_hp," · 完成" if unit.acted else (" · 已移動" if unit.moved else "")],
				func(): select_unit(unit.id),busy or battle.phase != "PLAYER" or unit.acted)
	var threat_toggle = CheckButton.new()
	threat_toggle.text = "全部敵方威脅 [T]"
	threat_toggle.button_pressed = show_all_threats
	threat_toggle.tooltip_text = "依目前占位預估敵人下次移動後的普攻範圍；不是 AI 必定攻擊的位置。"
	threat_toggle.toggled.connect(func(value):
		show_all_threats = value
		sync_board())
	sidebar.add_child(threat_toggle)
	button("定位角色 [F]",focus_inspected,selected.is_empty() or busy)
	button("重置視角 [Home]",func(): board.reset_camera(),busy)
	button("儲存戰鬥 [Ctrl+S]",request_save_battle,busy or battle.phase != "PLAYER")
	button("結束我方回合",func(): confirm("讓尚未行動的角色全部待機？",end_turn),busy or battle.phase != "PLAYER")
	button("返回選單",func(): confirm("離開這場戰鬥？下次出戰會恢復全部 HP／MP。",show_menu))
	label("右鍵 / Esc：返回或取消\n滾輪：縮放 · 中鍵拖曳：平移",13)
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
		"ITEM", "CHEST": choose_action(action)
		_: choose_action(action)

func select_unit(id: String) -> void:
	if busy or not battle.can_control(id):
		return
	selection = id
	if int(battle.map.radius)>4: board.focus_cell(battle.get_unit(id).cell)
	inspected_id = ""
	action_mode = "COMMAND"
	battle_ui()
	notice("在角色周圍選擇指令；滑鼠停留可查看名稱與消耗。")

func choose_action(value: String) -> void:
	if busy or not battle.can_control(selection) or value not in ["MOVE","ATTACK","SKILL","ITEM","CHEST"]:
		return
	var unit = selected_unit()
	if value=="ATTACK" and unit.mp<int(Catalog.action(unit).mp_cost):
		notice("MP 不足，無法施放魔彈。")
		return
	if value == "MOVE" and unit.moved:
		return
	if value == "SKILL" and unit.mp < Catalog.action(unit,true).mp_cost:
		notice("MP 不足，無法施放技能。")
		return
	if value=="SKILL" and Catalog.action(unit,true).get("effect","")=="guard":
		if battle.guard_unit(selection):
			selection = ""
			after_action()
		return
	action_mode = value
	selected_item = ""
	battle_ui()
	notice({"MOVE":"點選可達格移動。","ITEM":"選擇左側道具，再點自己或相鄰友軍。","CHEST":"點選自己或相鄰格的未開啟寶箱。"}.get(value,"點選射程內的敵人。")+"右鍵 / Esc 返回行動選單。")

func cancel_selection() -> void:
	if busy:
		return
	inspected_id = ""
	if action_mode in ["MOVE","ATTACK","SKILL","ITEM","CHEST"] and not selection.is_empty():
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
			var settlement_error = party.claim(battle)
			if not settlement_error.is_empty(): notice(settlement_error)
		battle_ui()
		return
	battle_ui()
	if battle.phase == "ENEMY":
		run_enemy_turn()

func sync_board() -> void:
	board.area_cells = {}
	board.objective_roles = {}
	if mode in ["BATTLE","DEPLOYMENT","RESULT"]:
		for id in level.get("protectedIds",[]): board.objective_roles[id] = "[保護] "
		if level.get("winCondition")=="TARGET": board.objective_roles["enemy_%d" % int(level.get("targetEnemyIndex",0))] = "[目標] "
	board.objective_cells = MissionUI.goal_cells(level,battle.map) if mode in ["BATTLE","DEPLOYMENT","RESULT"] else {}
	if mode in ["BATTLE","DEPLOYMENT","RESULT"]:
		board.map = battle.map
		board.invalid_cells = {}
		board.units = battle.units
		board.opened_chests = battle.opened_chests
	board.selected_id = selection
	board.inspected_id = inspected_id
	board.camera_locked = busy
	board.threat_cells = {}
	if mode == "BATTLE" and not busy:
		for enemy in battle.units:
			if enemy.faction == "ENEMY" and (show_all_threats or enemy.id == inspected_id):
				board.threat_cells.merge(Rules.threat_cells(battle.map,enemy,battle.units,Catalog.action(enemy)))
	board.show_spawns = mode in ["DEPLOYMENT","MAP_EDITOR"]
	board.show_coordinates = mode == "MAP_EDITOR"
	board.reachable = {}
	board.target_cells = {}
	board.path = []
	if mode == "BATTLE":
		state_label.text = "第 %d 回合  ·  %s" % [battle.turn,"我方回合" if battle.phase == "PLAYER" else "敵方回合"]
		context_label.text = "%s  ·  %s" % [battle.map.name,Mission.victory_text(level)]
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
	RPGUI.sync_targets(self)
	sync_radial_actions()
	board.queue_redraw()

func on_cell_hovered(cell: Vector3i) -> void:
	board.area_cells = {}
	hover_cell = cell
	if not Hex.inside(cell,int(board.map.get("radius",0))):
		detail_label.text = ""
		board.path = []
		board.queue_redraw()
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
				var damage = Rules.damage_for(unit,target,action)
				detail += "  |  預計 %d 傷害 → HP %d%s" % [damage,maxi(0,target.hp-damage)," · 可擊倒" if target.hp<=damage else ""]
				if int(action.get("radius",0))>0:
					for offset in Hex.cells(int(action.radius)):
						if Hex.inside(cell+offset,battle.map.radius): board.area_cells[Hex.key(cell+offset)] = true
					detail += " · 範圍內只傷敵人"
			else:
				detail += "  |  "+Rules.attack_error(unit,target,action)
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
	if action_mode=="CHEST":
		if battle.open_chest(selection,cell):
			selection = ""
			after_action()
		else: notice("請選自己或相鄰格的未開啟寶箱；行動未消耗。")
		return
	if action_mode=="ITEM":
		var friend = Rules.unit_at(battle.units,cell)
		if battle.use_item(selection,str(friend.get("id","")),selected_item):
			selection = ""
			after_action()
		else: notice("先選道具，再點需要回復的自己或相鄰友軍；無效操作不消耗。")
		return
	var clicked = Rules.unit_at(battle.units,cell)
	if not clicked.is_empty() and (selection.is_empty() or action_mode == "COMMAND") and not battle.can_control(clicked.id):
		selection = ""
		inspected_id = clicked.id
		action_mode = "COMMAND"
		battle_ui()
		notice("查看角色資料；右鍵 / Esc 關閉。紫紅色標示為依目前占位預估的下一次普攻威脅。")
		return
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
		if battle.phase=="RESULT":
			after_action()
			return
		action_mode = "COMMAND"
		battle_ui()
		notice("移動完成。從角色周圍選擇攻擊、技能或待機。")
	elif action_mode in ["ATTACK","SKILL"]:
		var attacker_snapshot = selected_unit().duplicate(true)
		var target_snapshot = clicked.duplicate(true)
		var attack_action = Catalog.action(attacker_snapshot,action_mode == "SKILL")
		var result = battle.attack(selection,str(clicked.get("id","")),action_mode == "SKILL")
		if not result.ok:
			notice(Rules.attack_error(attacker_snapshot,target_snapshot,attack_action)+" 行動未消耗。")
			return
		var token = generation
		await present_combat(attacker_snapshot,target_snapshot,attack_action,result)
		if token != generation:
			return
		for hit in result.get("hits",[{"cell":cell,"damage":result.damage}]):
			board.add_damage(hit.cell,int(hit.damage))
		selection = ""
		action_mode = "MOVE"
		after_action()

func present_combat(actor: Dictionary, target: Dictionary, action: Dictionary, result: Dictionary) -> void:
	if not combat_cinematics:
		audio.play("hit")
		return
	var token = generation
	busy = true
	sync_board()
	cinematic.begin(actor,target,action,int(result.damage),maxi(0,int(target.hp)-int(result.damage)),reduced_motion)
	await cinematic.finished
	if token == generation:
		busy = false

func animate_movement(id: String, origin: Vector3i, path: Array, token: int) -> void:
	var previous = origin
	for cell in path:
		if int(battle.map.radius)>4: board.focus_cell(cell)
		if token != generation:
			return
		# Store logical cells, not cached pixels, so resize cannot detach a moving unit.
		board.visual_positions[id] = {"from":previous,"to":cell,"weight":0.0}
		if reduced_motion:
			board.visual_positions[id].weight = 1.0
		else:
			active_tween = create_tween()
			active_tween.tween_method(func(value):
				if token == generation and board.visual_positions.has(id):
					board.visual_positions[id].weight = value
					board.queue_redraw(),0.0,1.0,0.12)
			audio.play("move")
			await get_tree().create_timer(0.13).timeout
		previous = cell
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
		var attacker_snapshot = unit.duplicate(true)
		var target_snapshot = target.duplicate(true)
		var result = battle.commit_enemy(id,plan)
		if result.get("ok",false):
			await present_combat(attacker_snapshot,target_snapshot,Catalog.action(attacker_snapshot,bool(plan.get("skill",false))),result)
			if token != generation:
				return
			busy = true
			board.add_damage(target_cell,int(result.damage))
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
		if battle.phase=="RESULT":
			after_action()
			return
		selection = ""
		action_mode = "MOVE"
		battle_ui()
		notice("第 %d 回合：我方行動。" % battle.turn)

func show_result_controls() -> void:
	var victory = battle.result == "VICTORY"
	label("戰鬥勝利" if victory else "戰鬥失敗",28)
	label("VICTORY" if victory else "DEFEAT",18)
	label("完成於第 %d 回合" % battle.turn)
	label(battle.result_reason if not battle.result_reason.is_empty() else ("目標已完成。" if victory else "我方全軍覆沒。"))
	RPGUI.result_controls(self)
	label("下次出戰將恢復全部 HP／MP。",14)
	button("重新部署",func(): begin_deployment(level,battle.map.duplicate(true)))
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
	label("可供玩家挑選的角色",18)
	for row in Catalog.roster():
		var item = CheckBox.new()
		item.text = row.name+" · "+Catalog.data().jobs[row.job].name
		item.button_pressed = editing_level.playerIds.has(row.id)
		item.toggled.connect(func(value):
			if value and not editing_level.playerIds.has(row.id):
				editing_level.playerIds.append(row.id)
			elif not value:
				editing_level.playerIds.erase(row.id)
				for field in ["requiredIds","protectedIds"]:
					if editing_level.has(field): editing_level[field].erase(row.id)
			render_level_editor())
		sidebar.add_child(item)
	label("敵方陣容",18)
	if not editing_level.has("enemyLevels"):
		editing_level.enemyLevels = []
		for unused in editing_level.enemyIds: editing_level.enemyLevels.append(1)
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
		picker.item_selected.connect(func(index):
			editing_level.enemyIds[i] = enemy_ids[index]
			render_level_editor())
		row_box.add_child(picker)
		var enemy_level = SpinBox.new()
		enemy_level.min_value = 1
		enemy_level.max_value = 20
		enemy_level.step = 1
		enemy_level.prefix = "Lv."
		enemy_level.value = editing_level.enemyLevels[i]
		enemy_level.tooltip_text = "敵軍等級（依職業固定成長）"
		enemy_level.value_changed.connect(func(value): editing_level.enemyLevels[i] = int(value))
		row_box.add_child(enemy_level)
		var remove = Button.new()
		remove.text = "−"
		remove.tooltip_text = "移除此敵人"
		remove.pressed.connect(func():
			if editing_level.get("winCondition")=="TARGET":
				var target_index = int(editing_level.get("targetEnemyIndex",0))
				editing_level.targetEnemyIndex = -1 if i==target_index else (target_index-1 if i<target_index else target_index)
			editing_level.enemyIds.remove_at(i)
			editing_level.enemyLevels.remove_at(i)
			render_level_editor())
		row_box.add_child(remove)
	button("加入敵人",func():
		editing_level.enemyIds.append("enemy_swordsman_base")
		editing_level.enemyLevels.append(1)
		render_level_editor())
	MissionUI.editor(self)
	button("儲存關卡",save_level)
	button("另存新關卡",func():
		editing_level.levelId = "level_%d" % Time.get_ticks_usec()
		save_level())
	button("試玩部署",func():
		var errors = store.validate_level(editing_level)
		if errors.is_empty(): MissionUI.open(self,editing_level)
		else: notice("\n".join(errors)))
	button("編輯這張地圖",func(): open_map_editor(store.map_by_id(editing_level.mapId)))
	button("返回選單",show_menu)
	board.map = store.map_by_id(editing_level.mapId)
	board.units = []
	board.show_spawns = true
	board.show_coordinates = true
	board.objective_cells = MissionUI.goal_cells(editing_level,board.map)
	board.reachable = {}
	board.target_cells = {}
	board.path = []
	board.selected_id = ""
	board.queue_redraw()
	state_label.text = "關卡編輯"
	context_label.text = "配置出戰名單與敵軍"
	detail_label.text = "所選角色形成候選池；玩家在戰前按上限選出本場隊伍。"
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
	map_editor = MapEditor.new()
	editor_radius = int(map.radius)
	generator_preview = {}
	board.reset_camera()
	selection = ""
	brush = "PLAIN"
	render_map_editor()

func render_map_editor() -> void:
	generator_preview = {}
	stroke_active = false
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
	var names = {"CHEST":"放置木寶箱","ERASE_CHEST":"移除寶箱","PLAIN":"平地 · 1","FOREST":"森林 · 2","SWAMP":"沼澤 · 2","HILLS":"丘陵 · 2","MOUNTAIN":"山脈 · 禁行","WATER":"水域 · 禁行","PLAYER":"我方出生點","ENEMY":"敵方出生點","CLEAR":"清除出生點"}
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
	label("筆刷範圍 / 地圖尺寸",18)
	var brush_size = SpinBox.new()
	brush_size.min_value = 0
	brush_size.max_value = 3
	brush_size.value = brush_radius
	brush_size.prefix = "筆刷半徑 "
	brush_size.value_changed.connect(func(value): brush_radius = int(value))
	sidebar.add_child(brush_size)
	var fill_toggle = CheckButton.new()
	fill_toggle.text = "填滿同地形區域"
	fill_toggle.button_pressed = fill_brush
	fill_toggle.toggled.connect(func(value): fill_brush = value)
	sidebar.add_child(fill_toggle)
	button("復原 Ctrl+Z",func():
		editing_map = map_editor.undo(editing_map)
		render_map_editor())
	button("重做 Ctrl+Y",func():
		editing_map = map_editor.redo(editing_map)
		render_map_editor())
	var radius_input = SpinBox.new()
	radius_input.min_value = 1
	radius_input.max_value = Hex.MAX_RADIUS
	radius_input.value = editor_radius
	radius_input.prefix = "地圖半徑 "
	radius_input.value_changed.connect(func(value): editor_radius = int(value))
	sidebar.add_child(radius_input)
	button("套用尺寸（可復原）",func():
		map_editor.checkpoint(editing_map)
		map_editor.resize(editing_map,editor_radius)
		render_map_editor())
	label("規則生成",18)
	var seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 2147483647
	seed_input.value = generator_seed
	seed_input.prefix = "種子 "
	seed_input.value_changed.connect(func(value): generator_seed = int(value))
	sidebar.add_child(seed_input)
	var ratio_input = SpinBox.new()
	ratio_input.min_value = 0
	ratio_input.max_value = 45
	ratio_input.value = generator_ratio*100
	ratio_input.suffix = "% 山水目標"
	ratio_input.value_changed.connect(func(value): generator_ratio = value/100.0)
	sidebar.add_child(ratio_input)
	button("一鍵生成預覽",func():
		generator_preview = MapGenerator.generate(editor_radius,generator_seed,generator_ratio)
		board.map = generator_preview
		board.invalid_cells = {}
		board.queue_redraw()
		notice("生成預覽：%d 格。套用後才改變編輯內容。" % Hex.cells(editor_radius).size()))
	button("套用生成結果",func():
		if generator_preview.is_empty():
			notice("請先生成預覽。")
			return
		map_editor.checkpoint(editing_map)
		var old_id = editing_map.mapId
		var old_name = editing_map.name
		editing_map = generator_preview.duplicate(true)
		editing_map.mapId = old_id
		editing_map.name = old_name
		generator_preview = {}
		render_map_editor())
	button("返回編輯內容",func():
		generator_preview = {}
		render_map_editor())
	button("檢查連通與山水群落",validate_editor_map)
	button("鏡頭回到中央",board.reset_camera)
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
	board.show_coordinates = false
	board.invalid_cells = {}
	board.queue_redraw()
	state_label.text = "地圖編輯"
	context_label.text = "%s  ·  半徑 %d" % [editing_map.name,editing_map.radius]
	detail_label.text = "左鍵拖曳繪製 · 中鍵移動 · 滾輪縮放 · 右下小地圖定位 · Ctrl+Z / Y 復原重做"

func paint_cell(cell: Vector3i) -> void:
	if not generator_preview.is_empty():
		notice("目前為生成預覽，請先套用或返回編輯內容。")
		return
	if not stroke_active:
		map_editor.checkpoint(editing_map)
		stroke_active = true
	if brush in ["CHEST","ERASE_CHEST"]:
		if not editing_map.has("chests"): editing_map.chests = {}
		if brush=="ERASE_CHEST": editing_map.chests.erase(Hex.key(cell))
		elif Hex.terrain_cost(editing_map,cell)>0: editing_map.chests[Hex.key(cell)] = "wooden"
	else:
		map_editor.paint(editing_map,cell,brush,brush_radius,fill_brush)
	board.invalidate_terrain()
	board.invalid_cells = {}
	board.queue_redraw()

func validate_editor_map() -> void:
	var report = MapGenerator.diagnose(editing_map)
	board.invalid_cells = report.cells
	board.queue_redraw()
	notice("規則檢查通過：可走區連通，山水群落至少 3 格。" if report.errors.is_empty() else "\n".join(report.errors))

func save_map() -> void:
	var report = MapGenerator.diagnose(editing_map)
	if not report.errors.is_empty():
		validate_editor_map()
		return
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
		var report = MapGenerator.diagnose(editing_map)
		if not report.errors.is_empty():
			validate_editor_map()
			return
		var error = store.export_map(path,editing_map)
		notice("地圖已匯出。" if error.is_empty() else error)

func focus_inspected() -> void:
	var unit = battle.get_unit(inspected_id if not inspected_id.is_empty() else selection)
	if not busy and not unit.is_empty():
		board.focus_cell(unit.cell)

func show_help() -> void:
	if not busy:
		help_dialog.popup_centered(Vector2i(680,540))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or busy:
		return
	if confirm_dialog.visible or file_dialog.visible or help_dialog.visible:
		return
	if event.keycode == KEY_F3:
		performance_label.visible = not performance_label.visible
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F1:
		show_help()
		get_viewport().set_input_as_handled()
		return
	if mode == "MAP_EDITOR" and event.ctrl_pressed and event.keycode in [KEY_Z,KEY_Y]:
		editing_map = map_editor.undo(editing_map) if event.keycode == KEY_Z else map_editor.redo(editing_map)
		generator_preview = {}
		render_map_editor()
		get_viewport().set_input_as_handled()
		return
	if mode != "BATTLE":
		return
	if event.ctrl_pressed and event.keycode == KEY_S:
		request_save_battle()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_HOME:
		board.reset_camera()
	elif event.keycode == KEY_F:
		focus_inspected()
	elif event.keycode == KEY_T:
		show_all_threats = not show_all_threats
		battle_ui()
	elif event.keycode == KEY_ESCAPE and not inspected_id.is_empty():
		cancel_selection()
	else:
		var shortcuts = {KEY_M:"MOVE",KEY_A:"ATTACK",KEY_S:"SKILL",KEY_W:"WAIT",KEY_I:"ITEM",KEY_B:"CHEST",KEY_ESCAPE:"CANCEL"}
		if not shortcuts.has(event.keycode):
			return
		on_radial_action(shortcuts[event.keycode])
	get_viewport().set_input_as_handled()

func battle_save_path() -> String:
	return store.storage_path.get_base_dir().path_join("battle.json")

func request_save_battle() -> void:
	if busy or mode != "BATTLE" or battle.phase != "PLAYER":
		return
	if FileAccess.file_exists(battle_save_path()):
		confirm("覆寫先前的戰鬥存檔？上一份會保留為備份。",save_battle)
	else:
		save_battle()

func save_battle() -> void:
	if busy or mode != "BATTLE" or battle.phase != "PLAYER":
		return
	var error = Saves.write(battle_save_path(),Saves.snapshot(battle,level))
	notice("戰鬥已儲存；可從主選單繼續。" if error.is_empty() else error)

func load_battle(from_backup: bool = false) -> void:
	if busy or mode != "MENU":
		return
	var loaded = Saves.read(battle_save_path()+(".bak" if from_backup else ""))
	if not loaded.ok:
		notice(loaded.message)
		return
	invalidate_animation()
	if party.settled_ids.has(loaded.get("rpg",{}).get("battle_id","")):
		notice("這場戰鬥已結算，不能載入舊快照再次領取戰利品。")
		return
	Saves.restore(battle,loaded)
	if loaded.get("rpg",{}).is_empty():
		battle.inventory = party.inventory.duplicate(true)
		battle.loadouts = party.loadouts.duplicate(true)
		battle.history.clear()
		battle.capture_round()
	level = loaded.level.duplicate(true)
	selection = ""
	inspected_id = ""
	action_mode = "COMMAND"
	mode = "BATTLE"
	board.reset_camera()
	battle_ui()
	notice("%s第 %d 回合；HP／MP 與已移動／已行動狀態均保留。" % ["已從備份恢復" if from_backup else "已繼續",battle.turn])

func persist_preferences() -> void:
	var error = preferences.save()
	if not error.is_empty() and status_label != null:
		notice("設定保存失敗："+error)

func _exit_tree() -> void:
	generation += 1
	if is_instance_valid(cinematic):
		cinematic.abort()
	if is_instance_valid(settings_timer) and not settings_timer.is_stopped():
		preferences.save()

func _process(delta: float) -> void:
	performance_clock += delta
	if performance_clock < 0.5 or performance_label == null: return
	performance_clock = 0.0
	if performance_label.visible:
		performance_label.text = "FPS %d / 60 · 引擎幀時間 %.2f ms\nGodot 記憶體 %.1f MiB · VRAM %.1f MiB · Draw %d" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]

func rewind_battle(target: int) -> void:
	if busy or battle.settled: return
	if battle.rewind_to(target):
		invalidate_animation()
		mode = "BATTLE"
		selection = ""
		inspected_id = ""
		action_mode = "COMMAND"
		battle_ui()
		notice("已回到第 %d 回合開始；背包、寶箱與隨機狀態同步還原。" % target)
