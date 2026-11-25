extends Control
signal finished
signal impact
const Catalog = preload("res://core/catalog.gd")
var actor: Dictionary = {}
var target: Dictionary = {}
var action: Dictionary = {}
var damage = 0
var target_hp = 0
var elapsed = 0.0
var reduced = false
var impacted = false
var active = false
var skip_button: Button
var portrait_cache: Dictionary = {}
const IMPACT_TIME = 1.20
const DURATION = 2.65

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	focus_mode = Control.FOCUS_ALL
	skip_button = Button.new()
	skip_button.text = "跳過演出  Space / Esc"
	skip_button.tooltip_text = "直接返回戰場；已成立的攻擊仍會結算一次。"
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.position = Vector2(-250,-65)
	skip_button.size = Vector2(225,42)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	focus_next = get_path_to(skip_button)
	focus_previous = get_path_to(skip_button)
	skip_button.focus_next = skip_button.get_path_to(self)
	skip_button.focus_previous = skip_button.get_path_to(self)
	hide()

func begin(attacker: Dictionary, defender: Dictionary, move: Dictionary, hit_damage: int, remaining_hp: int, reduce_motion: bool) -> void:
	actor = attacker.duplicate(true)
	target = defender.duplicate(true)
	action = move.duplicate(true)
	damage = hit_damage
	target_hp = remaining_hp
	elapsed = 0.0
	reduced = reduce_motion
	impacted = false
	active = true
	show()
	grab_focus()
	queue_redraw()

func skip() -> void:
	if not active:
		return
	# Presentation signals never mutate authoritative combat state.
	if not impacted:
		impacted = true
		impact.emit()
	active = false
	hide()
	finished.emit()

func abort() -> void:
	if not active:
		hide()
		return
	active = false
	hide()
	finished.emit()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ESCAPE,KEY_ENTER]:
		skip()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var hit_time = 0.25 if reduced else IMPACT_TIME
	if not impacted and elapsed >= hit_time:
		impacted = true
		impact.emit()
	if elapsed >= (0.8 if reduced else DURATION):
		active = false
		hide()
		finished.emit()
	queue_redraw()

func write_text(at: Vector2, value: String, font_size: int, color: Color, width: float = -1) -> void:
	draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func silhouette(unit: Dictionary, base: Vector2, facing: float, attack_offset: float, hit: bool) -> void:
	var color = Color("#76bbd0") if unit.faction == "PLAYER" else Color("#ce838b")
	var shadow = Color("#111e2b") if unit.faction == "PLAYER" else Color("#2b1721")
	var dark = color.darkened(0.65)
	var flash = hit and impacted and not reduced and elapsed < 1.38
	if flash:
		color = Color("#f5e6cc")
	var alpha = 1.0
	if hit and target_hp == 0 and impacted:
		alpha = 0.5 if reduced else lerpf(1.0,0.22,clampf((elapsed-1.5)/0.7,0,1))
	color.a = alpha
	shadow.a = alpha
	dark.a = alpha
	draw_set_transform(_stage_offset+(base+Vector2(attack_offset,0))*_stage_scale,0,Vector2(facing,1)*_stage_scale)
	# Optional adopted artwork can replace the placeholder without changing combat.
	var path = "res://assets/portraits/%s.png" % str(unit.get("id",""))
	if not ResourceLoader.exists(path):
		path = "res://assets/portraits/%s_%s.png" % [unit.job,str(unit.faction).to_lower()]
	if not portrait_cache.has(path):
		portrait_cache[path] = load(path) if ResourceLoader.exists(path) else null
	if portrait_cache[path] != null:
		var texture: Texture2D = portrait_cache[path]
		var image_size = texture.get_size()
		var factor = minf(420.0/image_size.x,470.0/image_size.y)
		draw_texture_rect(texture,Rect2(Vector2(-image_size.x*factor/2,-image_size.y*factor),image_size*factor),false,Color(1,1,1,alpha))
		draw_set_transform(Vector2.ZERO)
		return
	# Full-body, weapon-bearing job silhouettes; intentionally not final character art.
	draw_ellipse_shadow(Vector2(0,4),Vector2(115,18),Color(0,0,0,0.3))
	poly([Vector2(-55,-316),Vector2(-92,-290),Vector2(-125,-90),Vector2(-20,-120),Vector2(44,-210)],dark)
	poly([Vector2(-50,-142),Vector2(-6,-141),Vector2(-15,-36),Vector2(-47,-8),Vector2(-86,-8),Vector2(-54,-37)],shadow)
	poly([Vector2(5,-141),Vector2(45,-144),Vector2(49,-37),Vector2(80,-14),Vector2(80,0),Vector2(18,0),Vector2(10,-32)],shadow)
	poly([Vector2(-55,-310),Vector2(31,-314),Vector2(59,-224),Vector2(42,-131),Vector2(-61,-131),Vector2(-72,-220)],color)
	poly([Vector2(-38,-282),Vector2(16,-285),Vector2(26,-208),Vector2(-29,-197)],dark)
	poly([Vector2(-60,-167),Vector2(44,-167),Vector2(43,-147),Vector2(-61,-147)],shadow)
	draw_circle(Vector2(-9,-358),39,color)
	if unit.job == "swordsman":
		poly([Vector2(-49,-369),Vector2(-30,-406),Vector2(16,-406),Vector2(36,-373),Vector2(30,-345),Vector2(-48,-345)],shadow)
		draw_line(Vector2(4,-370),Vector2(32,-370),color,5,true)
		poly([Vector2(-61,-310),Vector2(-91,-286),Vector2(-69,-257),Vector2(-37,-275)],shadow)
		poly([Vector2(19,-304),Vector2(48,-306),Vector2(95,-238),Vector2(70,-217),Vector2(37,-249)],color)
		draw_line(Vector2(76,-229),Vector2(105,-250),shadow,19,true)
		# Sword points toward the opposing side, with a separate guard and grip.
		poly([Vector2(103,-265),Vector2(195,-390),Vector2(208,-417),Vector2(205,-383),Vector2(120,-253)],Color("#dbe0d6"))
		draw_line(Vector2(89,-280),Vector2(132,-245),color,8,true)
		draw_line(Vector2(104,-260),Vector2(83,-230),shadow,10,true)
	else:
		poly([Vector2(-50,-352),Vector2(-38,-401),Vector2(4,-418),Vector2(38,-380),Vector2(28,-347),Vector2(13,-378),Vector2(-16,-385),Vector2(-22,-344)],shadow)
		draw_line(Vector2(-64,-289),Vector2(-92,-361),Color("#b7a783"),9,true)
		poly([Vector2(-76,-320),Vector2(-49,-327),Vector2(-19,-223),Vector2(-43,-215)],shadow)
		poly([Vector2(21,-301),Vector2(43,-280),Vector2(108,-286),Vector2(112,-264),Vector2(32,-250),Vector2(10,-274)],color)
		draw_arc(Vector2(103,-263),104,-PI/2,PI/2,40,Color("#d7bd86"),7,true)
		draw_line(Vector2(103,-367),Vector2(103,-159),Color("#dfdfd4"),2,true)
		draw_line(Vector2(41,-268),Vector2(220,-268),Color("#e8dfbf"),3,true)
		poly([Vector2(220,-268),Vector2(207,-275),Vector2(207,-261)],Color("#e8dfbf"))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(at: Vector2, radius: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(40):
		points.append(at+Vector2(cos(TAU*i/40),sin(TAU*i/40))*radius)
	draw_colored_polygon(points,color)

func unit_panel(unit: Dictionary, at: Vector2, is_target: bool) -> void:
	var color = Color("#8dcde0") if unit.faction == "PLAYER" else Color("#e9a3ac")
	var hp = int(unit.hp)
	if is_target and impacted:
		hp = target_hp
	write_text(at,unit.name,28,color)
	write_text(at+Vector2(0,31),Catalog.data().jobs[unit.job].name,18,Color("#c0c7d2"))
	draw_rect(Rect2(at+Vector2(0,48),Vector2(330,10)),Color("#26313f"))
	draw_rect(Rect2(at+Vector2(0,48),Vector2(330*float(hp)/unit.max_hp,10)),color)
	write_text(at+Vector2(0,85),"HP %d / %d" % [hp,unit.max_hp],22,Color("#e6e9e9"))
	var mp = int(unit.mp)
	if not is_target:
		mp = maxi(0,mp-int(action.mp_cost))
	write_text(at+Vector2(200,85),"MP %d" % mp,18,Color("#b9c5d8"))

func _draw() -> void:
	if actor.is_empty():
		return
	# Fit the entire composition at both supported window sizes.
	var scale_factor = minf(size.x/1440.0,size.y/900.0)
	var offset = (size-Vector2(1440,900)*scale_factor)/2.0
	draw_rect(Rect2(Vector2.ZERO,size),Color("#090e19"))
	draw_set_transform(offset,0,Vector2.ONE*scale_factor)
	draw_rect(Rect2(0,155,720,535),Color("#101e2d"))
	draw_rect(Rect2(720,155,720,535),Color("#281923"))
	for i in range(7):
		draw_line(Vector2(0,175+i*75),Vector2(1440,175+i*75),Color(0.6,0.65,0.7,0.04),1,true)
	draw_line(Vector2(720,170),Vector2(720,670),Color("#53475c"),1,true)
	write_text(Vector2(80,83),"交戰",18,Color("#aaa7ac"))
	write_text(Vector2(80,127),"%s  →  %s" % [actor.name,target.name],26,Color("#e5ddcf"))
	write_text(Vector2(650,125),action.name,32,Color("#f2d4a0"))
	var player = actor if actor.faction == "PLAYER" else target
	var enemy = target if actor.faction == "PLAYER" else actor
	var enter = 0.0 if reduced else (1.0-clampf(elapsed/0.4,0,1))*110.0
	var lunge = 0.0
	if not reduced:
		lunge = 85.0*clampf((elapsed-0.78)/0.42,0,1)*(1.0-clampf((elapsed-1.40)/0.35,0,1))
	var shake = 0.0
	if not reduced and impacted and elapsed < 1.65:
		shake = sin(elapsed*90.0)*12*(1.0-clampf((elapsed-1.2)/0.45,0,1))
	# Each portrait helper resets transforms, so restore the stage transform between calls.
	var left_pos = Vector2(365-enter,665)
	var right_pos = Vector2(1075+enter,665)
	var left_offset = lunge if player.id == actor.id else shake
	var right_offset = -lunge if enemy.id == actor.id else shake
	# Helpers use design-space coordinates, composed through a temporary canvas transform.
	draw_set_transform(offset,0,Vector2.ONE*scale_factor)
	portrait_stage(player,left_pos,1,left_offset,player.id==target.id,offset,scale_factor)
	portrait_stage(enemy,right_pos,-1,right_offset,enemy.id==target.id,offset,scale_factor)
	draw_set_transform(offset,0,Vector2.ONE*scale_factor)
	if not reduced and elapsed > 0.95 and elapsed < 1.65:
		var side = 1.0 if actor.faction == "PLAYER" else -1.0
		var at = Vector2(1075 if side > 0 else 365,415)
		var effect_color = Color("#ffdd9a") if int(action.mp_cost)>0 else Color("#e4f1ef")
		if actor.job == "archer" and elapsed < 1.25:
			var t = clampf((elapsed-0.95)/0.3,0,1)
			var x = lerpf(470 if side>0 else 970,at.x,t)
			draw_line(Vector2(x-side*100,415),Vector2(x,415),effect_color,4,true)
			poly([Vector2(x,415),Vector2(x-side*17,408),Vector2(x-side*17,422)],effect_color)
		elif impacted:
			draw_line(at+Vector2(-65,-90),at+Vector2(65,85),effect_color,8,true)
			draw_line(at+Vector2(-40,60),at+Vector2(45,-60),effect_color,4,true)
			if int(action.mp_cost)>0:
				draw_arc(at,95,0,TAU,50,effect_color,3,true)
	if impacted:
		var at = Vector2(1015 if target.faction == "ENEMY" else 305,245)
		write_text(at,"−%d" % damage,52,Color("#ffe1ad"))
		if target_hp == 0:
			write_text(at+Vector2(-4,42),"擊倒",25,Color("#f4b0ab"))
	unit_panel(player,Vector2(160,735),player.id==target.id)
	unit_panel(enemy,Vector2(940,735),enemy.id==target.id)
	draw_set_transform(Vector2.ZERO)

# Map portrait drawing to the fitted stage, including the optional texture path.
func portrait_stage(unit: Dictionary, base: Vector2, facing: float, displacement: float, hit: bool, offset: Vector2, scale_factor: float) -> void:
	# silhouette issues local transforms; stage mapping is supplied through these fields.
	_stage_offset = offset
	_stage_scale = scale_factor
	silhouette(unit,base,facing,displacement,hit)
var _stage_offset = Vector2.ZERO
var _stage_scale = 1.0
