extends SceneTree
const Hex = preload("res://core/hex_rules.gd")
const Rules = preload("res://core/battle_rules.gd")
const Catalog = preload("res://core/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var map = {"radius":4,"terrains":{},"spawnPoints":{}}
	var enemy = Catalog.enemy("enemy_archer_base",0,Vector3i.ZERO)
	enemy.movement = 0
	var attack = Catalog.action(enemy)
	var threat = Rules.threat_cells(map,enemy,[enemy],attack)
	check(not threat.has("0,0,0"),"stationary archer cannot hit own cell")
	check(not threat.has("1,-1,0"),"stationary archer has minimum range")
	check(threat.has("2,-2,0"),"archer range two included")
	check(threat.has("3,-3,0"),"archer range three included")
	check(not threat.has("4,-4,0"),"archer outside range excluded")
	enemy.movement = 2
	threat = Rules.threat_cells(map,enemy,[enemy],attack)
	check(threat.has("4,-4,0"),"movement extends threat")
	for direction in Hex.DIRECTIONS:
		map.terrains[Hex.key(direction)] = "MOUNTAIN"
	threat = Rules.threat_cells(map,enemy,[enemy],attack)
	check(not threat.has("4,-4,0"),"blocked paths do not extend threat")
	check(threat.has("2,-2,0"),"existing rules allow attacks across mountains")
	enemy.acted = true
	check(threat == Rules.threat_cells(map,enemy,[enemy],attack),"forecast next activation ignores current acted flag")
	enemy.hp = 0
	check(Rules.threat_cells(map,enemy,[enemy],attack).is_empty(),"dead enemy no threat")
	var attacker = Catalog.player("player_archer_01",Vector3i.ZERO)
	var defender = Catalog.enemy("enemy_swordsman_base",0,Vector3i(1,-1,0))
	check(Rules.attack_error(attacker,defender,Catalog.action(attacker)).contains("太近"),"minimum range reason")
	defender.cell = Vector3i(4,-4,0)
	check(Rules.attack_error(attacker,defender,Catalog.action(attacker)).contains("太遠"),"maximum range reason")
	attacker.mp = 14
	check(Rules.attack_error(attacker,defender,Catalog.action(attacker,true)).contains("MP 不足"),"skill MP reason")
	attacker.mp = 15
	check(Rules.attack_error(attacker,defender,Catalog.action(attacker,true)).is_empty(),"skill valid at exact MP threshold")
	defender.faction = "PLAYER"
	check(Rules.attack_error(attacker,defender,Catalog.action(attacker)).contains("友軍"),"friendly fire reason")
	check(Rules.attack_error(attacker,{},Catalog.action(attacker)).contains("選擇敵方"),"empty target reason")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.combat_cinematics = false
	await process_frame
	app.level.mapId = "map_tutorial"
	app.begin_deployment(app.level)
	app.battle.auto_deploy()
	app.start_battle()
	var foe = app.battle.units.filter(func(u): return u.faction == "ENEMY")[0]
	var original = app.battle.units.duplicate(true)
	app.on_cell_clicked(foe.cell,MOUSE_BUTTON_LEFT)
	check(app.inspected_id == foe.id,"enemy can be inspected")
	check(app.selection.is_empty() and not app.radial_actions.visible,"inspection cannot issue player commands")
	check(not app.board.threat_cells.is_empty(),"inspection displays threat")
	check(original == app.battle.units,"inspection does not alter battle")
	app.cancel_selection()
	check(app.inspected_id.is_empty() and app.board.threat_cells.is_empty(),"cancel clears inspection and threat")
	app.show_all_threats = true
	app.sync_board()
	check(not app.board.threat_cells.is_empty(),"global threats can be enabled")
	app.board.pan_offset = Vector2(120,-65)
	var pos = app.board.position_of(foe.cell)
	check(Hex.from_pixel(pos-app.board.center(),app.board.hex_size()) == foe.cell,"panned cell hit test remains correct")
	app.board.focus_cell(foe.cell)
	check(app.board.position_of(foe.cell).distance_to(app.board.size*Vector2(0.5,0.49)) < 0.01,"focus centers target")
	app.board.reset_camera()
	check(app.board.pan_offset == Vector2.ZERO and app.board.zoom == 1.0,"camera reset")
	app.show_menu()
	check(app.board.threat_cells.is_empty(),"leaving battle clears threat")
	app.queue_free()
	await process_frame
	print("%d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
