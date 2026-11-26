extends Node2D
var texture: Texture2D
const COLORS = {"PLAIN":Color("#82916a"),"FOREST":Color("#4e7150"),"SWAMP":Color("#75846a"),"HILLS":Color("#a79670"),"MOUNTAIN":Color("#7c827e"),"WATER":Color("#46868e")}
func _draw() -> void:
	for i in range(COLORS.size()):
		var terrain = COLORS.keys()[i]
		var at = Vector2(i*128+64,72)
		var hs = 56.0
		var points = polygon(at,hs-1.5)
		var depth = 5.0
		if terrain=="HILLS": depth=9
		elif terrain=="MOUNTAIN": depth=13
		elif terrain=="WATER": depth=2
		draw_colored_polygon(polygon(at+Vector2(0,depth),hs-1.5),Color("#253332"))
		var uv = PackedVector2Array()
		for point in points: uv.append((point-at)/hs*0.5+Vector2(0.5,0.5))
		draw_polygon(points,PackedColorArray([COLORS[terrain]]),uv,texture)
		draw_terrain(at,hs,terrain,Vector3i.ZERO)
		points.append(points[0])
		draw_polyline(points,COLORS[terrain].lightened(0.15),1.0,true)

func polygon(at: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0*i-30.0)
		points.append(at + Vector2(cos(angle),sin(angle))*radius)
	return points

func draw_terrain(at: Vector2, hs: float, terrain: String, cell: Vector3i) -> void:
	var ink = Color(0.13,0.22,0.18,0.35)
	var phase = float(posmod(cell.x*13+cell.z*7,11))/11.0
	if terrain == "FOREST":
		for offset in [Vector2(-0.28,0.05),Vector2(0.23,0.19),Vector2(0,-0.25)]:
			var p = at+offset*hs
			draw_line(p,p+Vector2(0,hs*0.27),Color("#635942"),hs*0.06,true)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-hs*0.4),p+Vector2(-hs*0.23,hs*0.17),p+Vector2(hs*0.23,hs*0.17)]),Color("#315a43"))
			draw_line(p+Vector2(0,-hs*0.33),p+Vector2(-hs*0.17,hs*0.1),Color("#8b9b62"),1.5,true)
	elif terrain == "MOUNTAIN":
		var top = at+Vector2(hs*0.08,-hs*0.6)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-hs*0.65,hs*0.32),top,at+Vector2(hs*0.65,hs*0.32)]),Color("#b9b8a1"))
		draw_colored_polygon(PackedVector2Array([top,at+Vector2(hs*0.65,hs*0.32),at+Vector2(hs*0.12,hs*0.2)]),Color("#626f6b"))
		draw_colored_polygon(PackedVector2Array([top,top+Vector2(-hs*0.19,hs*0.25),top+Vector2(hs*0.18,hs*0.25)]),Color("#e1dfcb"))
	elif terrain == "WATER":
		for i in range(3):
			var y = (i-1)*hs*0.27
			draw_polyline(PackedVector2Array([at+Vector2(-hs*0.45,y),at+Vector2(-hs*0.1,y-3),at+Vector2(hs*0.35,y)]),Color(0.7,0.87,0.82,0.5),1.3,true)
	elif terrain == "HILLS":
		draw_arc(at+Vector2(0,hs*0.25),hs*0.45,PI*1.1,PI*1.9,16,ink,2.0,true)
	else:
		for i in range(3):
			var p = at+Vector2((i-1)*hs*0.35,(phase-0.5)*hs*0.5)
			draw_line(p,p+Vector2(-2,-hs*0.13),ink,1.0,true)
			if terrain == "SWAMP": draw_line(p,p+Vector2(hs*0.18,0),Color("#b1b794"),1.0,true)

