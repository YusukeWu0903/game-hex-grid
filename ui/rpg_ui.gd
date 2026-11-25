extends RefCounted
const Catalog = preload("res://core/catalog.gd")
const Hex = preload("res://core/hex_rules.gd")
static func battle_controls(app) -> void:
	var unit = app.selected_unit()
	if not unit.is_empty(): app.label("物防 %d · 魔防 %d · 盾牆 +%d" % [unit.defense,unit.resistance,unit.guard],14)
	if app.action_mode=="ITEM" and not app.selection.is_empty():
		app.label("選道具，再點自己或相鄰友軍",14)
		for id in Catalog.data().items:
			if int(app.battle.inventory.get(id,0))>0:
				app.button("%s ×%d" % [Catalog.item_name(id),app.battle.inventory[id]],func():
					app.selected_item = id
					app.notice("%s：點選自己或相鄰友軍。" % Catalog.item_name(id)))

static func add_rewind(app) -> void:
	if app.battle.history.is_empty() or app.battle.settled: return
	var picker = OptionButton.new()
	for state in app.battle.history: picker.add_item("第 %d 回合開始" % int(state.turn),int(state.turn))
	picker.select(app.battle.history.size()-1)
	picker.disabled = app.busy or app.battle.phase=="ENEMY"
	app.sidebar.add_child(picker)
	app.button("回溯到選定回合",func():
		var target = picker.get_selected_id()
		app.confirm("回到第 %d 回合開始？其後行動與掉落將還原。" % target,func(): app.rewind_battle(target)),app.busy or app.battle.phase=="ENEMY")

static func sync_targets(app) -> void:
	if app.mode!="BATTLE" or not app.battle.can_control(app.selection): return
	var actor = app.selected_unit()
	if app.action_mode=="CHEST":
		for key in app.battle.map.get("chests",{}):
			if not app.battle.opened_chests.has(key) and Hex.distance(actor.cell,Hex.cell(key))<=1: app.board.target_cells[key]=true
	elif app.action_mode=="ITEM":
		for unit in app.battle.units:
			if unit.faction=="PLAYER" and Hex.distance(actor.cell,unit.cell)<=1: app.board.target_cells[Hex.key(unit.cell)]=true

static func result_controls(app) -> void:
	app.label("戰利品已正式入庫。" if app.battle.settled else "戰利品尚未入庫；敗北可回溯。",14)
	for id in app.battle.pending_loot:
		if int(app.battle.pending_loot[id])>0: app.label("%s ×%d" % [Catalog.item_name(id),app.battle.pending_loot[id]],14)
	if app.battle.result=="VICTORY" and not app.battle.settled:
		app.button("重試保存結算",func():
			var failure = app.party.claim(app.battle)
			app.battle_ui()
			if not failure.is_empty(): app.notice(failure))
	if not app.battle.settled: add_rewind(app)

static func show_party(app) -> void:
	app.invalidate_animation()
	app.mode = "PARTY"
	app.clear_sidebar()
	app.label("隊伍與裝備",22)
	for row in Catalog.roster():
		app.button(row.name+" · "+Catalog.data().jobs[row.job].name,func():
			app.party_selected = row.id
			show_party(app))
	var unit = Catalog.player(app.party_selected,Vector3i.ZERO)
	Catalog.equip_unit(unit,app.party.loadouts.get(app.party_selected,{}))
	app.label(unit.name,20)
	app.label("HP %d · MP %d\n攻擊 +%d · 魔攻 +%d\n物防 %d · 魔防 %d" % [unit.max_hp,unit.max_mp,unit.attack_bonus,unit.magic_bonus,unit.defense,unit.resistance])
	for slot in ["weapon","armor","accessory"]:
		app.label({"weapon":"武器","armor":"防具","accessory":"飾品"}[slot])
		var picker = OptionButton.new()
		var ids = [""]
		picker.add_item("不裝備")
		for id in Catalog.data().equipment:
			var gear = Catalog.data().equipment[id]
			if gear.slot==slot and gear.jobs.has(unit.job) and int(app.party.inventory.get(id,0))>0:
				ids.append(id)
				picker.add_item("%s ×%d" % [gear.name,app.party.inventory[id]])
				picker.set_item_tooltip(ids.size()-1,"攻+%d 魔+%d 防+%d 抗+%d HP+%d MP+%d" % [gear.attack,gear.magic,gear.defense,gear.resistance,gear.hp,gear.mp])
		picker.select(maxi(0,ids.find(app.party.loadouts.get(app.party_selected,{}).get(slot,""))))
		picker.item_selected.connect(func(index):
			var failure = app.party.equip(app.party_selected,slot,ids[index])
			show_party(app)
			if not failure.is_empty(): app.notice(failure))
		app.sidebar.add_child(picker)
	app.label("隊伍背包",18)
	for id in app.party.inventory:
		if int(app.party.inventory[id])>0: app.label("%s ×%d" % [Catalog.item_name(id),app.party.inventory[id]],14)
	app.button("返回選單",app.show_menu)
	app.state_label.text = "戰前整備"
	app.context_label.text = "裝備持有數量包含已穿戴的份數"
	app.detail_label.text = "選擇後自動保存；不得超量分配。滑鼠停留選項查看加成。"
	app.notice(app.party.error if not app.party.error.is_empty() else "戰前換裝；戰利品須勝利後才永久保存。")
