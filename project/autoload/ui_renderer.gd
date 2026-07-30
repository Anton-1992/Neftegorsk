## UIRenderer.gd — v25: full gameplay
extends Node

var boot = null
var font = null
var gs = null
var sim = null
var current_district_id = ""
var current_level_num = 0
var current_screen = "main_menu"

var lbl_cash = null
var lbl_fuel = null
var lbl_price = null
var lbl_time = null
var lbl_msg = null
var lbl_opp_msg = null
var lbl_revenue = null
var lbl_fuel_sold = null

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

# ==================== MAIN MENU ====================

func show_main_menu(boot_node):
	boot = boot_node
	_load_font()
	_clear()
	current_screen = "main_menu"
	boot.add_child(_bg())
	boot.add_child(_lbl("NEFTEGORSK", 0, 30, 1080, 80, 56, Color(1, 0.9, 0.3)))
	boot.add_child(_lbl("v25", 0, 100, 1080, 30, 18, Color(0.5, 0.5, 0.6)))
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
	var s = _get_sim()
	if s != null:
		s.start_level(current_district_id, current_level_num, boot)
	else:
		show_gameplay(boot)

# ==================== GAMEPLAY ====================

func show_gameplay(boot_node):
	boot = boot_node
	_load_font()
	_clear()
	current_screen = "gameplay"
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
	_draw_map(s)
	var py = 500
	boot.add_child(_lbl("-- Fuel Station --", 40, py, 1000, 30, 20, Color(0.5, 0.5, 0.6)))
	var fuel_str = "0"
	var price_str = "50"
	var cap_str = "5000"
	if s != null:
		fuel_str = str(s.fuel_stored)
		price_str = str(int(s.fuel_price))
	if g != null:
		cap_str = str(g.player_fuel_capacity)
	lbl_fuel = _lbl("Fuel: " + fuel_str + "/" + cap_str + " L", 40, py + 35, 500, 30, 20, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel)
	lbl_price = _lbl("Price: " + price_str + " R/L", 540, py + 35, 500, 30, 20, Color(1, 0.9, 0.3), false)
	boot.add_child(lbl_price)
	var cy = py + 75
	boot.add_child(_btn("Price -5", 40, cy, 230, 50, Color(0.2, 0.15, 0.1), 20, _on_price_down))
	boot.add_child(_btn("Price +5", 280, cy, 230, 50, Color(0.2, 0.15, 0.1), 20, _on_price_up))
	boot.add_child(_btn("Buy Fuel", 520, cy, 250, 50, Color(0.1, 0.2, 0.15), 20, _on_buy))
	boot.add_child(_btn("Buy MAX", 780, cy, 260, 50, Color(0.1, 0.15, 0.2), 20, _on_buy_max))
	var time_str = "8:00"
	if s != null:
		var h = int(s.game_time) % 24
		time_str = str(h) + ":00"
	lbl_time = _lbl("Time: " + time_str, 40, cy + 60, 300, 30, 20, Color(0.5, 0.5, 0.6), false)
	boot.add_child(lbl_time)
	var rev_str = "0"
	var sold_str = "0"
	if s != null:
		rev_str = str(s.revenue)
		sold_str = str(s.fuel_sold)
	lbl_revenue = _lbl("Revenue: " + rev_str + " R", 340, cy + 60, 350, 30, 20, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_revenue)
	lbl_fuel_sold = _lbl("Sold: " + sold_str + " L", 700, cy + 60, 340, 30, 20, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel_sold)
	lbl_msg = _lbl("", 40, cy + 100, 1000, 30, 18, Color(0.6, 0.6, 0.6), false)
	boot.add_child(lbl_msg)
	var oy = cy + 145
	boot.add_child(_lbl("-- Opponents --", 40, oy, 1000, 30, 20, Color(0.5, 0.5, 0.6)))
	lbl_opp_msg = _lbl("", 40, oy + 30, 1000, 30, 18, Color(0.9, 0.6, 0.3), false)
	boot.add_child(lbl_opp_msg)
	var oby = oy + 65
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

func _draw_map(s):
	var gs_val = 8
	var mt = []
	if s != null:
		gs_val = s.grid_size
		mt = s.map_tiles
	var tw = 50
	var th = 25
	var ox = 540
	var oy = 80
	var g = _get_gs()
	var dc = Color(0.2, 0.2, 0.3)
	if g != null:
		dc = g.district_colors.get(current_district_id, dc)
	for iy in range(gs_val):
		for ix in range(gs_val):
			var tt = 0
			if mt.size() > iy and mt[iy].size() > ix:
				tt = mt[iy][ix]
			var c = dc
			if tt == 1:
				c = Color(dc.r + 0.12, dc.g + 0.12, dc.b + 0.1)
			elif tt == 2:
				c = Color(dc.r + 0.2, dc.g + 0.15, dc.b + 0.08)
			elif tt == 3:
				c = Color(0.15, 0.25, 0.4)
			elif tt == 4:
				c = Color(0.15, 0.35, 0.2)
			elif tt == 5:
				c = Color(0.2, 0.7, 0.25)
			elif tt == 6:
				c = Color(0.8, 0.2, 0.2)
			var sx = ox + (ix - iy) * tw
			var sy = oy + (ix + iy) * th
			var p = Polygon2D.new()
			p.polygon = PackedVector2Array([Vector2(0, -th), Vector2(tw, 0), Vector2(0, th), Vector2(-tw, 0)])
			p.color = c
			p.position = Vector2(sx, sy)
			boot.add_child(p)
			if tt == 5:
				boot.add_child(_lbl("YOU", sx - tw, sy - th, tw * 2, th * 2, 12, Color(1, 1, 1)))
			elif tt == 6:
				boot.add_child(_lbl("!", sx - tw, sy - th, tw * 2, th * 2, 14, Color(1, 0.8, 0.3)))

func _on_back():
	var s = _get_sim()
	if s != null:
		s.stop_level()
	_show_level_select()

func _on_price_up():
	var s = _get_sim()
	if s != null:
		s.fuel_price = min(s.fuel_price + 5.0, 85.0)
	update_gameplay_ui()

func _on_price_down():
	var s = _get_sim()
	if s != null:
		s.fuel_price = max(s.fuel_price - 5.0, 35.0)
	update_gameplay_ui()

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
	update_gameplay_ui()

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
	update_gameplay_ui()

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
	update_gameplay_ui()

func update_gameplay_ui():
	var g = _get_gs()
	var s = _get_sim()
	if g == null or s == null:
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
	var s = _get_sim()
	if s != null:
		s.start_level(current_district_id, current_level_num, boot)
	else:
		show_gameplay(boot)
