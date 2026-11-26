extends Node2D
const Hex = preload("res://core/hex_rules.gd")
const TYPES = ["PLAIN","FOREST","SWAMP","HILLS","MOUNTAIN","WATER"]
var map: Dictionary = {}
var cells: Array = []
var atlas: Texture2D
func _draw() -> void:
	if atlas==null: return
	for cell in cells:
		var index = TYPES.find(map.terrains.get(Hex.key(cell),"PLAIN"))
		var at = Hex.to_pixel(cell,56.0)
		draw_texture_rect_region(atlas,Rect2(at-Vector2(64,72),Vector2(128,144)),Rect2(Vector2(index*128,0),Vector2(128,144)))
