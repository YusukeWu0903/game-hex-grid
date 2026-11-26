extends SceneTree
const Hex=preload("res://core/hex_rules.gd")
const Rules=preload("res://core/battle_rules.gd")
const Catalog=preload("res://core/catalog.gd")
func _initialize() -> void:
	var map={"radius":12,"terrains":{},"spawnPoints":{}}
	var actor=Catalog.enemy("enemy_swordsman_base",0,Vector3i(-12,12,0))
	var units=[actor,Catalog.player("player_swordsman_01",Vector3i(12,-12,0)),
		Catalog.player("player_swordsman_02",Vector3i(11,-12,1)),
		Catalog.player("player_archer_01",Vector3i(12,-11,-1))]
	var times=[]
	for i in range(30):
		var start=Time.get_ticks_usec()
		Rules.plan_ai(map,actor,units,Catalog.action(actor))
		times.append(Time.get_ticks_usec()-start)
	times.sort()
	print("AI_PROFILE radius12 cells469 targets3: min=%d median=%d max=%d us" % [times[0],times[15],times[-1]])
	quit()
