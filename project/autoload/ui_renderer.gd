## UIRenderer.gd — v25: full gameplay UI
## NO class_name, NO @onready, NO gui_input, NO emoji, NO ternary
## All Button.pressed signals, DejaVuSans.ttf on all Button+Label
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
	var children = boot.get_children()
	for child in children:
		boot.remove_child(child)
		child.free()

func _make_btn(text, x, y, w, h, color, font_size, callback, cb_arg = null):
	var btn = Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	if font != null:
		btn.add_theme_font_override("font", font)
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.content_margin_left = 10
	s.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	if cb_arg != null:
		btn.pressed.connect(callback.bind(cb_arg))
	else:
		btn.pressed.connect(callback)
	return btn

func _make_label(text, x, y, w, h, font_size, color, align_center = true):
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, h)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if align_center:
		lbl.horizontal_alignment = 1
	lbl.vertical_alignment = 1
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		lbl.add_theme_font_override("font", font)
	return lbl

func _make_bg(color = Color(0.06, 0.08, 0.12)):
	var bg = ColorRect.new()
	bg.color = color
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

# ==================== MAIN MENU ====================

func show_main_menu(boot_node):
	boot = boot_node
	_load_font()
	_clear()
	current_screen = "main_menu"
	boot.add_child(_make_bg())
	boot.add_child(_make_label("NEFTEGORSK", 0, 30, 1080, 80, 56, Color(1, 0.9, 0.3)))
	boot.add_child(_make_label("v25", 0, 100, 1080, 30, 18, Color(0.5, 0.5, 0.6)))
	var gs_node = _get_gs()
	var cash_str = "0"
	var stars_str = "0"
	if gs_node != null:
		cash_str = str(gs_node.cash)
		stars_str = str(gs_node.total_stars)
	boot.add_child(_make_label("Money: " + cash_str + " R", 40, 150, 500, 40, 22, Color(0.7, 0.9, 0.7), false))
	boot.add_child(_make_label("Stars: " + stars_str, 540, 150, 500, 40, 22, Color(1, 0.9, 0.3), false))
	boot.add_child(_make_label("Select District:", 40, 210, 1000, 40, 24, Color(0.7, 0.7, 0.8), false))
	var y = 260
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	for d_id in order:
		if gs_node == null:
			break
		var d_name = gs_node.district_names.get(d_id, d_id)
		var is_unlocked = gs_node.is_district_unlocked(d_id)
		var req_stars = gs_node.district_req_stars.get(d_id, 0)
		var levels_count = gs_node.district_levels_count.get(d_id, 0)
		var d_color = gs_node.district_colors.get(d_id, Color(0.2, 0.2, 0.3))
		if is_unlocked:
			var completed = 0
			for i in range(1, levels_count + 1):
				var key = d_id + "_" + str(i)
				if gs_node.completed_levels.has(key) and gs_node.completed_levels[key] > 0:
					completed += 1
			var btn_text = d_name + "  [" + str(completed) + "/" + str(levels_count) + "]"
			var btn = _make_btn(btn_text, 40, y, 1000, 65, d_color, 22, _on_district_pressed, d_id)
			boot.add_child(btn)
		else:
			var lbl = _make_label(d_name + "  [Need " + str(req_stars) + " stars]", 40, y, 1000, 65, 20, Color(0.35, 0.35, 0.4), false)
			boot.add_child(lbl)
		y += 75
	y += 20
	boot.add_child(_make_btn("Upgrade Shop", 40, y, 1000, 60, Color(0.15, 0.12, 0.25), 24, _show_upgrade_shop))
	y += 70
	boot.add_child(_make_btn("Save Game", 40, y, 480, 50, Color(0.12, 0.18, 0.12), 20, _on_save_pressed))
	boot.add_child(_make_btn("Reset", 560, y, 480, 50, Color(0.25, 0.1, 0.1), 20, _on_reset_pressed))

func _on_district_pressed(d_id):
	current_district_id = d_id
	_show_level_select()

func _on_save_pressed():
	var gs_node = _get_gs()
	if gs_node != null:
		gs_node.save_game()

func _on_reset_pressed():
	var gs_node = _get_gs()
	if gs_node != null:
		gs_node.cash = 50000
		gs_node.total_stars = 0
		gs_node.completed_levels = {}
		gs_node.unlocked_districts = [StringName("business_center")]
		gs_node.owned_upgrades = []
		gs_node.apply_upgrades()
		gs_node.save_game()
	show_main_menu(boot)

# ==================== LEVEL SELECT ====================

func _show_level_select():
	_clear()
	current_screen = "level_select"
	boot.add_child(_make_bg())
	var gs_node = _get_gs()
	var d_name = ""
	var levels_count = 0
	var d_color = Color(0.2, 0.2, 0.3)
	if gs_node != null:
		d_name = gs_node.district_names.get(current_district_id, current_district_id)
		levels_count = gs_node.district_levels_count.get(current_district_id, 4)
		d_color = gs_node.district_colors.get(current_district_id, Color(0.2, 0.2, 0.3))
	boot.add_child(_make_btn("<< Back", 20, 20, 180, 45, Color(0.2, 0.25, 0.3), 22, show_main_menu.bind(boot)))
	boot.add_child(_make_label(d_name, 220, 20, 640, 50, 38, Color(1, 0.9, 0.3)))
	var y = 120
	for i in range(1, levels_count + 1):
		var key = current_district_id + "_" + str(i)
		var stars = 0
		if gs_node != null and gs_node.completed_levels.has(key):
			stars = gs_node.completed_levels[key]
		var is_unlocked = (i == 1) or (gs_node != null and gs_node.is_level_unlocked(current_district_id, i))
		var star_text = ""
		for s in range(3):
			if s < stars:
				star_text += "* "
			else:
				star_text += "- "
		var opp_count = min(i, 3)
		var btn_text = "Level " + str(i) + "  " + star_text + "  " + str(opp_count) + " opponent(s)"
		if is_unlocked:
			var lvl_color = d_color
			if stars > 0:
				lvl_color = Color(d_color.r + 0.08, d_color.g + 0.08, d_color.b + 0.05)
			var btn = _make_btn(btn_text, 40, y, 1000, 65, lvl_color, 22, _on_level_pressed, i)
			boot.add_child(btn)
		else:
			boot.add_child(_make_label("Level " + str(i) + "  [Locked]", 40, y, 1000, 65, 20, Color(0.35, 0.35, 0.4), false))
		y += 75

func _on_level_pressed(num):
	current_level_num = num
	_start_gameplay()

# ==================== GAMEPLAY ====================

func _start_gameplay():
	var sim_node = _get_sim()
	if sim_node != null:
		sim_node.start_level(current_district_id, current_level_num, boot)
	else:
		show_gameplay(boot)

func show_gameplay(boot_node):
	boot = boot_node
	_load_font()
	_clear()
	current_screen = "gameplay"
	var gs_node = _get_gs()
	var sim_node = _get_sim()
	boot.add_child(_make_bg(Color(0.04, 0.06, 0.1)))
	boot.add_child(_make_btn("<< Back", 20, 15, 140, 40, Color(0.25, 0.15, 0.15), 20, _on_gameplay_back))
	var d_name = ""
	if gs_node != null:
		d_name = gs_node.district_names.get(current_district_id, "")
	boot.add_child(_make_label(d_name + " Lv." + str(current_level_num), 180, 15, 500, 40, 28, Color(1, 0.9, 0.3)))
	var cash_str = "0"
	if gs_node != null:
		cash_str = str(gs_node.cash)
	lbl_cash = _make_label("Cash: " + cash_str + " R", 700, 15, 360, 40, 22, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_cash)
	# Isometric map
	_draw_isometric_map(sim_node)
	# Info panel below map
	var panel_y = 500
	boot.add_child(_make_label("-- Fuel Station --", 40, panel_y, 1000, 30, 20, Color(0.5, 0.5, 0.6)))
	var fuel_str = "0"
	var price_str = "50"
	var capacity_str = "5000"
	if sim_node != null:
		fuel_str = str(sim_node.fuel_stored)
		price_str = str(int(sim_node.fuel_price))
	if gs_node != null:
		capacity_str = str(gs_node.player_fuel_capacity)
	lbl_fuel = _make_label("Fuel: " + fuel_str + "/" + capacity_str + " L", 40, panel_y + 35, 500, 30, 20, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel)
	lbl_price = _make_label("Price: " + price_str + " R/L", 540, panel_y + 35, 500, 30, 20, Color(1, 0.9, 0.3), false)
	boot.add_child(lbl_price)
	var ctrl_y = panel_y + 75
	boot.add_child(_make_btn("Price -5", 40, ctrl_y, 230, 50, Color(0.2, 0.15, 0.1), 20, _on_price_down))
	boot.add_child(_make_btn("Price +5", 280, ctrl_y, 230, 50, Color(0.2, 0.15, 0.1), 20, _on_price_up))
	boot.add_child(_make_btn("Buy Fuel", 520, ctrl_y, 250, 50, Color(0.1, 0.2, 0.15), 20, _on_buy_fuel))
	boot.add_child(_make_btn("Buy MAX", 780, ctrl_y, 260, 50, Color(0.1, 0.15, 0.2), 20, _on_buy_fuel_max))
	var time_str = "8:00"
	if sim_node != null:
		var h = int(sim_node.game_time) % 24
		time_str = str(h) + ":00"
	lbl_time = _make_label("Time: " + time_str, 40, ctrl_y + 60, 300, 30, 20, Color(0.5, 0.5, 0.6), false)
	boot.add_child(lbl_time)
	var rev_str = "0"
	var sold_str = "0"
	if sim_node != null:
		rev_str = str(sim_node.revenue)
		sold_str = str(sim_node.fuel_sold)
	lbl_revenue = _make_label("Revenue: " + rev_str + " R", 340, ctrl_y + 60, 350, 30, 20, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_revenue)
	lbl_fuel_sold = _make_label("Sold: " + sold_str + " L", 700, ctrl_y + 60, 340, 30, 20, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel_sold)
	lbl_msg = _make_label("", 40, ctrl_y + 100, 1000, 30, 18, Color(0.6, 0.6, 0.6), false)
	boot.add_child(lbl_msg)
	# Opponents
	var opp_y = ctrl_y + 145
	boot.add_child(_make_label("-- Opponents --", 40, opp_y, 1000, 30, 20, Color(0.5, 0.5, 0.6)))
	lbl_opp_msg = _make_label("", 40, opp_y + 30, 1000, 30, 18, Color(0.9, 0.6, 0.3), false)
	boot.add_child(lbl_opp_msg)
	var opp_btn_y = opp_y + 65
	if sim_node != null:
		var opp_list = sim_node.opponents
		if opp_list != null:
			for opp in opp_list:
				if opp.stations_count > 0:
					var buyout_price = sim_node.calc_buyout(opp)
					var opp_text = opp.name + "  Price:" + str(int(opp.price)) + "R  BUYOUT:" + str(buyout_price) + "R"
					var btn = _make_btn(opp_text, 40, opp_btn_y, 1000, 55, Color(0.2, 0.08, 0.08), 20, _on_buyout, opp.id)
					boot.add_child(btn)
					opp_btn_y += 62
	opp_btn_y += 15
	boot.add_child(_make_btn("Upgrade Shop", 40, opp_btn_y, 1000, 50, Color(0.12, 0.12, 0.2), 22, _show_upgrade_shop))

func _draw_isometric_map(sim_node):
	var grid_size = 8
	var map_tiles_ref = []
	if sim_node != null:
		grid_size = sim_node.grid_size
		map_tiles_ref = sim_node.map_tiles
	var tw = 50
	var th = 25
	var origin_x = 540
	var origin_y = 80
	var gs_node = _get_gs()
	var d_color = Color(0.2, 0.2, 0.3)
	if gs_node != null:
		d_color = gs_node.district_colors.get(current_district_id, d_color)
	for iy in range(grid_size):
		for ix in range(grid_size):
			var tile_type = 0
			if map_tiles_ref.size() > iy and map_tiles_ref[iy].size() > ix:
				tile_type = map_tiles_ref[iy][ix]
			var color = d_color
			if tile_type == 1:
				color = Color(d_color.r + 0.12, d_color.g + 0.12, d_color.b + 0.1)
			elif tile_type == 2:
				color = Color(d_color.r + 0.2, d_color.g + 0.15, d_color.b + 0.08)
			elif tile_type == 3:
				color = Color(0.15, 0.25, 0.4)
			elif tile_type == 4:
				color = Color(0.15, 0.35, 0.2)
			elif tile_type == 5:
				color = Color(0.2, 0.7, 0.25)
			elif tile_type == 6:
				color = Color(0.8, 0.2, 0.2)
			var sx = origin_x + (ix - iy) * tw
			var sy = origin_y + (ix + iy) * th
			var poly = Polygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(0, -th), Vector2(tw, 0), Vector2(0, th), Vector2(-tw, 0)])
			poly.color = color
			poly.position = Vector2(sx, sy)
			boot.add_child(poly)
			var outline = Line2D.new()
			outline.points = PackedVector2Array([Vector2(0, -th), Vector2(tw, 0), Vector2(0, th), Vector2(-tw, 0), Vector2(0, -th)])
			outline.width = 1.0
			outline.default_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
			outline.position = Vector2(sx, sy)
			boot.add_child(outline)
			if tile_type == 5:
				var lbl = _make_label("YOU", sx - tw, sy - th, tw * 2, th * 2, 12, Color(1, 1, 1))
				boot.add_child(lbl)
			elif tile_type == 6:
				var lbl = _make_label("!", sx - tw, sy - th, tw * 2, th * 2, 14, Color(1, 0.8, 0.3))
				boot.add_child(lbl)

func _on_gameplay_back():
	var sim_node = _get_sim()
	if sim_node != null:
		sim_node.stop_level()
	_show_level_select()

func _on_price_up():
	var sim_node = _get_sim()
	if sim_node != null:
		sim_node.fuel_price = min(sim_node.fuel_price + 5.0, 85.0)
	update_gameplay_ui()

func _on_price_down():
	var sim_node = _get_sim()
	if sim_node != null:
		sim_node.fuel_price = max(sim_node.fuel_price - 5.0, 35.0)
	update_gameplay_ui()

func _on_buy_fuel():
	var gs_node = _get_gs()
	var sim_node = _get_sim()
	if gs_node == null or sim_node == null:
		return
	var amount = 1000
	var cost = int(amount * sim_node.wholesale_price)
	if gs_node.cash >= cost:
		gs_node.cash -= cost
		sim_node.fuel_stored = min(sim_node.fuel_stored + amount, gs_node.player_fuel_capacity)
		if lbl_msg != null:
			lbl_msg.text = "Bought " + str(amount) + "L for " + str(cost) + "R"
	else:
		if lbl_msg != null:
			lbl_msg.text = "Not enough cash! Need " + str(cost) + "R"
	update_gameplay_ui()

func _on_buy_fuel_max():
	var gs_node = _get_gs()
	var sim_node = _get_sim()
	if gs_node == null or sim_node == null:
		return
	var space = gs_node.player_fuel_capacity - sim_node.fuel_stored
	if space <= 0:
		if lbl_msg != null:
			lbl_msg.text = "Tank is full!"
		return
	var cost = int(space * sim_node.wholesale_price)
	if gs_node.cash >= cost:
		gs_node.cash -= cost
		sim_node.fuel_stored += space
		if lbl_msg != null:
			lbl_msg.text = "Bought " + str(space) + "L for " + str(cost) + "R"
	else:
		var can_afford = int(gs_node.cash / sim_node.wholesale_price)
		if can_afford > 0:
			var actual_cost = int(can_afford * sim_node.wholesale_price)
			gs_node.cash -= actual_cost
			sim_node.fuel_stored += can_afford
			if lbl_msg != null:
				lbl_msg.text = "Bought " + str(can_afford) + "L for " + str(actual_cost) + "R"
		else:
			if lbl_msg != null:
				lbl_msg.text = "Not enough cash!"
	update_gameplay_ui()

func _on_buyout(opp_id):
	var gs_node = _get_gs()
	var sim_node = _get_sim()
	if gs_node == null or sim_node == null:
		return
	var opp = sim_node.find_opponent(opp_id)
	if opp == null:
		return
	var price = sim_node.calc_buyout(opp)
	if gs_node.cash >= price:
		gs_node.cash -= price
		opp.stations_count = 0
		if lbl_msg != null:
			lbl_msg.text = "Bought out " + opp.name + " for " + str(price) + "R!"
		sim_node.check_win()
	else:
		if lbl_msg != null:
			lbl_msg.text = "Not enough cash! Need " + str(price) + "R"
	update_gameplay_ui()

func update_gameplay_ui():
	var gs_node = _get_gs()
	var sim_node = _get_sim()
	if gs_node == null or sim_node == null:
		return
	if lbl_cash != null:
		lbl_cash.text = "Cash: " + str(gs_node.cash) + " R"
	if lbl_fuel != null:
		lbl_fuel.text = "Fuel: " + str(sim_node.fuel_stored) + "/" + str(gs_node.player_fuel_capacity) + " L"
	if lbl_price != null:
		lbl_price.text = "Price: " + str(int(sim_node.fuel_price)) + " R/L"
	if lbl_time != null:
		var h = int(sim_node.game_time) % 24
		lbl_time.text = "Time: " + str(h) + ":00"
	if lbl_revenue != null:
		lbl_revenue.text = "Revenue: " + str(sim_node.revenue) + " R"
	if lbl_fuel_sold != null:
		lbl_fuel_sold.text = "Sold: " + str(sim_node.fuel_sold) + " L"

# ==================== UPGRADE SHOP ====================

func _show_upgrade_shop():
	_clear()
	current_screen = "upgrade_shop"
	boot.add_child(_make_bg(Color(0.05, 0.05, 0.1)))
	boot.add_child(_make_btn("<< Back", 20, 20, 180, 45, Color(0.2, 0.25, 0.3), 22, _on_shop_back))
	boot.add_child(_make_label("Upgrade Shop", 220, 20, 640, 50, 38, Color(1, 0.9, 0.3)))
	var gs_node = _get_gs()
	if gs_node == null:
		boot.add_child(_make_label("GameState not available!", 40, 100, 1000, 40, 24, Color(1, 0.3, 0.3)))
		return
	var cash_str = str(gs_node.cash)
	var stars_str = str(gs_node.total_stars)
	boot.add_child(_make_label("Cash: " + cash_str + " R  |  Stars: " + stars_str, 40, 80, 1000, 30, 20, Color(0.7, 0.9, 0.7), false))
	var y = 130
	var upgrade_defs = gs_node.upgrade_defs
	for upg in upgrade_defs:
		var upg_id = upg.get("id", "")
		var upg_name = upg.get("name", "")
		var upg_desc = upg.get("desc", "")
		var upg_stars = upg.get("stars", 0)
		var upg_cash = upg.get("cash", 0)
		var upg_cat = upg.get("cat", "")
		var is_owned = upg_id in gs_node.owned_upgrades
		var cat_color = Color(0.12, 0.15, 0.2)
		if upg_cat == "station":
			cat_color = Color(0.12, 0.18, 0.12)
		elif upg_cat == "logistics":
			cat_color = Color(0.12, 0.12, 0.2)
		elif upg_cat == "marketing":
			cat_color = Color(0.2, 0.15, 0.1)
		if is_owned:
			boot.add_child(_make_label("[OWNED] " + upg_name + " - " + upg_desc, 40, y, 1000, 55, 20, Color(0.4, 0.5, 0.4), false))
		else:
			var can_afford = (gs_node.cash >= upg_cash and gs_node.total_stars >= upg_stars)
			var btn_text = upg_name + " - " + upg_desc + " [" + str(upg_cash) + "R, " + str(upg_stars) + "*]"
			if can_afford:
				var btn = _make_btn(btn_text, 40, y, 1000, 55, cat_color, 20, _on_buy_upgrade, upg_id)
				boot.add_child(btn)
			else:
				boot.add_child(_make_label("[LOCKED] " + btn_text, 40, y, 1000, 55, 18, Color(0.35, 0.35, 0.4), false))
		y += 65

func _on_buy_upgrade(upg_id):
	var gs_node = _get_gs()
	if gs_node == null:
		return
	var upg_def = null
	for upg in gs_node.upgrade_defs:
		if upg.get("id", "") == upg_id:
			upg_def = upg
			break
	if upg_def == null:
		return
	var upg_cash = upg_def.get("cash", 0)
	var upg_stars = upg_def.get("stars", 0)
	if gs_node.cash >= upg_cash and gs_node.total_stars >= upg_stars:
		gs_node.cash -= upg_cash
		gs_node.total_stars -= upg_stars
		gs_node.owned_upgrades.append(upg_id)
		gs_node.apply_upgrades()
		gs_node.save_game()
	_show_upgrade_shop()

func _on_shop_back():
	if current_screen == "gameplay":
		show_gameplay(boot)
	else:
		show_main_menu(boot)

# ==================== WIN/LOSE SCREEN ====================

func show_result(won: bool, stars: int, stars_gained: int):
	_clear()
	current_screen = "result"
	if won:
		boot.add_child(_make_bg(Color(0.04, 0.08, 0.06)))
		boot.add_child(_make_label("VICTORY!", 0, 100, 1080, 80, 56, Color(0.3, 1.0, 0.3)))
		boot.add_child(_make_label("Stars earned: " + str(stars), 0, 200, 1080, 50, 32, Color(1, 0.9, 0.3)))
		var gs_node = _get_gs()
		if gs_node != null:
			boot.add_child(_make_label("Cash: " + str(gs_node.cash) + " R", 0, 270, 1080, 40, 24, Color(0.7, 0.9, 0.7)))
			boot.add_child(_make_label("Total Stars: " + str(gs_node.total_stars), 0, 320, 1080, 40, 24, Color(1, 0.9, 0.3)))
	else:
		boot.add_child(_make_bg(Color(0.1, 0.04, 0.04)))
		boot.add_child(_make_label("BANKRUPT!", 0, 100, 1080, 80, 56, Color(1.0, 0.2, 0.2)))
		boot.add_child(_make_label("Your business went under.", 0, 200, 1080, 50, 28, Color(0.8, 0.5, 0.5)))
	boot.add_child(_make_btn("Back to Menu", 290, 500, 500, 60, Color(0.15, 0.2, 0.25), 26, show_main_menu.bind(boot)))
	boot.add_child(_make_btn("Retry Level", 290, 580, 500, 60, Color(0.2, 0.15, 0.1), 26, _start_gameplay))
