extends Control
const Hex = preload("res://core/hex_rules.gd")
const Catalog = preload("res://core/catalog.gd")
signal cell_clicked(cell: Vector3i, button: int)
signal cell_hovered(cell: Vector3i)
var map: Dictionary = {}
var units: Array = []
var selected_id = ""
var reachable: Dictionary = {}
var target_cells: Dictionary = {}
var path: Array = []
var visual_positions: Dictionary = {}
var hovered = Vector3i(999,999,999)
var show_spawns = false
var show_coordinates = false
var zoom = 1.0
var effects: Array = []
const COLORS = {"PLAIN":Color("#263348"),"FOREST":Color("#295344"),"SWAMP":Color("#505638"),
	"HILLS":Color("#75614c"),"MOUNTAIN":Color("#414956"),"WATER":Color("#174963")}
const LABELS = {"PLAIN":"", "FOREST":"森", "SWAMP":"沼", "HILLS":"丘", "MOUNTAIN":"山", "WATER":"水"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)

func hex_size() -> float:
	var radius = int(map.get("radius",4))
	return minf(size.x / (sqrt(3.0)*(2*radius+1)+1), size.y/(3*radius+4)) * zoom

func center() -> Vector2:
	return size * Vector2(0.5,0.49)

func position_of(cell: Vector3i) -> Vector2:
	return center() + Hex.to_pixel(cell,hex_size())

func _gui_input(event: InputEvent) -> void:
	if map.is_empty():
		return
	if event is InputEventMouseMotion:
		var cell = Hex.from_pixel(event.position-center(),hex_size())
		if cell != hovered:
			hovered = cell
			cell_hovered.emit(cell)
			queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(1.5,zoom+0.1)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(0.65,zoom-0.1)
			queue_redraw()
		else:
			var cell = Hex.from_pixel(event.position-center(),hex_size())
			if Hex.inside(cell,int(map.radius)):
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
	draw_rect(Rect2(Vector2.ZERO,size),Color("#0b111b"))
	if map.is_empty():
		return
	var hs = hex_size()
	var cells = Hex.cells(int(map.radius))
	cells.sort_custom(func(a,b): return a.z < b.z if a.z != b.z else a.x < b.x)
	for cell in cells:
		var key = Hex.key(cell)
		var terrain = map.terrains.get(key,"PLAIN")
		var at = position_of(cell)
		var points = polygon(at,hs-1.5)
		var depth = 5.0
		if terrain == "HILLS": depth = 9.0
		if terrain == "MOUNTAIN": depth = 13.0
		if terrain == "WATER": depth = 2.0
		draw_colored_polygon(polygon(at+Vector2(0,depth),hs-1.5),Color("#05090f"))
		var color: Color = COLORS.get(terrain,COLORS.PLAIN)
		draw_colored_polygon(points,color)
		var outline = PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline,color.lightened(0.15),1.0,true)
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
		elif not str(LABELS.get(terrain,"")).is_empty():
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
		var at: Vector2 = effect.position + Vector2(0,-30.0*(1.0-effect.life))
		text_at(at,effect.text,22,Color(1,0.8,0.6,minf(1.0,effect.life*2.0)))

func draw_unit(unit: Dictionary, hs: float) -> void:
	if unit.hp <= 0:
		return
	var at: Vector2 = visual_positions.get(unit.id,position_of(unit.cell))
	var radius = hs*0.37
	var player = unit.faction == "PLAYER"
	var color = Color("#257b9c") if player else Color("#a84545")
	if unit.acted:
		color = color.darkened(0.45)
	draw_circle(at+Vector2(0,6),radius+2,Color(0,0,0,0.45))
	draw_circle(at,radius,color)
	draw_arc(at,radius,0,TAU,40,Color("#8dd6ef") if player else Color("#f5aaa1"),1.8,true)
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
	effects.append({"position":position_of(cell)+Vector2(0,-12),"text":"−%d" % damage,"life":1.0})
	queue_redraw()

func _process(delta: float) -> void:
	if effects.is_empty():
		return
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(e): return e.life > 0)
	queue_redraw()
