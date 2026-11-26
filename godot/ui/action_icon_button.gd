extends Button
var action_id = ""
var accent = Color("#79c8dd")

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(54,54)
	size = Vector2(54,54)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size/2.0) <= size.x/2.0

func _draw() -> void:
	var center = size/2.0
	var radius = size.x/2.0 - 2
	var lit = is_hovered() or has_focus()
	var background = Color("#172b3b")
	var ink = Color("#e9f4f7")
	var border = accent
	if lit:
		background = Color("#30566b")
		border = Color("#f2d79b")
	if is_pressed():
		background = Color("#466a7e")
	if disabled:
		background = Color("#17212b")
		ink = Color("#657684")
		border = Color("#435360")
	draw_circle(center+Vector2(0,3),radius+2,Color(0,0,0,0.65))
	draw_circle(center,radius,background)
	draw_arc(center,radius,0,TAU,48,border,2.2,true)
	if lit and not disabled:
		draw_arc(center,radius-4,0,TAU,48,Color(1,0.88,0.6,0.30),1.0,true)
	match action_id:
		"MOVE":
			# Boot and a direction chevron.
			draw_polyline(PackedVector2Array([center+Vector2(-11,-12),center+Vector2(-2,-12),center+Vector2(-1,-2),center+Vector2(10,2),center+Vector2(12,10),center+Vector2(-12,10),center+Vector2(-11,-12)]),ink,2.3,true)
			draw_line(center+Vector2(-10,5),center+Vector2(9,5),ink,2.0,true)
			draw_polyline(PackedVector2Array([center+Vector2(5,-12),center+Vector2(11,-7),center+Vector2(5,-2)]),ink,2.0,true)
		"ATTACK":
			# Sword: pointed blade, crossguard, hilt.
			draw_colored_polygon(PackedVector2Array([center+Vector2(-3,4),center+Vector2(7,-12),center+Vector2(12,-15),center+Vector2(12,-9),center+Vector2(2,8)]),ink)
			draw_line(center+Vector2(-7,1),center+Vector2(7,11),ink,2.8,true)
			draw_line(center+Vector2(-1,7),center+Vector2(-7,14),ink,3.2,true)
		"SKILL":
			# Four-point burst, distinct from the normal sword attack.
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(4,-4),center+Vector2(14,0),center+Vector2(4,4),center+Vector2(0,15),center+Vector2(-4,4),center+Vector2(-14,0),center+Vector2(-4,-4)]),ink)
			draw_circle(center+Vector2(12,-12),2.0,ink)
			draw_circle(center+Vector2(-12,12),1.8,ink)
		"WAIT":
			# Hourglass.
			draw_line(center+Vector2(-11,-13),center+Vector2(11,-13),ink,2.5,true)
			draw_line(center+Vector2(-11,13),center+Vector2(11,13),ink,2.5,true)
			draw_polyline(PackedVector2Array([center+Vector2(-9,-12),center+Vector2(-8,-6),center+Vector2(6,7),center+Vector2(8,12)]),ink,2.0,true)
			draw_polyline(PackedVector2Array([center+Vector2(9,-12),center+Vector2(8,-6),center+Vector2(-6,7),center+Vector2(-8,12)]),ink,2.0,true)
			draw_colored_polygon(PackedVector2Array([center+Vector2(-6,10),center+Vector2(0,5),center+Vector2(6,10)]),ink)
		"ITEM":
			draw_rect(Rect2(center+Vector2(-4,-14),Vector2(8,7)),ink,false,2)
			draw_circle(center+Vector2(0,4),10,ink,false,2)
			draw_line(center+Vector2(-6,4),center+Vector2(6,4),ink,2)
			draw_line(center+Vector2(0,-2),center+Vector2(0,10),ink,2)
		"CHEST":
			draw_rect(Rect2(center+Vector2(-13,-9),Vector2(26,21)),ink,false,2)
			draw_line(center+Vector2(-13,-1),center+Vector2(13,-1),ink,2)
			draw_rect(Rect2(center+Vector2(-3,-3),Vector2(6,8)),ink)
		"CANCEL":
			draw_line(center+Vector2(-9,-9),center+Vector2(9,9),ink,3.0,true)
			draw_line(center+Vector2(9,-9),center+Vector2(-9,9),ink,3.0,true)
	if disabled:
		# A lock mark reinforces the disabled color.
		var lock_at = center+Vector2(16,17)
		draw_circle(lock_at,7.0,Color("#0c141e"))
		draw_rect(Rect2(lock_at+Vector2(-3,-1),Vector2(6,5)),ink)
		draw_arc(lock_at+Vector2(0,-1),3,PI,TAU,12,ink,1.5,true)
