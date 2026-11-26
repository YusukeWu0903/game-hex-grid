extends Control
const IconButton = preload("res://ui/action_icon_button.gd")
const Catalog = preload("res://core/catalog.gd")
signal action_requested(action: String)
var buttons: Dictionary = {}
var utility_buttons: Dictionary = {}
var board
var anchor_cell = Vector3i.ZERO
var ring_center = Vector2.ZERO
var unit_center = Vector2.ZERO
const ORDER = ["MOVE","ATTACK","SKILL","WAIT","CANCEL"]
const LABELS = {"MOVE":"移動","ATTACK":"攻擊","SKILL":"技能","WAIT":"待機","CANCEL":"取消選取"}
const KEYS = {"MOVE":"M","ATTACK":"A","SKILL":"S","WAIT":"W","CANCEL":"Esc"}
const ANGLES = [-90.0,-18.0,54.0,126.0,198.0]
const RADIUS = 83.0
const EDGE = 116.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 5
	for id in ORDER:
		var item = IconButton.new()
		item.action_id = id
		item.name = "Action" + id
		item.accessibility_name = LABELS[id]
		if id == "ATTACK": item.accent = Color("#e89787")
		if id == "SKILL": item.accent = Color("#c7b2e9")
		if id == "WAIT": item.accent = Color("#d9c291")
		item.pressed.connect(func(): action_requested.emit(id))
		item.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				action_requested.emit("CANCEL")
				item.accept_event())
		add_child(item)
		buttons[id] = item
	for id in ["ITEM","CHEST"]:
		var item = IconButton.new()
		item.action_id = id
		item.tooltip_text = "道具 [I]：選擇消耗品並點自己／相鄰友軍" if id=="ITEM" else "開箱 [B]：點自己／相鄰格的寶箱，消耗行動"
		item.accessibility_name = "使用道具" if id=="ITEM" else "開啟寶箱"
		item.pressed.connect(func(): action_requested.emit(id))
		utility_buttons[id] = item
		add_child(item)
	for i in range(ORDER.size()):
		var item = buttons[ORDER[i]]
		item.focus_next = item.get_path_to(buttons[ORDER[(i+1)%ORDER.size()]])
		item.focus_previous = item.get_path_to(buttons[ORDER[(i+4)%ORDER.size()]])
	buttons.CANCEL.focus_next = buttons.CANCEL.get_path_to(utility_buttons.ITEM)
	utility_buttons.ITEM.focus_previous = utility_buttons.ITEM.get_path_to(buttons.CANCEL)
	utility_buttons.ITEM.focus_next = utility_buttons.ITEM.get_path_to(utility_buttons.CHEST)
	utility_buttons.CHEST.focus_previous = utility_buttons.CHEST.get_path_to(utility_buttons.ITEM)
	utility_buttons.CHEST.focus_next = utility_buttons.CHEST.get_path_to(buttons.MOVE)
	buttons.MOVE.focus_previous = buttons.MOVE.get_path_to(utility_buttons.CHEST)
	hide()

func configure(unit: Dictionary) -> void:
	anchor_cell = unit.cell
	var skill = Catalog.action(unit,true)
	for id in ORDER:
		var item = buttons[id]
		item.disabled = false
		var tip = "%s  [%s]" % [LABELS[id],KEYS[id]]
		match id:
			"MOVE":
				item.disabled = unit.moved
				tip += "\n本回合已移動" if unit.moved else "\n移動力 %d，依地形計算消耗" % unit.movement
			"ATTACK":
				var attack = Catalog.action(unit)
				item.disabled = unit.mp<int(attack.mp_cost)
				tip += "\n%s · %d MP" % [attack.name,attack.mp_cost]
				tip += "\n%d 傷害 · 射程 %d–%d" % [attack.damage,attack.range_min,attack.range_max]
			"SKILL":
				item.disabled = unit.mp < skill.mp_cost
				tip = "%s  [S]\n%d MP · %d 傷害 · 射程 %d–%d" % [skill.name,skill.mp_cost,skill.damage,skill.range_min,skill.range_max]
				if item.disabled:
					tip += "\nMP 不足：目前 %d / 需要 %d" % [unit.mp,skill.mp_cost]
			"WAIT":
				tip += "\n結束這名角色的行動"
			"CANCEL":
				tip += "\n不消耗行動；已完成的移動保留"
		item.tooltip_text = tip
		item.accessibility_description = tip
		item.queue_redraw()
	show()
	reposition()

func reposition() -> void:
	if board == null or not visible:
		return
	var new_unit_center: Vector2 = board.position_of(anchor_cell)
	# Keep the whole ring on the board; a leader connects an inset ring to its unit.
	var new_ring_center = Vector2(clampf(new_unit_center.x,EDGE,maxf(EDGE,size.x-EDGE)),
		clampf(new_unit_center.y,EDGE,maxf(EDGE,size.y-155)))
	var changed = new_unit_center != unit_center or new_ring_center != ring_center
	unit_center = new_unit_center
	ring_center = new_ring_center
	for i in range(ORDER.size()):
		var angle = deg_to_rad(ANGLES[i])
		buttons[ORDER[i]].position = ring_center+Vector2(cos(angle),sin(angle))*RADIUS-Vector2(27,27)
	for i in range(2):
		utility_buttons[["ITEM","CHEST"][i]].position = ring_center+Vector2(-34 if i==0 else 34,119)-Vector2(27,27)
	if changed: queue_redraw()

func _process(_delta: float) -> void:
	reposition()

func _draw() -> void:
	if unit_center.distance_to(ring_center) > 2:
		draw_line(unit_center,ring_center,Color(0.94,0.81,0.54,0.65),1.5,true)
		draw_arc(unit_center,9.0,0,TAU,24,Color("#e7c68b"),1.5,true)
	# Short arcs connect commands while leaving the selected unit visible.
	for angle in ANGLES:
		draw_arc(ring_center,RADIUS,deg_to_rad(angle+22),deg_to_rad(angle+50),12,Color(0.55,0.69,0.76,0.30),1.2,true)
