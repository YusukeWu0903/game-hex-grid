extends Control
signal finished
const Story = preload("res://core/story_dialogue.gd")
const Catalog = preload("res://core/catalog.gd")
var lines: Array = []
var index = 0
var state: Dictionary
var elapsed = 0.0
var body: RichTextLabel
var nameplate: Label
var portrait: TextureRect
var history_panel: PanelContainer
var transcript: RichTextLabel
var advance_button: Button
var skip_dialog: ConfirmationDialog
var cache: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new()
	shade.color = Color(0.02,0.03,0.06,0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_left = 0.04
	portrait.anchor_right = 0.50
	portrait.anchor_top = 0.04
	portrait.anchor_bottom = 0.78
	add_child(portrait)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.70
	panel.anchor_bottom = 0.96
	var style = StyleBoxFlat.new()
	style.bg_color = Color("15232bf2")
	style.border_color = Color("af9561")
	style.set_border_width_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	nameplate = Label.new()
	nameplate.add_theme_font_size_override("font_size",24)
	nameplate.add_theme_color_override("font_color",Color("e4c68a"))
	column.add_child(nameplate)
	body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.add_theme_font_size_override("normal_font_size",22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	for title in ["歷史 H","略過本段","下一句  Space / Enter"]:
		var b = Button.new()
		b.text = title
		b.focus_mode = Control.FOCUS_NONE
		actions.add_child(b)
		if title.begins_with("歷史"): b.pressed.connect(toggle_history)
		elif title.begins_with("略過"): b.pressed.connect(func(): skip_dialog.popup_centered())
		else:
			advance_button = b
			b.pressed.connect(advance)
	history_panel = PanelContainer.new()
	history_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	history_panel.anchor_left = 0.12
	history_panel.anchor_right = 0.88
	history_panel.anchor_top = 0.08
	history_panel.anchor_bottom = 0.90
	history_panel.add_theme_stylebox_override("panel",style)
	add_child(history_panel)
	var history_box = VBoxContainer.new()
	history_panel.add_child(history_box)
	transcript = RichTextLabel.new()
	transcript.add_theme_font_size_override("normal_font_size",22)
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_box.add_child(transcript)
	var back = Button.new()
	back.text = "返回對話  H / Esc"
	back.pressed.connect(toggle_history)
	history_box.add_child(back)
	skip_dialog = ConfirmationDialog.new()
	skip_dialog.dialog_text = "略過本段對話？未閱讀的台詞不會加入歷史。"
	skip_dialog.confirmed.connect(finish)
	add_child(skip_dialog)
	hide()
	set_process(false)

func play(queue: Array, story_state: Dictionary) -> void:
	lines = queue
	state = story_state
	index = 0
	history_panel.hide()
	show()
	set_process(true)
	show_line()

func show_line() -> void:
	var line = lines[index]
	elapsed = 0.0
	body.text = line.text
	body.visible_characters = 0
	nameplate.text = line.speaker
	nameplate.visible = not line.speaker.is_empty()
	advance_button.text = "顯示全文  Space / Enter"
	var path = str(line.portrait)
	portrait.visible = not path.is_empty()
	if not path.is_empty():
		if not cache.has(path): cache[path] = load("res://assets/portraits/"+path+".png")
		portrait.texture = cache[path]
		portrait.flip_h = line.side == "RIGHT"
		portrait.anchor_left = 0.50 if line.side == "RIGHT" else 0.04
		portrait.anchor_right = 0.96 if line.side == "RIGHT" else 0.50

func reveal() -> void:
	body.visible_characters = -1
	Story.record(state,lines[index].id)
	advance_button.text = "下一句  Space / Enter"

func advance() -> void:
	if not visible or history_panel.visible or skip_dialog.visible: return
	if body.visible_characters != -1:
		reveal()
		return
	index += 1
	if index >= lines.size(): finish()
	else: show_line()

func finish() -> void:
	abort()
	finished.emit()

func abort() -> void:
	hide()
	set_process(false)
	if is_instance_valid(skip_dialog): skip_dialog.hide()
	lines = []
	cache.clear()
	if is_instance_valid(portrait): portrait.texture = null

func toggle_history() -> void:
	if history_panel.visible:
		history_panel.hide()
		return
	var lookup = {}
	for script in Catalog.data().get("dialogues",{}).values():
		for line in script: lookup[line.id] = line
	var text = ""
	for id in state.log:
		if lookup.has(id): text += (lookup[id].speaker+"\n" if lookup[id].speaker!="" else "")+lookup[id].text+"\n\n"
	transcript.text = text if not text.is_empty() else "尚無已讀台詞。"
	history_panel.show()

func _process(delta: float) -> void:
	if history_panel.visible or skip_dialog.visible or body.visible_characters == -1: return
	elapsed += delta
	body.visible_characters = int(elapsed / 0.028)
	if body.visible_characters >= body.get_total_character_count(): reveal()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and not skip_dialog.visible:
		if event.keycode == KEY_H or (event.keycode == KEY_ESCAPE and history_panel.visible): toggle_history()
		elif event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]: advance()
	if event is InputEventKey and not skip_dialog.visible: get_viewport().set_input_as_handled()
