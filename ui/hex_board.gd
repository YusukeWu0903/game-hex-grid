extends Control
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
signal cell_clicked(cell: Vector3i, button: int)
signal cell_hovered(cell: Vector3i)
signal cell_dragged(cell: Vector3i)
signal stroke_finished
var invalid_cells: Dictionary = {}
var camera_target = Vector2.ZERO
var zoom_target = 1.0
var painting = false
var edge_scroll_enabled = true
var minimap_dragging = false
var map: Dictionary = {}:
	set(value):
		map = value
		cached_cells = Hex.cells(int(map.get("radius",0))) if not map.is_empty() else []
		cached_cells.sort_custom(func(a,b): return a.z<b.z if a.z!=b.z else a.x<b.x)
		minimap_dirty = true
		if terrain_layer != null:
			terrain_layer.map = map
			terrain_layer.cells = cached_cells
			terrain_layer.queue_redraw()
var cached_cells: Array = []
var minimap_dirty = true
var minimap_texture: ImageTexture
var terrain_texture: NoiseTexture2D
var tile_atlas: Texture2D
var terrain_layer: Node2D
var automatic_focus = false
var last_painted = Vector3i(999,999,999)
var units: Array = []
var selected_id = ""
var reachable: Dictionary = {}
var target_cells: Dictionary = {}
var threat_cells: Dictionary = {}
var inspected_id = ""
var pan_offset = Vector2.ZERO
var dragging = false
var camera_locked = false
var path: Array = []
var visual_positions: Dictionary = {}
var hovered = Vector3i(999,999,999)
var show_spawns = false
var show_coordinates = false
var zoom = 1.0
var effects: Array = []
const COLORS = {"PLAIN":Color("#82916a"),"FOREST":Color("#4e7150"),"SWAMP":Color("#75846a"),
	"HILLS":Color("#a79670"),"MOUNTAIN":Color("#7c827e"),"WATER":Color("#46868e")}
const LABELS = {"PLAIN":"", "FOREST":"森", "SWAMP":"沼", "HILLS":"丘", "MOUNTAIN":"山", "WATER":"水"}

func _ready() -> void:
	var background = ColorRect.new()
	background.color = Color("#242e30")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.show_behind_parent = true
	add_child(background)
	terrain_layer = preload("res://ui/terrain_layer.gd").new()
	terrain_layer.show_behind_parent = true
	terrain_layer.map = map
	terrain_layer.cells = cached_cells
	add_child(terrain_layer)
	var noise = FastNoiseLite.new()
	noise.seed = 17
	noise.frequency = 0.08
	terrain_texture = NoiseTexture2D.new()
	terrain_texture.width = 256
	terrain_texture.height = 256
	terrain_texture.noise = noise
	var ramp = Gradient.new()
	ramp.set_color(0,Color(0.78,0.80,0.74))
	ramp.set_color(1,Color(1,1,0.94))
	terrain_texture.color_ramp = ramp
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	mouse_exited.connect(func():
		hovered = Vector3i(999,999,999)
		cell_hovered.emit(hovered)
		queue_redraw())
	if DisplayServer.get_name() != "headless": bake_terrain_atlas()

func hex_size() -> float:
	var radius = mini(4,int(map.get("radius",4)))
	return minf(size.x / (sqrt(3.0)*(2*radius+1)+1), size.y/(3*radius+4)) * zoom

func center() -> Vector2:
	return size * Vector2(0.5,0.49) + pan_offset

func position_of(cell: Vector3i) -> Vector2:
	return center() + Hex.to_pixel(cell,hex_size())

func reset_camera() -> void:
	pan_offset = Vector2.ZERO
	camera_target = Vector2.ZERO
	zoom = 1.0
	zoom_target = 1.0
	automatic_focus = false
	queue_redraw()

func focus_cell(cell: Vector3i) -> void:
	automatic_focus = true
	camera_target = -Hex.to_pixel(cell,hex_size())
	queue_redraw()

func camera_limit() -> Vector2:
	return Vector2(sqrt(3.0),1.5)*float(map.get("radius",4))*hex_size()

func minimap_rect() -> Rect2:
	return Rect2(Vector2(size.x-174,size.y-154),Vector2(160,140))

func minimap_scale() -> float:
	return 60.0/(maxi(1,int(map.get("radius",4)))*sqrt(3.0))

func minimap_seek(point: Vector2) -> void:
	camera_target = -(point-minimap_rect().get_center())/minimap_scale()*hex_size()
	camera_target = camera_target.clamp(-camera_limit(),camera_limit())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			painting = false
			last_painted = Vector3i(999,999,999)
			minimap_dragging = false
			stroke_finished.emit()
		if event.button_index == MOUSE_BUTTON_MIDDLE: dragging = false

func _gui_input(event: InputEvent) -> void:
	if map.is_empty(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and minimap_rect().has_point(event.position):
			if not camera_locked:
				minimap_dragging = true
				minimap_seek(event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed and not camera_locked
			accept_event()
			return
	if event is InputEventMouseMotion:
		if minimap_dragging and not camera_locked:
			minimap_seek(event.position)
			accept_event()
			return
		if dragging and not camera_locked:
			camera_target = (camera_target+event.relative).clamp(-camera_limit(),camera_limit())
			accept_event()
			return
		var cell = Hex.from_pixel(event.position-center(),hex_size())
		if cell != hovered:
			hovered = cell
			cell_hovered.emit(cell)
			if painting and Hex.inside(cell,map.radius):
				if Hex.inside(last_painted,map.radius):
					var steps = maxi(1,Hex.distance(last_painted,cell))
					for i in range(1,steps+1):
						cell_dragged.emit(Hex.from_pixel(Hex.to_pixel(last_painted,1).lerp(Hex.to_pixel(cell,1),float(i)/steps),1))
				else: cell_dragged.emit(cell)
				last_painted = cell
			queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if not camera_locked:
				zoom_target = clampf(zoom_target+(0.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -0.1),0.45,2.0)
		else:
			var cell = Hex.from_pixel(event.position-center(),hex_size())
			if Hex.inside(cell,int(map.radius)):
				painting = event.button_index == MOUSE_BUTTON_LEFT
				last_painted = cell
				cell_clicked.emit(cell,event.button_index)
		accept_event()

func polygon(at: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0*i-30.0)
		points.append(at + Vector2(cos(angle),sin(angle))*radius)
	return points

func text_at(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font = get_theme_default_font()
	var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,at-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	if map.is_empty():
		return
	var hs = hex_size()
	terrain_layer.position = center()
	terrain_layer.scale = Vector2.ONE*hs/56.0
	var overlay_cells: Array = cached_cells
	if tile_atlas != null and not show_coordinates:
		var keys = invalid_cells.duplicate()
		keys.merge(threat_cells)
		keys.merge(reachable)
		keys.merge(target_cells)
		if show_spawns: keys.merge(map.spawnPoints)
		if Hex.inside(hovered,map.radius): keys[Hex.key(hovered)] = true
		overlay_cells = []
		for key in keys: overlay_cells.append(Hex.cell(key))
	for cell in overlay_cells:
		var key = Hex.key(cell)
		var terrain = map.terrains.get(key,"PLAIN")
		var at = position_of(cell)
		if not Rect2(Vector2(-hs,-hs*2),size+Vector2(hs*2,hs*4)).has_point(at): continue
		var has_overlay = invalid_cells.has(key) or threat_cells.has(key) or reachable.has(key) or target_cells.has(key) or cell==hovered
		var points = polygon(at,hs-1.5) if has_overlay else PackedVector2Array()
		if tile_atlas == null:
			draw_colored_polygon(polygon(at,hs-1.5),COLORS.get(terrain,COLORS.PLAIN))
		var outline = PackedVector2Array(points)
		if has_overlay: outline.append(points[0])
		if invalid_cells.has(key):
			draw_colored_polygon(points,Color(1,0.1,0.15,0.45))
			text_at(at+Vector2(0,-hs*0.5),"!",20,Color.WHITE)
		if threat_cells.has(key):
			draw_colored_polygon(points,Color(0.8,0.22,0.55,0.13))
			draw_polyline(outline,Color("#b16b96"),1.2,true)
			# Small corner mark keeps danger distinct from attack-target fill.
			draw_circle(at+Vector2(0,-hs*0.70),2.0,Color("#e299c5"))
		if reachable.has(key):
			draw_colored_polygon(points,Color(0.22,0.65,0.72,0.18))
			draw_polyline(outline,Color("#4b9eae"),1.5,true)
		if target_cells.has(key):
			draw_colored_polygon(points,Color(0.9,0.29,0.28,0.20))
			draw_polyline(outline,Color("#dd7370"),1.5,true)
		if cell == hovered:
			draw_polyline(outline,Color("#e8cf95"),2.0,true)
		if show_coordinates:
			text_at(at+Vector2(0,4),key,maxi(10,int(hs*0.22)),Color("#b1bdc9"))
		elif false:
			text_at(at+Vector2(0,4),LABELS[terrain],maxi(13,int(hs*0.3)),Color(0.8,0.88,0.9,0.45))
		if show_spawns and map.spawnPoints.has(key):
			var player = map.spawnPoints[key] == "PLAYER"
			text_at(at+Vector2(0,hs*0.58),"我方" if player else "敵方",12,Color("#8bd6f3") if player else Color("#ffa7a0"))
	if path.size() > 0:
		var line = PackedVector2Array()
		var selected = units.filter(func(u): return u.id == selected_id)
		if not selected.is_empty():
			line.append(position_of(selected[0].cell))
		for cell in path:
			line.append(position_of(cell))
		if line.size() >= 2:
			draw_polyline(line,Color("#efd18f"),3.0,true)
	for unit in units:
		draw_unit(unit,hs)
	for effect in effects:
		var at: Vector2 = position_of(effect.cell) + Vector2(0,-12-30.0*(1.0-effect.life))
		text_at(at,effect.text,22,Color(1,0.8,0.6,minf(1.0,effect.life*2.0)))

	draw_minimap()

func draw_unit(unit: Dictionary, hs: float) -> void:
	if unit.hp <= 0:
		return
	var at: Vector2 = position_of(unit.cell)
	if visual_positions.has(unit.id):
		var motion = visual_positions[unit.id]
		at = position_of(motion.from).lerp(position_of(motion.to),motion.weight)
	var radius = hs*0.37
	var player = unit.faction == "PLAYER"
	var color = Color("#257b9c") if player else Color("#a84545")
	if unit.acted:
		color = color.darkened(0.45)
	draw_circle(at+Vector2(0,6),radius+2,Color(0,0,0,0.45))
	draw_circle(at,radius,color)
	draw_arc(at,radius,0,TAU,40,Color("#8dd6ef") if player else Color("#f5aaa1"),1.8,true)
	if unit.id == inspected_id and unit.id != selected_id:
		draw_arc(at,radius+6,0,TAU,40,Color("#e299c5"),2.0,true)
	if unit.id == selected_id:
		draw_arc(at,radius+5,0,TAU,40,Color("#f4d58b"),2.5,true)
	var white = Color("#f4f2e9")
	var length = radius*0.48
	if unit.job == "swordsman":
		draw_line(at+Vector2(-length,-length),at+Vector2(length,length),white,2.4,true)
		draw_line(at+Vector2(length,-length),at+Vector2(-length,length),white,2.4,true)
	else:
		draw_arc(at+Vector2(length*0.3,0),length,PI*0.55,PI*1.45,20,white,2.0,true)
		draw_line(at+Vector2(0,-length),at+Vector2(0,length),white,1.0,true)
		draw_line(at-Vector2(length,0),at+Vector2(length,0),white,2.0,true)
	var width = hs*0.8
	var base = at+Vector2(-width/2,radius+7)
	draw_rect(Rect2(base,Vector2(width,4)),Color("#16202c"))
	draw_rect(Rect2(base,Vector2(width*float(unit.hp)/unit.max_hp,4)),Color("#74c795"))
	draw_rect(Rect2(base+Vector2(0,6),Vector2(width,3)),Color("#16202c"))
	draw_rect(Rect2(base+Vector2(0,6),Vector2(width*float(unit.mp)/maxi(1,unit.max_mp),3)),Color("#6cb6dd"))
	text_at(at+Vector2(0,-radius-7),unit.name,clampi(int(hs*0.25),11,15),Color("#e2e8ee"))
	if unit.acted:
		text_at(at+Vector2(radius,0),"✓",13,Color("#e2e8ee"))

func add_damage(cell: Vector3i, damage: int) -> void:
	effects.append({"cell":cell,"text":"−%d" % damage,"life":1.0})
	queue_redraw()

func draw_minimap() -> void:
	var rect = minimap_rect()
	draw_style_box(get_theme_stylebox("panel","Panel"),rect)
	draw_rect(rect,Color(0.08,0.13,0.13,0.94))
	var scale_value = minimap_scale()
	if minimap_dirty or minimap_texture == null:
		var bitmap = Image.create(160,140,false,Image.FORMAT_RGBA8)
		for c in cached_cells:
			var at = Vector2(80,70)+Hex.to_pixel(c,scale_value)
			var radius = maxi(1,int(ceil(scale_value)))
			var color: Color = COLORS.get(map.terrains.get(Hex.key(c),"PLAIN"),COLORS.PLAIN)
			for y in range(maxi(0,int(at.y)-radius),mini(140,int(at.y)+radius+1)):
				for x in range(maxi(0,int(at.x)-radius),mini(160,int(at.x)+radius+1)):
					bitmap.set_pixel(x,y,color)
		minimap_texture = ImageTexture.create_from_image(bitmap)
		minimap_dirty = false
	draw_texture_rect(minimap_texture,rect,false)
	for key in map.spawnPoints:
		draw_circle(rect.get_center()+Hex.to_pixel(Hex.cell(key),scale_value),2.0,Color.CYAN if map.spawnPoints[key]=="PLAYER" else Color.SALMON)
	for unit in units:
		if unit.hp>0: draw_circle(rect.get_center()+Hex.to_pixel(unit.cell,scale_value),2.5,Color.CYAN if unit.faction=="PLAYER" else Color.SALMON)
	var factor = scale_value/hex_size()
	var view = Rect2(rect.get_center()-pan_offset*factor-size*0.5*factor,size*factor).intersection(rect)
	draw_rect(view,Color("#f2dc9d"),false,1.5)
	draw_rect(rect,Color("#ad9b72"),false,1.0)

func _process(delta: float) -> void:
	if map.is_empty(): return
	var changed = false
	if not camera_locked or automatic_focus:
		var mouse = get_local_mouse_position()
		if not camera_locked and edge_scroll_enabled and not painting and not dragging and not minimap_dragging and Rect2(Vector2.ZERO,size).has_point(mouse) and not minimap_rect().has_point(mouse) and get_viewport().gui_get_hovered_control()==self:
			var direction = Vector2.ZERO
			if mouse.x<18: direction.x=1
			elif mouse.x>size.x-18: direction.x=-1
			if mouse.y<18: direction.y=1
			elif mouse.y>size.y-18: direction.y=-1
			camera_target += direction*480.0*delta
		camera_target = camera_target.clamp(-camera_limit(),camera_limit())
		if absf(zoom-zoom_target)>0.0001:
			var old_zoom = zoom
			zoom = lerpf(zoom,zoom_target,1.0-exp(-14.0*delta))
			pan_offset *= zoom/old_zoom
			camera_target *= zoom/old_zoom
			changed = true
		if pan_offset != camera_target:
			pan_offset = pan_offset.lerp(camera_target,1.0-exp(-14.0*delta))
			if pan_offset.distance_to(camera_target)<0.1:
				pan_offset = camera_target
				automatic_focus = false
			changed = true
	if not effects.is_empty():
		for effect in effects: effect.life -= delta
		effects = effects.filter(func(e): return e.life > 0)
		changed = true
	if changed: queue_redraw()

func bake_terrain_atlas() -> void:
	if terrain_texture.get_image()==null: await terrain_texture.changed
	var viewport = SubViewport.new()
	viewport.size = Vector2i(768,144)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter = preload("res://ui/terrain_atlas.gd").new()
	painter.texture = terrain_texture
	viewport.add_child(painter)
	add_child(viewport)
	await RenderingServer.frame_post_draw
	var bitmap = viewport.get_texture().get_image()
	if bitmap != null:
		tile_atlas = ImageTexture.create_from_image(bitmap)
		terrain_layer.atlas = tile_atlas
		terrain_layer.queue_redraw()
	viewport.queue_free()
	queue_redraw()

func invalidate_terrain() -> void:
	minimap_dirty = true
	if terrain_layer != null:
		terrain_layer.map = map
		terrain_layer.queue_redraw()
