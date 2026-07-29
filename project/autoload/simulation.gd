## Simulation.gd — game mechanics + _process() loop
## NO class_name, NO @onready, NO gui_input
extends Node

var current_district: String = ""
var current_level_num: int = 0
var grid_size: int = 8
var map_tiles: Array = []
var player_pos: Vector2i = Vector2i(2, 2)
var opponents: Array = []
var player_pumps: int = 2
var player_fuel_capacity: int = 5000
var fuel_price: float = 50.0
var fuel_stored: int = 5000
var revenue: int = 0
var fuel_sold: int = 0
var game_time: float = 8.0
var sales_timer: float = 0.0
var ai_timer: float = 0.0
var cost_timer: float = 0.0
var level_start_cash: int = 0
var level_start_real_time: float = 0.0
var in_game: bool = false
var buyout_confirm_id: int = -1
var wholesale_price: float = 42.5

const SALES_INTERVAL: float = 2.5
const AI_INTERVAL: float = 12.0
const COST_INTERVAL: float = 60.0
const BASE_SALES: float = 8.0
const WHOLESALE_BASE: float = 42.5
const DAILY_COST_PER_STATION: int = 800
const BANKRUPTCY_THRESHOLD: int = -10000
const BASE_BUYOUT: int = 60000
const MIN_PRICE: float = 35.0
const MAX_PRICE: float = 85.0

func start_level(d_id: String, num: int, boot: Control) -> void:
	var gs = get_node_or_null("/root/GameState")
	var ui = get_node_or_null("/root/UIRenderer")
	
	gs.apply_upgrades()
	grid_size = gs.district_grid_sizes.get(d_id, 8)
	fuel_price = 50.0
	fuel_stored = gs.player_fuel_capacity
	player_pumps = gs.player_pumps
	revenue = 0
	fuel_sold = 0
	game_time = 8.0
	sales_timer = 0.0
	cost_timer = 0.0
	ai_timer = 0.0
	level_start_cash = gs.cash
	level_start_real_time = Time.get_unix_time_from_system()
	buyout_confirm_id = -1
	in_game = true
	current_district = d_id
	current_level_num = num
	
	_generate_map(d_id, num)
	
	if ui != null and ui.has_method("show_gameplay"):
		ui.show_gameplay(boot)

func stop_level() -> void:
	in_game = false

func _process(delta: float) -> void:
	if not in_game:
		return
	
	var gs = get_node_or_null("/root/GameState")
	var ui = get_node_or_null("/root/UIRenderer")
	
	sales_timer += delta
	if sales_timer >= SALES_INTERVAL:
		sales_timer = 0.0
		_simulate_sales_tick(gs, ui)
	
	ai_timer += delta
	if ai_timer >= AI_INTERVAL:
		ai_timer = 0.0
		_simulate_opponent_ai(ui)
	
	cost_timer += delta
	if cost_timer >= COST_INTERVAL:
		cost_timer = 0.0
		_deduct_daily_costs(gs, ui)
	
	if gs != null and gs.auto_order_active and fuel_stored < int(gs.player_fuel_capacity * 0.3):
		var amount = min(gs.player_fuel_capacity - fuel_stored, 3000)
		var cost = int(amount * wholesale_price)
		if gs.cash >= cost and amount > 0:
			gs.cash -= cost
			fuel_stored += amount
			if ui != null and ui.lbl_msg != null:
				ui.lbl_msg.text = "Автозаказ: +" + str(amount) + "L за " + str(cost) + "R"
	
	_check_bankruptcy(gs, ui)

func _demand_at_hour(hour: int) -> float:
	var base = 0.35
	if hour >= 7 and hour <= 9:
		base += 0.45
	if hour >= 12 and hour <= 14:
		base += 0.35
	if hour >= 17 and hour <= 19:
		base += 0.50
	if hour >= 22 or hour <= 5:
		base = 0.15
	return base

func _simulate_sales_tick(gs: Node, ui: Node) -> void:
	game_time += 1.0
	var hour = int(game_time % 24)
	var demand = _demand_at_hour(hour)
	
	var gs_node = gs
	var traffic = gs_node.district_traffic.get(current_district, 60) / 100.0
	
	var opp_avg = _get_avg_opponent_price()
	var price_factor = 1.0
	if opp_avg > 0:
		price_factor = opp_avg / max(fuel_price, MIN_PRICE)
		price_factor = clamp(price_factor, 0.3, 2.5)
	
	var base_sales = BASE_SALES * demand * traffic * price_factor * gs_node.marketing_factor * float(player_pumps) * gs_node.speed_factor
	var actual = min(int(base_sales), fuel_stored)
	
	if actual > 0:
		fuel_stored -= actual
		var income = int(actual * fuel_price)
		gs_node.cash += income
		revenue += income
		fuel_sold += actual
		
		var msg = ""
		if hour >= 7 and hour <= 9:
			msg = "Утренний пик! +" + str(actual) + "L -> " + str(income) + "R"
		elif hour >= 12 and hour <= 14:
			msg = "Обеденный пик! +" + str(actual) + "L -> " + str(income) + "R"
		elif hour >= 17 and hour <= 19:
			msg = "Вечерний пик! +" + str(actual) + "L -> " + str(income) + "R"
		elif hour >= 22 or hour <= 5:
			msg = "Ночь... +" + str(actual) + "L -> " + str(income) + "R"
		else:
			msg = "Продано " + str(actual) + "L -> " + str(income) + "R"
		
		if ui != null and ui.lbl_msg != null:
			ui.lbl_msg.text = msg
	else:
		if fuel_stored <= 0:
			if ui != null and ui.lbl_msg != null:
				ui.lbl_msg.text = "[!] Топливо закончилось! Закупите!"
	
	if ui != null and ui.has_method("update_gameplay_ui"):
		ui.update_gameplay_ui()

func _get_avg_opponent_price() -> float:
	if opponents.is_empty():
		return WHOLESALE_BASE * 1.2
	var sum = 0.0
	var count = 0
	for opp in opponents:
		if opp.stations_count > 0:
			sum += opp.price
			count += 1
	if count == 0:
		return WHOLESALE_BASE * 1.2
	return sum / count

func _simulate_opponent_ai(ui: Node) -> void:
	for opp in opponents:
		if opp.stations_count <= 0:
			continue
		
		var should_change = randf() < opp.change_freq
		if not should_change:
			continue
		
		var new_price = opp.price
		var player_diff = fuel_price - opp.price
		
		if opp.archetype == "shark":
			if player_diff > 3:
				new_price = max(fuel_price - 3, WHOLESALE_BASE * (1.0 + opp.margin))
			elif player_diff < -3:
				new_price = fuel_price + 2
			else:
				new_price += (randf() - 0.6) * 3
		elif opp.archetype == "miser":
			new_price += (randf() - 0.3) * 1.5
		elif opp.archetype == "opportunist":
			if abs(player_diff) > 2:
				new_price = fuel_price + (randf() - 0.5) * 2
			else:
				new_price += (randf() - 0.5) * 1.5
		elif opp.archetype == "tycoon":
			new_price = (opp.price + fuel_price * 0.5 + WHOLESALE_BASE * 1.2) / 2.7 + (randf() - 0.5) * 2
		elif opp.archetype == "local":
			new_price += (randf() - 0.4) * 1.0
		elif opp.archetype == "green":
			new_price += randf() * 1.5
		
		var old_price = opp.price
		new_price = clamp(new_price, WHOLESALE_BASE * (1.0 + opp.margin), MAX_PRICE)
		opp.price = new_price
		
		var action = ""
		if new_price < old_price - 0.5:
			action = opp.name + " снизил цену до " + str(int(new_price)) + "R!"
		elif new_price > old_price + 0.5:
			action = opp.name + " повысил цену до " + str(int(new_price)) + "R!"
		else:
			action = opp.name + " держит цену " + str(int(new_price)) + "R"
		
		if ui != null and ui.lbl_opp_msg != null:
			ui.lbl_opp_msg.text = action
	
	if ui != null and ui.has_method("update_gameplay_ui"):
		ui.update_gameplay_ui()

func _deduct_daily_costs(gs: Node, ui: Node) -> void:
	var player_station_count = 1
	for opp in opponents:
		if opp.stations_count <= 0:
			player_station_count += 1
	
	var total_cost = DAILY_COST_PER_STATION * player_station_count
	gs.cash -= total_cost
	
	if ui != null and ui.lbl_msg != null:
		ui.lbl_msg.text = "Дневные расходы: -" + str(total_cost) + "R (" + str(player_station_count) + " запр.)"
	
	if ui != null and ui.has_method("update_gameplay_ui"):
		ui.update_gameplay_ui()

func check_win() -> void:
	var remaining = 0
	for opp in opponents:
		if opp.stations_count > 0:
			remaining += 1
	
	if remaining == 0:
		in_game = false
		var gs = get_node_or_null("/root/GameState")
		var ui = get_node_or_null("/root/UIRenderer")
		
		var stars = 3
		var elapsed = Time.get_unix_time_from_system() - level_start_real_time
		if elapsed < 300:
			stars += 1
		if gs.cash > level_start_cash * 2:
			stars += 1
		
		var level_key = current_district + "_" + str(current_level_num)
		var prev_stars = gs.completed_levels.get(level_key, 0)
		var new_stars = max(prev_stars, stars)
		var gained = new_stars - prev_stars
		gs.total_stars += gained
		gs.completed_levels[level_key] = new_stars
		
		_check_district_unlock(gs)
		gs.save_game()
		
		if ui != null and ui.has_method("show_result"):
			ui.show_result(true, stars, gained)

func _check_district_unlock(gs: Node) -> void:
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	for i in range(order.size() - 1):
		var d_id = order[i]
		var next_id = order[i + 1]
		if gs.is_district_unlocked(d_id) and not gs.is_district_unlocked(next_id):
			var req = gs.district_req_stars.get(next_id, 999)
			if gs.total_stars >= req:
				var all_done = true
				var lvls = gs.district_levels_count.get(d_id, 4)
				for j in range(1, lvls + 1):
					if not gs.completed_levels.has(d_id + "_" + str(j)) or gs.completed_levels[d_id + "_" + str(j)] == 0:
						all_done = false
						break
				if all_done:
					gs.unlocked_districts.append(StringName(next_id))

func _check_bankruptcy(gs: Node, ui: Node) -> void:
	if gs.cash < BANKRUPTCY_THRESHOLD:
		in_game = false
		if ui != null and ui.has_method("show_result"):
			ui.show_result(false, 0, 0)

func calc_buyout(opp: Dictionary) -> int:
	var base = BASE_BUYOUT + current_level_num * 15000
	var gs = get_node_or_null("/root/GameState")
	var price = int(base * opp.loyalty * gs.negotiation_factor)
	return price

func find_opponent(opp_id: int):
	for opp in opponents:
		if opp.id == opp_id:
			return opp
	return null

func _generate_map(d_id: String, level_num: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = level_num * 12345 + d_id.hash()
	map_tiles = []
	opponents = []
	
	for y in range(grid_size):
		var row = []
		for x in range(grid_size):
			row.append(0)
		map_tiles.append(row)
	
	var h_count = 2
	if level_num > 2:
		h_count = 3
	var v_count = 2
	if level_num > 3:
		v_count = 3
	for i in range(h_count):
		var ry = rng.randi_range(1, grid_size - 2)
		for x in range(grid_size):
			map_tiles[ry][x] = 1
	for i in range(v_count):
		var rx = rng.randi_range(1, grid_size - 2)
		for y in range(grid_size):
			map_tiles[y][rx] = 1
	
	for y in range(grid_size):
		for x in range(grid_size):
			if map_tiles[y][x] == 0:
				var near = false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var ny = y + dy
						var nx = x + dx
						if ny >= 0 and ny < grid_size and nx >= 0 and nx < grid_size and map_tiles[ny][nx] == 1:
							near = true
				if near and rng.randf() < 0.55:
					map_tiles[y][x] = 2
	
	player_pos = Vector2i(grid_size / 2, grid_size / 2)
	for y in range(grid_size):
		for x in range(grid_size):
			if map_tiles[y][x] == 1 and abs(x - grid_size / 2) <= 2 and abs(y - grid_size / 2) <= 2:
				player_pos = Vector2i(x, y)
				break
	map_tiles[player_pos.y][player_pos.x] = 5
	
	var opp_count = min(level_num, 3)
	var archetype_pool = _get_archetypes_for_district(d_id)
	
	for i in range(opp_count):
		var archetype = archetype_pool[rng.randi_range(0, archetype_pool.size() - 1)]
		var arch_data = _get_archetype_data(archetype)
		for attempt in range(30):
			var ox = rng.randi_range(1, grid_size - 2)
			var oy = rng.randi_range(1, grid_size - 2)
			if map_tiles[oy][ox] == 1 and (abs(ox - player_pos.x) + abs(oy - player_pos.y)) >= 3:
				map_tiles[oy][ox] = 6
				var opp = {
					"id": i,
					"archetype": archetype,
					"name": arch_data.name,
					"pos": Vector2i(ox, oy),
					"price": WHOLESALE_BASE * (1.0 + arch_data.margin) * arch_data.price_mod,
					"cash": 30000 + level_num * 10000,
					"loyalty": arch_data.loyalty,
					"stations_count": 1,
					"color": arch_data.color,
					"msg": arch_data.msg,
					"aggression": arch_data.aggression,
					"price_mod": arch_data.price_mod,
					"margin": arch_data.margin,
					"change_freq": arch_data.change_freq,
				}
				opponents.append(opp)
				break

func _get_archetypes_for_district(d_id: String) -> Array:
	var mapping = {
		"business_center": ["shark", "opportunist", "miser"],
		"historic": ["miser", "local", "opportunist"],
		"residential": ["miser", "local"],
		"industrial": ["shark", "tycoon", "opportunist"],
		"waterfront": ["local", "green", "opportunist"],
		"suburban": ["local", "miser"],
		"port": ["shark", "tycoon", "local"],
		"airport": ["tycoon", "green", "opportunist"],
		"university": ["miser", "green", "opportunist"],
		"tourist": ["local", "opportunist", "shark"],
	}
	return mapping.get(d_id, ["opportunist"])

func _get_archetype_data(arch: String) -> Dictionary:
	var data = {
		"shark": {"name": "Акула", "color": Color(0.9, 0.2, 0.2), "loyalty": 0.7, "aggression": 1.8, "price_mod": 0.9, "margin": 0.12, "change_freq": 0.8, "msg": "Твой бизнес горит!"},
		"miser": {"name": "Скупой", "color": Color(0.9, 0.75, 0.2), "loyalty": 1.8, "aggression": 0.4, "price_mod": 1.15, "margin": 0.25, "change_freq": 0.2, "msg": "Каждая копейка на счету."},
		"opportunist": {"name": "Опортунист", "color": Color(0.4, 0.4, 0.9), "loyalty": 1.0, "aggression": 1.0, "price_mod": 1.0, "margin": 0.15, "change_freq": 0.6, "msg": "Хороший ход. Повторю."},
		"tycoon": {"name": "Магнат", "color": Color(0.7, 0.3, 0.9), "loyalty": 1.5, "aggression": 1.2, "price_mod": 0.95, "margin": 0.15, "change_freq": 0.4, "msg": "Деньги решают всё."},
		"local": {"name": "Местный", "color": Color(0.2, 0.7, 0.9), "loyalty": 2.0, "aggression": 0.8, "price_mod": 1.05, "margin": 0.18, "change_freq": 0.3, "msg": "Здесь я хозяин."},
		"green": {"name": "Эколог", "color": Color(0.3, 0.85, 0.4), "loyalty": 1.3, "aggression": 0.6, "price_mod": 1.25, "margin": 0.30, "change_freq": 0.25, "msg": "Будущее за чистой энергией."},
	}
	return data.get(arch, data["opportunist"])
