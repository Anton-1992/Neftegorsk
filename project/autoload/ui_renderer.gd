## UIRenderer.gd — v25e: visible map, live simulation, cars
extends Node

var boot = null
var font = null
var gs = null
var sim = null
var current_district_id = ""
var current_level_num = 0
var current_screen = "main_menu"
var ui_timer = 0.0

var lbl_cash = null
var lbl_fuel = null
var lbl_price = null
var lbl_time = null
var lbl_msg = null
var lbl_opp_msg = null
var lbl_revenue = null
var lbl_fuel_sold = null
var lbl_status = null

func _get_gs():
	if gs == null:
		gs = get_node_or_null("/root/GameState")
	return gs

func _get_sim():
	if sim == null:
		sim = get_node_or_null("/root/Simulation")
	return sim

func _load_font():
	if font == null:
		font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")

func _clear():
	if boot == null:
		return
	var ch = boot.get_children()
	for c in ch:
		boot.remove_child(c)
		c.free()

func _btn(text, x, y, w, h, color, fs, cb, arg = null):
	var b = Button.new()
	b.text = text
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	if font != null:
		b.add_theme_font_override("font", font)
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s)
	if arg != null:
		b.pressed.connect(cb.bind(arg))
	else:
		b.pressed.connect(cb)
	return b

func _lbl(text, x, y, w, h, fs, color, center = true):
	var l = Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if center:
		l.horizontal_alignment = 1
	l.vertical_alignment = 1
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		l.add_theme_font_override("font", font)
	return l

func _bg(color = Color(0.06, 0.08, 0.12)):
	var bg = ColorRect.new()
	bg.color = color
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

# Live update every frame when in gameplay
func _process(delta):
	if current_screen != "gameplay":
		return
	ui_timer += delta
	if ui_timer < 1.0:
		return
	ui_timer = 0.0
	_update_live()

func _update_live():
	var s = _get_sim()
	var g = _get_gs()
	if s == null or g == null:
		return
	if lbl_cash != null:
		lbl_cash.text = "Cash: " + str(g.cash) + " R"
	if lbl_fuel != null:
		lbl_fuel.text = "Fuel: " + str(s.fuel_stored) + "/" + str(g.player_fuel_capacity) + " L"
	if lbl_price != null:
		lbl_price.text = "Price: " + str(int(s.fuel_price)) + " R/L"
	if lbl_time != null:
		var h = int(s.game_time) % 24
		lbl_time.text = "Time: " + str(h) + ":00"
	if lbl_revenue != null:
		lbl_revenue.text = "Revenue: " + str(s.revenue) + " R"
	if lbl_fuel_sold != null:
		lbl_fuel_sold.text = "Sold: " + str(s.fuel_sold) + " L"
	if lbl_status != null:
		var h = int(s.game_time) % 24
		var period = "Night"
		if h >= 7 and h <= 9:
			period = "Morning rush!"
		elif h >= 12 and h <= 14:
			period = "Lunch rush!"
		elif h >= 17 and h <= 19:
			period = "Evening rush!"
		elif h >= 6 and h <= 22:
			period = "Daytime"
		lbl_status.text = period + " | Pumps: " + str(s.player_pumps) + " | Fuel: " + str(s.fuel_stored) + "L"

# ==================== MAIN MENU ====================

func show_main_menu(boot_node):
	boot = boot_node
	_load_font()
	_clear()
	current_screen = "main_menu"
	boot.add_child(_bg())
	boot.add_child(_lbl("NEFTEGORSK", 0, 30, 1080, 80, 56, Color(1, 0.9, 0.3)))
	boot.add_child(_lbl("v25e", 0, 100, 1080, 30, 18, Color(0.5, 0.5, 0.6)))
	var g = _get_gs()
	var cash_str = "0"
	var stars_str = "0"
	if g != null:
		cash_str = str(g.cash)
		stars_str = str(g.total_stars)
	boot.add_child(_lbl("Money: " + cash_str + " R", 40, 150, 500, 40, 22, Color(0.7, 0.9, 0.7), false))
	boot.add_child(_lbl("Stars: " + stars_str, 540, 150, 500, 40, 22, Color(1, 0.9, 0.3), false))
	boot.add_child(_lbl("Select District:", 40, 210, 1000, 40, 24, Color(0.7, 0.7, 0.8), false))
	var y = 260
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	for d_id in order:
		if g == null:
			break
		var d_name = g.district_names.get(d_id, d_id)
		var unlocked = g.is_district_unlocked(d_id)
		var req = g.district_req_stars.get(d_id, 0)
		var lc = g.district_levels_count.get(d_id, 0)
		var dc = g.district_colors.get(d_id, Color(0.2, 0.2, 0.3))
		if unlocked:
			var done = 0
			for i in range(1, lc + 1):
				var key = d_id + "_" + str(i)
				if g.completed_levels.has(key) and g.completed_levels[key] > 0:
					done += 1
			var t = d_name + "  [" + str(done) + "/" + str(lc) + "]"
			boot.add_child(_btn(t, 40, y, 1000, 65, dc, 22, _on_district, d_id))
		else:
			boot.add_child(_lbl(d_name + "  [Need " + str(req) + " stars]", 40, y, 1000, 65, 20, Color(0.35, 0.35, 0.4), false))
		y += 75
	y += 20
	boot.add_child(_btn("Upgrade Shop", 40, y, 1000, 60, Color(0.15, 0.12, 0.25), 24, _show_upgrade_shop))
	y += 70
	boot.add_child(_btn("Save Game", 40, y, 480, 50, Color(0.12, 0.18, 0.12), 20, _on_save))
	boot.add_child(_btn("Reset", 560, y, 480, 50, Color(0.25, 0.1, 0.1), 20, _on_reset))

func _on_district(d_id):
	current_district_id = d_id
	_show_level_select()

func _on_save():
	var g = _get_gs()
	if g != null:
		g.save_game()

func _on_reset():
	var g = _get_gs()
	if g != null:
		g.cash = 50000
		g.total_stars = 0
		g.completed_levels = {}
		g.unlocked_districts = [StringName("business_center")]
		g.owned_upgrades = []
		g.apply_upgrades()
		g.save_game()
	show_main_menu(boot)

# ==================== LEVEL SELECT ====================

func _show_level_select():
	_clear()
	current_screen = "level_select"
	boot.add_child(_bg())
	var g = _get_gs()
	var d_name = ""
	var lc = 4
	var dc = Color(0.2, 0.2, 0.3)
	if g != null:
		d_name = g.district_names.get(current_district_id, current_district_id)
		lc = g.district_levels_count.get(current_district_id, 4)
		dc = g.district_colors.get(current_district_id, dc)
	boot.add_child(_btn("<< Back", 20, 20, 180, 45, Color(0.2, 0.25, 0.3), 22, show_main_menu.bind(boot)))
	boot.add_child(_lbl(d_name, 220, 20, 640, 50, 38, Color(1, 0.9, 0.3)))
	var y = 120
	for i in range(1, lc + 1):
		var key = current_district_id + "_" + str(i)
		var stars = 0
		if g != null and g.completed_levels.has(key):
			stars = g.completed_levels[key]
		var unlocked = (i == 1)
		if g != null and g.has_method("is_level_unlocked"):
			unlocked = g.is_level_unlocked(current_district_id, i)
		var st = ""
		for s in range(3):
			if s < stars:
				st += "* "
			else:
				st += "- "
		var oc = min(i, 3)
		var t = "Level " + str(i) + "  " + st + "  " + str(oc) + " opponent(s)"
		if unlocked:
			var c = dc
			if stars > 0:
				c = Color(dc.r + 0.08, dc.g + 0.08, dc.b + 0.05)
			boot.add_child(_btn(t, 40, y, 1000, 65, c, 22, _on_level, i))
		else:
			boot.add_child(_lbl("Level " + str(i) + "  [Locked]", 40, y, 1000, 65, 20, Color(0.35, 0.35, 0.4), false))
		y += 75

func _on_level(num):
	current_level_num = num
	_init_sim()
	show_gameplay(boot)

func _init_sim():
	var s = _get_sim()
	if s == null:
		return
	var g = _get_gs()
	if g != null:
		g.apply_upgrades()
		s.grid_size = g.district_grid_sizes.get(current_district_id, 8)
		s.fuel_price = 50.0
		s.fuel_stored = g.player_fuel_capacity
		s.player_pumps = g.player_pumps
		s.revenue = 0
		s.fuel_sold = 0
		s.game_time = 8.0
		s.sales_timer = 0.0
		s.cost_timer = 0.0
		s.ai_timer = 0.0
		s.level_start_cash = g.cash
		s.level_start_real_time = Time.get_unix_time_from_system()
		s.buyout_confirm_id = -1
		s.current_district = current_district_id
		s.current_level_num = current_level_num
	s.in_game = false
	s.map_tiles = []
	s.opponents = []
	var rng = RandomNumberGenerator.new()
	rng.seed = current_level_num * 12345 + current_district_id.hash()
	var sz = s.grid_size
	for y in range(sz):
		var row = []
		for x in range(sz):
			row.append(0)
		s.map_tiles.append(row)
	var h_count = 2
	if current_level_num > 2:
		h_count = 3
	for i in range(h_count):
		var ry = rng.randi_range(1, sz - 2)
		for x in range(sz):
			s.map_tiles[ry][x] = 1
	for i in range(h_count):
		var rx = rng.randi_range(1, sz - 2)
		for y in range(sz):
			s.map_tiles[y][rx] = 1
	for y in range(sz):
		for x in range(sz):
			if s.map_tiles[y][x] == 0:
				var near = false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var ny = y + dy
						var nx = x + dx
						if ny >= 0 and ny < sz and nx >= 0 and nx < sz and s.map_tiles[ny][nx] == 1:
							near = true
				if near and rng.randf() < 0.55:
					s.map_tiles[y][x] = 2
	var px = sz / 2
	var py = sz / 2
	for y in range(sz):
		for x in range(sz):
			if s.map_tiles[y][x] == 1 and abs(x - sz / 2) <= 2 and abs(y - sz / 2) <= 2:
				px = x
				py = y
				break
	s.map_tiles[py][px] = 5
	var opp_count = min(current_level_num, 3)
	var archetypes = ["shark", "miser", "opportunist"]
	for i in range(opp_count):
		for attempt in range(30):
			var ox = rng.randi_range(1, sz - 2)
			var oy = rng.randi_range(1, sz - 2)
			if s.map_tiles[oy][ox] == 1 and (abs(ox - px) + abs(oy - py)) >= 3:
				s.map_tiles[oy][ox] = 6
				var arch = archetypes[i % 3]
				var opp_name = "Opponent"
				var opp_price = 42.5 * 1.15
				var opp_loyalty = 1.0
				var opp_aggression = 1.0
				var opp_change_freq = 0.6
				var opp_margin = 0.15
				if arch == "shark":
					opp_name = "Akula"
					opp_price = 42.5 * 1.12
					opp_loyalty = 0.7
					opp_aggression = 1.8
					opp_change_freq = 0.8
					opp_margin = 0.12
				elif arch == "miser":
					opp_name = "Skupoy"
					opp_price = 42.5 * 1.25
					opp_loyalty = 1.8
					opp_aggression = 0.4
					opp_change_freq = 0.2
					opp_margin = 0.25
				else:
					opp_name = "Opportunist"
					opp_price = 42.5 * 1.15
					opp_loyalty = 1.0
					opp_aggression = 1.0
					opp_change_freq = 0.6
					opp_margin = 0.15
				s.opponents.append({
					"id": i,
					"archetype": arch,
					"name": opp_name,
					"pos": Vector2i(ox, oy),
					"price": opp_price,
					"cash": 30000 + current_level_num * 10000,
					"loyalty": opp_loyalty,
					"stations_count": 1,
					"aggression": opp_aggression,
					"change_freq": opp_change_freq,
					"margin": opp_margin,
				})
				break
	s.in_game = true

# ==================== GAMEPLAY ====================

func show_gameplay(boot_node):
	boot = boot_node
	_load_font()
	_clear()
	current_screen = "gameplay"
	ui_timer = 0.0
	var g = _get_gs()
	var s = _get_sim()
	boot.add_child(_bg(Color(0.04, 0.06, 0.1)))
	boot.add_child(_btn("<< Back", 20, 15, 140, 40, Color(0.25, 0.15, 0.15), 20, _on_back))
	var d_name = ""
	if g != null:
		d_name = g.district_names.get(current_district_id, "")
	boot.add_child(_lbl(d_name + " Lv." + str(current_level_num), 180, 15, 500, 40, 28, Color(1, 0.9, 0.3)))
	var cash_str = "0"
	if g != null:
		cash_str = str(g.cash)
	lbl_cash = _lbl("Cash: " + cash_str + " R", 700, 15, 360, 40, 22, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_cash)

	# === MAP === top-down grid using ColorRect
	var sz = 8
	var mt = []
	if s != null:
		sz = s.grid_size
		mt = s.map_tiles
	var ts = 42
	var map_w = sz * ts
	var map_x = 540 - map_w / 2
	var map_y = 60
	var dc = Color(0.2, 0.2, 0.3)
	if g != null:
		dc = g.district_colors.get(current_district_id, dc)
	# Map border
	var border = ColorRect.new()
	border.color = Color(dc.r * 0.3, dc.g * 0.3, dc.b * 0.3)
	border.position = Vector2(map_x - 4, map_y - 4)
	border.size = Vector2(map_w + 8, sz * ts + 8)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(border)
	for iy in range(sz):
		for ix in range(sz):
			var tt = 0
			if mt.size() > iy and mt[iy].size() > ix:
				tt = mt[iy][ix]
			var c = Color(dc.r * 0.7, dc.g * 0.7, dc.b * 0.7)
			var txt = ""
			var tc = Color(1, 1, 1)
			if tt == 0:
				c = Color(dc.r * 0.6, dc.g * 0.6, dc.b * 0.6)
			elif tt == 1:
				c = Color(0.35, 0.35, 0.4)
				txt = ""
			elif tt == 2:
				c = Color(dc.r + 0.25, dc.g + 0.15, dc.b + 0.08)
				txt = "B"
				tc = Color(0.6, 0.5, 0.4)
			elif tt == 5:
				c = Color(0.15, 0.65, 0.2)
				txt = "P"
				tc = Color(1, 1, 1)
			elif tt == 6:
				c = Color(0.75, 0.15, 0.15)
				txt = "E"
				tc = Color(1, 1, 1)
			var cr = ColorRect.new()
			cr.color = c
			cr.position = Vector2(map_x + ix * ts, map_y + iy * ts)
			cr.size = Vector2(ts - 2, ts - 2)
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boot.add_child(cr)
			if txt != "":
				var tl = _lbl(txt, map_x + ix * ts, map_y + iy * ts, ts - 2, ts - 2, 18, tc)
				boot.add_child(tl)
	# Map legend
	boot.add_child(_lbl("P=You  E=Enemy  B=Building  Gray=Road", map_x - 4, map_y + sz * ts + 4, map_w + 8, 22, 13, Color(0.5, 0.5, 0.5), false))

	# === INFO PANEL ===
	var py = map_y + sz * ts + 30
	boot.add_child(_lbl("-- Fuel Station --", 40, py, 1000, 30, 20, Color(0.5, 0.5, 0.6)))
	var fuel_str = "0"
	var price_str = "50"
	var cap_str = "5000"
	if s != null:
		fuel_str = str(s.fuel_stored)
		price_str = str(int(s.fuel_price))
	if g != null:
		cap_str = str(g.player_fuel_capacity)
	lbl_fuel = _lbl("Fuel: " + fuel_str + "/" + cap_str + " L", 40, py + 30, 500, 28, 20, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel)
	lbl_price = _lbl("Price: " + price_str + " R/L", 540, py + 30, 500, 28, 20, Color(1, 0.9, 0.3), false)
	boot.add_child(lbl_price)
	var cy = py + 62
	boot.add_child(_btn("Price -5", 40, cy, 230, 50, Color(0.2, 0.15, 0.1), 20, _on_price_down))
	boot.add_child(_btn("Price +5", 280, cy, 230, 50, Color(0.2, 0.15, 0.1), 20, _on_price_up))
	boot.add_child(_btn("Buy Fuel", 520, cy, 250, 50, Color(0.1, 0.2, 0.15), 20, _on_buy))
	boot.add_child(_btn("Buy MAX", 780, cy, 260, 50, Color(0.1, 0.15, 0.2), 20, _on_buy_max))
	var time_str = "8:00"
	if s != null:
		var h = int(s.game_time) % 24
		time_str = str(h) + ":00"
	lbl_time = _lbl("Time: " + time_str, 40, cy + 55, 300, 28, 20, Color(0.5, 0.5, 0.6), false)
	boot.add_child(lbl_time)
	var rev_str = "0"
	var sold_str = "0"
	if s != null:
		rev_str = str(s.revenue)
		sold_str = str(s.fuel_sold)
	lbl_revenue = _lbl("Revenue: " + rev_str + " R", 340, cy + 55, 350, 28, 20, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_revenue)
	lbl_fuel_sold = _lbl("Sold: " + sold_str + " L", 700, cy + 55, 340, 28, 20, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel_sold)
	lbl_msg = _lbl("", 40, cy + 88, 1000, 28, 16, Color(0.6, 0.6, 0.6), false)
	boot.add_child(lbl_msg)
	lbl_status = _lbl("", 40, cy + 112, 1000, 28, 16, Color(0.8, 0.7, 0.3), false)
	boot.add_child(lbl_status)
	# Opponents
	var oy = cy + 145
	boot.add_child(_lbl("-- Opponents --", 40, oy, 1000, 30, 20, Color(0.5, 0.5, 0.6)))
	lbl_opp_msg = _lbl("", 40, oy + 28, 1000, 28, 16, Color(0.9, 0.6, 0.3), false)
	boot.add_child(lbl_opp_msg)
	var oby = oy + 58
	if s != null:
		var ol = s.opponents
		if ol != null:
			for opp in ol:
				if opp.stations_count > 0:
					var bp = s.calc_buyout(opp)
					var ot = opp.name + "  Price:" + str(int(opp.price)) + "R  BUYOUT:" + str(bp) + "R"
					boot.add_child(_btn(ot, 40, oby, 1000, 55, Color(0.2, 0.08, 0.08), 20, _on_buyout, opp.id))
					oby += 62
	oby += 15
	boot.add_child(_btn("Upgrade Shop", 40, oby, 1000, 50, Color(0.12, 0.12, 0.2), 22, _show_upgrade_shop))

func _on_back():
	var s = _get_sim()
	if s != null:
		s.stop_level()
	_show_level_select()

func _on_price_up():
	var s = _get_sim()
	if s != null:
		s.fuel_price = min(s.fuel_price + 5.0, 85.0)
	_update_live()

func _on_price_down():
	var s = _get_sim()
	if s != null:
		s.fuel_price = max(s.fuel_price - 5.0, 35.0)
	_update_live()

func _on_buy():
	var g = _get_gs()
	var s = _get_sim()
	if g == null or s == null:
		return
	var amount = 1000
	var cost = int(amount * s.wholesale_price)
	if g.cash >= cost:
		g.cash -= cost
		s.fuel_stored = min(s.fuel_stored + amount, g.player_fuel_capacity)
		if lbl_msg != null:
			lbl_msg.text = "Bought " + str(amount) + "L for " + str(cost) + "R"
	else:
		if lbl_msg != null:
			lbl_msg.text = "Not enough cash! Need " + str(cost) + "R"
	_update_live()

func _on_buy_max():
	var g = _get_gs()
	var s = _get_sim()
	if g == null or s == null:
		return
	var space = g.player_fuel_capacity - s.fuel_stored
	if space <= 0:
		if lbl_msg != null:
			lbl_msg.text = "Tank is full!"
		return
	var cost = int(space * s.wholesale_price)
	if g.cash >= cost:
		g.cash -= cost
		s.fuel_stored += space
		if lbl_msg != null:
			lbl_msg.text = "Bought " + str(space) + "L for " + str(cost) + "R"
	else:
		var can = int(g.cash / s.wholesale_price)
		if can > 0:
			var ac = int(can * s.wholesale_price)
			g.cash -= ac
			s.fuel_stored += can
			if lbl_msg != null:
				lbl_msg.text = "Bought " + str(can) + "L for " + str(ac) + "R"
		else:
			if lbl_msg != null:
				lbl_msg.text = "Not enough cash!"
	_update_live()

func _on_buyout(opp_id):
	var g = _get_gs()
	var s = _get_sim()
	if g == null or s == null:
		return
	var opp = s.find_opponent(opp_id)
	if opp == null:
		return
	var price = s.calc_buyout(opp)
	if g.cash >= price:
		g.cash -= price
		opp.stations_count = 0
		if lbl_msg != null:
			lbl_msg.text = "Bought out " + opp.name + " for " + str(price) + "R!"
		s.check_win()
	else:
		if lbl_msg != null:
			lbl_msg.text = "Not enough cash! Need " + str(price) + "R"
	_update_live()

func update_gameplay_ui():
	_update_live()

# ==================== UPGRADE SHOP ====================

func _show_upgrade_shop():
	_clear()
	current_screen = "upgrade_shop"
	boot.add_child(_bg(Color(0.05, 0.05, 0.1)))
	boot.add_child(_btn("<< Back", 20, 20, 180, 45, Color(0.2, 0.25, 0.3), 22, _on_shop_back))
	boot.add_child(_lbl("Upgrade Shop", 220, 20, 640, 50, 38, Color(1, 0.9, 0.3)))
	var g = _get_gs()
	if g == null:
		boot.add_child(_lbl("GameState not available!", 40, 100, 1000, 40, 24, Color(1, 0.3, 0.3)))
		return
	boot.add_child(_lbl("Cash: " + str(g.cash) + " R  |  Stars: " + str(g.total_stars), 40, 80, 1000, 30, 20, Color(0.7, 0.9, 0.7), false))
	var y = 130
	for upg in g.upgrade_defs:
		var uid = upg.get("id", "")
		var un = upg.get("name", "")
		var ud = upg.get("desc", "")
		var us = upg.get("stars", 0)
		var uc = upg.get("cash", 0)
		var ucat = upg.get("cat", "")
		var owned = uid in g.owned_upgrades
		var cc = Color(0.12, 0.15, 0.2)
		if ucat == "station":
			cc = Color(0.12, 0.18, 0.12)
		elif ucat == "logistics":
			cc = Color(0.12, 0.12, 0.2)
		elif ucat == "marketing":
			cc = Color(0.2, 0.15, 0.1)
		if owned:
			boot.add_child(_lbl("[OWNED] " + un + " - " + ud, 40, y, 1000, 55, 20, Color(0.4, 0.5, 0.4), false))
		else:
			var can = (g.cash >= uc and g.total_stars >= us)
			var bt = un + " - " + ud + " [" + str(uc) + "R, " + str(us) + "*]"
			if can:
				boot.add_child(_btn(bt, 40, y, 1000, 55, cc, 20, _on_buy_upg, uid))
			else:
				boot.add_child(_lbl("[LOCKED] " + bt, 40, y, 1000, 55, 18, Color(0.35, 0.35, 0.4), false))
		y += 65

func _on_buy_upg(uid):
	var g = _get_gs()
	if g == null:
		return
	var ud = null
	for upg in g.upgrade_defs:
		if upg.get("id", "") == uid:
			ud = upg
			break
	if ud == null:
		return
	var uc = ud.get("cash", 0)
	var us = ud.get("stars", 0)
	if g.cash >= uc and g.total_stars >= us:
		g.cash -= uc
		g.total_stars -= us
		g.owned_upgrades.append(uid)
		g.apply_upgrades()
		g.save_game()
	_show_upgrade_shop()

func _on_shop_back():
	if current_screen == "gameplay":
		show_gameplay(boot)
	else:
		show_main_menu(boot)

# ==================== WIN/LOSE ====================

func show_result(won, stars, stars_gained):
	_clear()
	current_screen = "result"
	if won:
		boot.add_child(_bg(Color(0.04, 0.08, 0.06)))
		boot.add_child(_lbl("VICTORY!", 0, 100, 1080, 80, 56, Color(0.3, 1.0, 0.3)))
		boot.add_child(_lbl("Stars earned: " + str(stars), 0, 200, 1080, 50, 32, Color(1, 0.9, 0.3)))
		var g = _get_gs()
		if g != null:
			boot.add_child(_lbl("Cash: " + str(g.cash) + " R", 0, 270, 1080, 40, 24, Color(0.7, 0.9, 0.7)))
			boot.add_child(_lbl("Total Stars: " + str(g.total_stars), 0, 320, 1080, 40, 24, Color(1, 0.9, 0.3)))
	else:
		boot.add_child(_bg(Color(0.1, 0.04, 0.04)))
		boot.add_child(_lbl("BANKRUPT!", 0, 100, 1080, 80, 56, Color(1.0, 0.2, 0.2)))
		boot.add_child(_lbl("Your business went under.", 0, 200, 1080, 50, 28, Color(0.8, 0.5, 0.5)))
	boot.add_child(_btn("Back to Menu", 290, 500, 500, 60, Color(0.15, 0.2, 0.25), 26, show_main_menu.bind(boot)))
	boot.add_child(_btn("Retry Level", 290, 580, 500, 60, Color(0.2, 0.15, 0.1), 26, _on_retry))

func _on_retry():
	_init_sim()
	show_gameplay(boot)
