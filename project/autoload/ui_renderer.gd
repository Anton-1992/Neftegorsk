## UIRenderer.gd — v35: ColorRect map + Back button fix
extends Node

var boot = null
var font = null
var gs = null
var sim = null
var current_district_id = ""
var current_level_num = 0
var current_screen = "title"
var ui_timer = 0.0
var car_timer = 0.0
var my_map = []
var my_opponents = []
var my_grid = 8
var my_fuel = 5000
var my_capacity = 5000
var my_price = 50.0
var my_cash = 50000
var my_pumps = 2
var my_time = 8.0
var my_revenue = 0
var my_sold = 0
var my_in_game = false
var player_pos = Vector2i(0, 0)

# Settings
var music_on = true
var sound_on = true

# Screen dimensions
var SW = 1920
var SH = 1080

# Map view reference
var map_view = null
var TW = 64
var TH = 32
var BLOCK_H = 20
var cars = []

# Back button diagnostic
var back_pressed = false

var lbl_cash = null
var lbl_fuel = null
var lbl_price = null
var lbl_time = null
var lbl_msg = null
var lbl_status = null
var lbl_opp = null
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

func _update_screen_size():
	var vp = get_viewport()
	if vp != null:
		var rect = vp.get_visible_rect()
		SW = int(rect.size.x)
		SH = int(rect.size.y)
	if SW < 100:
		SW = 1920
	if SH < 100:
		SH = 1080

func _clear():
	if boot == null:
		return
	map_view = null
	var ch = boot.get_children()
	for c in ch:
		boot.remove_child(c)
		c.free()

	cars = []

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
	bg.size = Vector2(SW, SH)
	bg.position = Vector2(0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

# ==================== ISOMETRIC HELPERS ====================

# ==================== PROCESS ====================

func _process(delta):
	_update_screen_size()
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if current_screen != "gameplay" or not my_in_game:
		return
	ui_timer += delta
	car_timer += delta
	if ui_timer < 1.5:
		_update_cars(delta)
		return
	ui_timer = 0.0
	_sim_tick()
	_refresh_labels()
	_spawn_car()
	_update_cars(delta)

# ==================== CAR SYSTEM ====================

func _iso_to_screen(gx, gy, cx, cy):
	var sx = cx + (gx - gy) * TW / 2
	var sy = cy + (gx + gy) * TH / 2
	return Vector2(sx, sy)

func _find_road_path(start_x, start_y, end_x, end_y):
	var sz = my_grid
	if start_x < 0 or start_x >= sz or start_y < 0 or start_y >= sz:
		return []
	if end_x < 0 or end_x >= sz or end_y < 0 or end_y >= sz:
		return []
	var visited = {}
	var queue = [[start_x, start_y, []]]
	visited[str(start_x) + "," + str(start_y)] = true
	var dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]]
	while queue.size() > 0:
		var item = queue.pop_front()
		var cx = item[0]
		var cy = item[1]
		var path = item[2]
		var new_path = path.duplicate()
		new_path.append(Vector2i(cx, cy))
		if cx == end_x and cy == end_y:
			return new_path
		for d in dirs:
			var nx = cx + d[0]
			var ny = cy + d[1]
			var key = str(nx) + "," + str(ny)
			if nx >= 0 and nx < sz and ny >= 0 and ny < sz and not visited.has(key):
				var tt = 0
				if my_map.size() > ny and my_map[ny].size() > nx:
					tt = my_map[ny][nx]
				if tt == 1 or tt == 5 or tt == 6:
					visited[key] = true
					queue.append([nx, ny, new_path])
	return []

func _spawn_car():
	if cars.size() >= 5:
		return
	if my_map.size() == 0:
		return
	var sz = my_grid
	# Collect all station positions (player + opponents)
	var stations = []
	stations.append(player_pos)
	for opp in my_opponents:
		if opp.stations_count > 0:
			# Find enemy station on map
			for y in range(sz):
				for x in range(sz):
					if my_map.size() > y and my_map[y].size() > x and my_map[y][x] == 6:
						stations.append(Vector2i(x, y))
	# Pick a random destination
	if stations.size() == 0:
		return
	var dest = stations[randi() % stations.size()]
	var edges = []
	for x in range(sz):
		if my_map.size() > 0 and my_map[0].size() > x and my_map[0][x] == 1:
			edges.append(Vector2i(x, 0))
		if my_map.size() > sz - 1 and my_map[sz - 1].size() > x and my_map[sz - 1][x] == 1:
			edges.append(Vector2i(x, sz - 1))
	for y in range(sz):
		if my_map.size() > y and my_map[y].size() > 0 and my_map[y][0] == 1:
			edges.append(Vector2i(0, y))
		if my_map.size() > y and my_map[y].size() > sz - 1 and my_map[y][sz - 1] == 1:
			edges.append(Vector2i(sz - 1, y))
	if edges.size() == 0:
		return
	var edge = edges[randi() % edges.size()]
	var path = _find_road_path(edge.x, edge.y, dest.x, dest.y)
	if path.size() < 2:
		return
	# Cars to player = warm colors, to enemy = cool colors
	var car_color = Color(0.9, 0.8, 0.2)
	if dest == player_pos:
		# Warm colors for player station
		var r = randi() % 3
		if r == 0:
			car_color = Color(0.9, 0.8, 0.2)
		elif r == 1:
			car_color = Color(0.9, 0.5, 0.2)
		else:
			car_color = Color(0.2, 0.8, 0.3)
	else:
		# Cool colors for enemy station
		var r = randi() % 3
		if r == 0:
			car_color = Color(0.2, 0.5, 0.9)
		elif r == 1:
			car_color = Color(0.7, 0.2, 0.8)
		else:
			car_color = Color(0.9, 0.9, 0.9)
	cars.append({
		"path": path,
		"step": 0,
		"t": 0.0,
		"speed": 1.5 + randf() * 1.0,
		"color": car_color,
		"node": null,
		"dest": dest,
	})

func _update_cars(delta):
	if map_view == null:
		return
	map_view.car_data = []
	var map_w = my_grid * TW
	var mcx = map_w / 2
	var mcy = TH
	for car in cars:
		car.t += delta * car.speed
		if car.t >= 1.0:
			car.t = 0.0
			car.step += 1
		if car.step >= car.path.size() - 1:
			car.step = -1
			continue
		if car.step < 0:
			continue
		var from = car.path[car.step]
		var to = car.path[car.step + 1]
		var t = car.t
		var gx = from.x + (to.x - from.x) * t
		var gy = from.y + (to.y - from.y) * t
		var spos = _iso_to_screen(gx, gy, mcx, mcy)
		map_view.car_data.append({"x": spos.x, "y": spos.y, "color": car.color})
	var alive = []
	for car in cars:
		if car.step >= 0:
			alive.append(car)
	cars = alive
	map_view.request_redraw()

# ==================== SIMULATION ====================

func _sim_tick():
	var g = _get_gs()
	if g != null:
		my_cash = g.cash
	my_time += 1.0
	var h = int(my_time) % 24
	var demand = 0.35
	if h >= 7 and h <= 9:
		demand = 0.8
	elif h >= 12 and h <= 14:
		demand = 0.7
	elif h >= 17 and h <= 19:
		demand = 0.85
	elif h >= 22 or h <= 5:
		demand = 0.15
	var base = 8.0 * demand * float(my_pumps)
	var actual = min(int(base), my_fuel)
	if actual > 0:
		my_fuel -= actual
		var income = int(actual * my_price)
		my_cash += income
		my_revenue += income
		my_sold += actual
		if g != null:
			g.cash = my_cash
	for opp in my_opponents:
		if opp.stations_count > 0 and randf() < 0.3:
			opp.price += (randf() - 0.5) * 3.0
			if opp.price < 40.0:
				opp.price = 40.0
			if opp.price > 80.0:
				opp.price = 80.0
	if my_cash < -10000:
		my_in_game = false
		show_result(false, 0, 0)

func _refresh_labels():
	if lbl_cash != null:
		lbl_cash.text = "Cash: " + str(my_cash) + " R"
	if lbl_fuel != null:
		lbl_fuel.text = "Fuel: " + str(my_fuel) + "/" + str(my_capacity) + " L"
	if lbl_price != null:
		lbl_price.text = "Price: " + str(int(my_price)) + " R/L"
	if lbl_time != null:
		var h = int(my_time) % 24
		lbl_time.text = "Time: " + str(h) + ":00"
	if lbl_status != null:
		var h = int(my_time) % 24
		var p = "Night"
		if h >= 7 and h <= 9:
			p = "MORNING RUSH!"
		elif h >= 12 and h <= 14:
			p = "LUNCH RUSH!"
		elif h >= 17 and h <= 19:
			p = "EVENING RUSH!"
		elif h >= 6 and h <= 22:
			p = "Daytime"
		lbl_status.text = p + " | Pumps:" + str(my_pumps)
	if lbl_revenue != null:
		lbl_revenue.text = "Revenue: " + str(my_revenue) + " R"
	if lbl_fuel_sold != null:
		lbl_fuel_sold.text = "Sold: " + str(my_sold) + " L"
	if lbl_opp != null:
		var t = ""
		for opp in my_opponents:
			if opp.stations_count > 0:
				t += opp.name + " Price:" + str(int(opp.price)) + "R  "
		lbl_opp.text = t

# ==================== TITLE SCREEN ====================

func show_main_menu(boot_node):
	boot = boot_node
	_load_font()
	_update_screen_size()
	_clear()
	current_screen = "title"
	boot.add_child(_bg(Color(0.04, 0.05, 0.09)))
	# Title
	boot.add_child(_lbl("NEFTEGORSK", 0, 60, SW, 100, 72, Color(1, 0.85, 0.2)))
	boot.add_child(_lbl("Fuel Empire", 0, 150, SW, 40, 28, Color(0.6, 0.6, 0.7)))
	# Big PLAY button — center of screen
	var play_w = 500
	var play_h = 120
	var play_x = (SW - play_w) / 2
	var play_y = 260
	boot.add_child(_btn("PLAY", play_x, play_y, play_w, play_h, Color(0.12, 0.45, 0.18), 52, _show_district_select))
	# Stats below play button
	var g = _get_gs()
	var cash_str = "0"
	var stars_str = "0"
	if g != null:
		cash_str = str(g.cash)
		stars_str = str(g.total_stars)
	boot.add_child(_lbl("Money: " + cash_str + " R  |  Stars: " + stars_str, 0, play_y + play_h + 20, SW, 30, 20, Color(0.5, 0.5, 0.6)))
	# Settings + Achievements — big buttons below PLAY
	var btn_w = 350
	var btn_h = 80
	var btn_gap = 40
	var btn_y = play_y + play_h + 70
	var btn_x1 = SW / 2 - btn_w - btn_gap / 2
	var btn_x2 = SW / 2 + btn_gap / 2
	boot.add_child(_btn("Settings", btn_x1, btn_y, btn_w, btn_h, Color(0.15, 0.15, 0.25), 28, _show_settings))
	boot.add_child(_btn("Achievements", btn_x2, btn_y, btn_w, btn_h, Color(0.2, 0.15, 0.08), 28, _show_achievements))
	# Version
	boot.add_child(_lbl("v35", 0, SH - 40, SW, 30, 14, Color(0.3, 0.3, 0.4)))

# ==================== SETTINGS ====================

func _show_settings():
	_clear()
	_update_screen_size()
	current_screen = "settings"
	boot.add_child(_bg(Color(0.04, 0.05, 0.09)))
	var cx = (SW - 600) / 2
	var cy = 30
	boot.add_child(_btn("<< Back", cx, cy, 600, 60, Color(0.2, 0.25, 0.3), 28, show_main_menu.bind(boot)))
	cy += 75
	boot.add_child(_lbl("Settings", cx, cy, 600, 50, 38, Color(1, 0.9, 0.3)))
	cy += 65
	# Music
	var music_text = "Music: ON"
	var music_color = Color(0.12, 0.3, 0.15)
	if not music_on:
		music_text = "Music: OFF"
		music_color = Color(0.3, 0.12, 0.12)
	boot.add_child(_btn(music_text, cx, cy, 600, 60, music_color, 24, _toggle_music))
	cy += 80
	# Sound
	var sound_text = "Sound: ON"
	var sound_color = Color(0.12, 0.3, 0.15)
	if not sound_on:
		sound_text = "Sound: OFF"
		sound_color = Color(0.3, 0.12, 0.12)
	boot.add_child(_btn(sound_text, cx, cy, 600, 60, sound_color, 24, _toggle_sound))
	cy += 100
	# Save
	boot.add_child(_btn("Save Game", cx, cy, 600, 60, Color(0.12, 0.18, 0.12), 24, _on_save))
	cy += 80
	# Reset
	boot.add_child(_btn("Reset Progress", cx, cy, 600, 60, Color(0.35, 0.1, 0.1), 24, _on_reset))
	cy += 100
	boot.add_child(_lbl("All progress will be lost on reset!", cx, cy, 600, 30, 16, Color(0.6, 0.4, 0.4)))

func _toggle_music():
	music_on = not music_on
	_show_settings()

func _toggle_sound():
	sound_on = not sound_on
	_show_settings()

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

# ==================== ACHIEVEMENTS ====================

func _show_achievements():
	_clear()
	_update_screen_size()
	current_screen = "achievements"
	boot.add_child(_bg(Color(0.04, 0.05, 0.09)))
	var cx = (SW - 700) / 2
	boot.add_child(_btn("<< Back", cx, 30, 700, 60, Color(0.2, 0.25, 0.3), 28, show_main_menu.bind(boot)))
	boot.add_child(_lbl("Achievements", cx + 200, 95, 500, 50, 38, Color(1, 0.9, 0.3)))
	var g = _get_gs()
	if g == null:
		boot.add_child(_lbl("GameState not available!", cx, 100, 700, 40, 24, Color(1, 0.3, 0.3)))
		return
	var y = 100
	# Total stats
	boot.add_child(_lbl("Total Stars: " + str(g.total_stars), cx, y, 700, 30, 24, Color(1, 0.9, 0.3), false))
	y += 40
	boot.add_child(_lbl("Cash: " + str(g.cash) + " R", cx, y, 700, 30, 24, Color(0.7, 0.9, 0.7), false))
	y += 40
	# Count completed levels
	var total_done = 0
	var total_levels = 0
	for key in g.completed_levels:
		if g.completed_levels[key] > 0:
			total_done += 1
	for d_id in g.district_levels_count:
		total_levels += g.district_levels_count[d_id]
	boot.add_child(_lbl("Levels Completed: " + str(total_done) + " / " + str(total_levels), cx, y, 700, 30, 24, Color(0.6, 0.8, 1.0), false))
	y += 40
	var unlocked_count = g.unlocked_districts.size()
	boot.add_child(_lbl("Districts Unlocked: " + str(unlocked_count) + " / 10", cx, y, 700, 30, 24, Color(0.8, 0.7, 0.9), false))
	y += 40
	boot.add_child(_lbl("Upgrades Owned: " + str(g.owned_upgrades.size()), cx, y, 700, 30, 24, Color(0.7, 0.9, 0.7), false))
	y += 60
	# Per-district progress
	boot.add_child(_lbl("-- District Progress --", cx, y, 700, 30, 22, Color(0.6, 0.6, 0.7)))
	y += 35
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	for d_id in order:
		var d_name = g.district_names.get(d_id, d_id)
		var lc = g.district_levels_count.get(d_id, 0)
		var done = 0
		for i in range(1, lc + 1):
			var key = d_id + "_" + str(i)
			if g.completed_levels.has(key) and g.completed_levels[key] > 0:
				done += 1
		var unlocked = g.is_district_unlocked(d_id)
		var status = str(done) + "/" + str(lc)
		if not unlocked:
			status = "LOCKED"
		boot.add_child(_lbl(d_name + ":  " + status, cx, y, 700, 26, 20, Color(0.7, 0.7, 0.8), false))
		y += 30

# ==================== DISTRICT SELECT ====================

func _show_district_select():
	_clear()
	_update_screen_size()
	current_screen = "district_select"
	boot.add_child(_bg())
	boot.add_child(_btn("<< Back", 20, 20, 250, 55, Color(0.2, 0.25, 0.3), 26, show_main_menu.bind(boot)))
	boot.add_child(_lbl("Select District", 220, 20, SW - 440, 50, 38, Color(1, 0.9, 0.3)))
	var g = _get_gs()
	var cash_str = "0"
	var stars_str = "0"
	if g != null:
		cash_str = str(g.cash)
		stars_str = str(g.total_stars)
	var col_w = SW / 2 - 40
	var left_x = 20
	var right_x = SW / 2 + 20
	boot.add_child(_lbl("Money: " + cash_str + " R", left_x, 80, col_w / 2, 30, 20, Color(0.7, 0.9, 0.7), false))
	boot.add_child(_lbl("Stars: " + stars_str, left_x + col_w / 2, 80, col_w / 2, 30, 20, Color(1, 0.9, 0.3), false))
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	var y_left = 115
	var y_right = 115
	var col = 0
	for d_id in order:
		if g == null:
			break
		var d_name = g.district_names.get(d_id, d_id)
		var unlocked = g.is_district_unlocked(d_id)
		var req = g.district_req_stars.get(d_id, 0)
		var lc = g.district_levels_count.get(d_id, 0)
		var dc = g.district_colors.get(d_id, Color(0.2, 0.2, 0.3))
		var cx = left_x
		var cy = y_left
		if col == 1:
			cx = right_x
			cy = y_right
		if unlocked:
			var done = 0
			for i in range(1, lc + 1):
				var key = d_id + "_" + str(i)
				if g.completed_levels.has(key) and g.completed_levels[key] > 0:
					done += 1
			var t = d_name + "  [" + str(done) + "/" + str(lc) + "]"
			boot.add_child(_btn(t, cx, cy, col_w, 55, dc, 20, _on_district, d_id))
		else:
			boot.add_child(_lbl(d_name + "  [Need " + str(req) + " stars]", cx, cy, col_w, 55, 18, Color(0.35, 0.35, 0.4), false))
		if col == 0:
			y_left += 62
		else:
			y_right += 62
		col = 1 - col
	var max_y = max(y_left, y_right)
	max_y += 15
	boot.add_child(_btn("Upgrade Shop", left_x, max_y, col_w, 50, Color(0.15, 0.12, 0.25), 22, _show_upgrade_shop))

func _on_district(d_id):
	current_district_id = d_id
	_show_level_select()

# ==================== LEVEL SELECT ====================

func _show_level_select():
	_clear()
	_update_screen_size()
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
	var content_w = min(SW - 40, 1000)
	var cx = (SW - content_w) / 2
	boot.add_child(_btn("<< Back", cx, 20, 250, 55, Color(0.2, 0.25, 0.3), 26, _show_district_select))
	boot.add_child(_lbl(d_name, cx + 200, 20, content_w - 200, 50, 38, Color(1, 0.9, 0.3)))
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
			boot.add_child(_btn(t, cx, y, content_w, 55, c, 22, _on_level, i))
		else:
			boot.add_child(_lbl("Level " + str(i) + "  [Locked]", cx, y, content_w, 55, 18, Color(0.35, 0.35, 0.4), false))
		y += 62

func _on_level(num):
	current_level_num = num
	_gen_map()
	show_gameplay(boot)

# ==================== MAP GENERATION ====================

func _gen_map():
	var g = _get_gs()
	my_cash = 50000
	my_capacity = 5000
	my_pumps = 2
	my_grid = 8
	if g != null:
		my_cash = g.cash
		my_capacity = g.player_fuel_capacity
		my_pumps = g.player_pumps
		my_grid = g.district_grid_sizes.get(current_district_id, 8)
	my_fuel = my_capacity
	my_price = 50.0
	my_time = 8.0
	my_revenue = 0
	my_sold = 0
	my_in_game = true
	ui_timer = 0.0
	car_timer = 0.0
	cars = []
	var rng = RandomNumberGenerator.new()
	rng.seed = current_level_num * 12345 + current_district_id.hash()
	var sz = my_grid
	my_map = []
	for y in range(sz):
		var row = []
		for x in range(sz):
			row.append(0)
		my_map.append(row)
	var hc = 2
	if current_level_num > 2:
		hc = 3
	for i in range(hc):
		var ry = rng.randi_range(1, sz - 2)
		for x in range(sz):
			my_map[ry][x] = 1
	for i in range(hc):
		var rx = rng.randi_range(1, sz - 2)
		for y in range(sz):
			my_map[y][rx] = 1
	for y in range(sz):
		for x in range(sz):
			if my_map[y][x] == 0:
				var near = false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var ny = y + dy
						var nx = x + dx
						if ny >= 0 and ny < sz and nx >= 0 and nx < sz and my_map[ny][nx] == 1:
							near = true
				if near and rng.randf() < 0.55:
					my_map[y][x] = 2
	var px = sz / 2
	var py = sz / 2
	for y in range(sz):
		for x in range(sz):
			if my_map[y][x] == 1 and abs(x - sz / 2) <= 2 and abs(y - sz / 2) <= 2:
				px = x
				py = y
				break
	my_map[py][px] = 5
	player_pos = Vector2i(px, py)
	my_opponents = []
	var oc = min(current_level_num, 3)
	var names = ["Akula", "Skupoy", "Opportunist"]
	var loy = [0.7, 1.8, 1.0]
	for i in range(oc):
		for attempt in range(30):
			var ox = rng.randi_range(1, sz - 2)
			var oy = rng.randi_range(1, sz - 2)
			if my_map[oy][ox] == 1 and (abs(ox - px) + abs(oy - py)) >= 3:
				my_map[oy][ox] = 6
				my_opponents.append({
					"id": i,
					"name": names[i % 3],
					"price": 50.0 + (i - 1) * 5.0,
					"loyalty": loy[i % 3],
					"stations_count": 1,
				})
				break
	var s = _get_sim()
	if s != null:
		s.in_game = true
		s.fuel_price = my_price
		s.fuel_stored = my_fuel
		s.grid_size = my_grid
		s.map_tiles = my_map
		s.opponents = my_opponents
		s.game_time = my_time
		s.revenue = my_revenue
		s.fuel_sold = my_sold
		s.current_district = current_district_id
		s.current_level_num = current_level_num

# ==================== ISOMETRIC GAMEPLAY ====================

func show_gameplay(boot_node):
	boot = boot_node
	_load_font()
	_update_screen_size()
	_clear()
	current_screen = "gameplay"
	var g = _get_gs()
	var sz = my_grid

	# Isometric tile size — map fills most of screen
	var top_bar_h = 80
	var bot_bar_h = 140
	var map_area_w = SW - 20
	var map_area_h = SH - top_bar_h - bot_bar_h - 20
	TW = int(map_area_w / sz)
	TH = TW / 2
	var total_map_h = sz * TH + BLOCK_H + 20
	if total_map_h > map_area_h:
		TH = int((map_area_h - BLOCK_H - 20) / sz)
		TW = TH * 2
	TW = max(TW, 30)
	TH = max(TH, 15)

	boot.add_child(_bg(Color(0.02, 0.03, 0.06)))

	# ---- ISOMETRIC MAP (fills screen) ----
	var map_w = sz * TW
	var map_h = sz * TH + BLOCK_H + 20
	var map_x = (SW - map_w) / 2
	var map_y = top_bar_h + (SH - top_bar_h - bot_bar_h - map_h) / 2

	# Load map_view scene
	var mv_scene = load("res://scenes/map_view.tscn")
	var mv = mv_scene.instantiate()
	mv.position = Vector2(map_x, map_y)
	mv.size = Vector2(map_w, map_h)
	mv.TW = TW
	mv.TH = TH
	if font != null:
		mv.font = font
	boot.add_child(mv)
	map_view = mv

	var mcx = map_w / 2
	var mcy = TH

	var dc = Color(0.2, 0.2, 0.3)
	if g != null:
		dc = g.district_colors.get(current_district_id, dc)

	for depth in range(0, sz * 2):
		for gx in range(0, sz):
			var gy = depth - gx
			if gy < 0 or gy >= sz:
				continue
			var tt = 0
			if my_map.size() > gy and my_map[gy].size() > gx:
				tt = my_map[gy][gx]
			var spos = _iso_to_screen(gx, gy, mcx, mcy)
			var top_color = Color(dc.r * 0.4, dc.g * 0.4, dc.b * 0.4)
			var left_color = Color(dc.r * 0.3, dc.g * 0.3, dc.b * 0.3)
			var right_color = Color(dc.r * 0.25, dc.g * 0.25, dc.b * 0.25)
			var bh = 0
			var label_text = ""
			var label_color = Color(0.8, 0.8, 0.8)
			if tt == 0:
				top_color = Color(dc.r * 0.35, dc.g * 0.35, dc.b * 0.35)
				left_color = Color(dc.r * 0.25, dc.g * 0.25, dc.b * 0.25)
				right_color = Color(dc.r * 0.2, dc.g * 0.2, dc.b * 0.2)
				bh = 2
			elif tt == 1:
				top_color = Color(0.35, 0.35, 0.4)
				left_color = Color(0.25, 0.25, 0.3)
				right_color = Color(0.2, 0.2, 0.25)
			elif tt == 2:
				top_color = Color(dc.r + 0.2, dc.g + 0.12, dc.b + 0.06)
				left_color = Color(dc.r + 0.1, dc.g + 0.06, dc.b + 0.03)
				right_color = Color(dc.r + 0.05, dc.g + 0.03, dc.b + 0.01)
				bh = BLOCK_H
				label_text = "B"
				label_color = Color(0.6, 0.5, 0.4)
			elif tt == 5:
				top_color = Color(0.15, 0.65, 0.2)
				left_color = Color(0.1, 0.45, 0.15)
				right_color = Color(0.08, 0.35, 0.12)
				bh = BLOCK_H / 2
				label_text = "P"
				label_color = Color(1, 1, 1)
			elif tt == 6:
				top_color = Color(0.75, 0.15, 0.15)
				left_color = Color(0.5, 0.1, 0.1)
				right_color = Color(0.4, 0.08, 0.08)
				bh = BLOCK_H / 2
				label_text = "E"
				label_color = Color(1, 1, 1)
			map_view.tiles.append({
				"x": spos.x, "y": spos.y,
				"tc": top_color, "lc": left_color, "rc": right_color,
				"bh": bh
			})
			if label_text != "":
				map_view.labels.append({
					"x": spos.x, "y": spos.y - bh / 2,
				"text": label_text, "fs": max(TW / 4, 10),
				"color": label_color
			})
	map_view.request_redraw()

	# ---- TOP BAR (data + Back) ----
	var tb = ColorRect.new()
	tb.color = Color(0.06, 0.07, 0.12, 0.9)
	tb.position = Vector2(0, 0)
	tb.size = Vector2(SW, top_bar_h)
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(tb)

	# BACK BUTTON — top-left, VERY prominent
	boot.add_child(_btn("BACK", 10, 10, 180, 60, Color(0.5, 0.1, 0.1), 28, _on_back))

	var d_name = ""
	if g != null:
		d_name = g.district_names.get(current_district_id, "")
	boot.add_child(_lbl(d_name + " Lv." + str(current_level_num), 200, 10, 400, 30, 22, Color(1, 0.9, 0.3)))
	lbl_cash = _lbl("Cash: " + str(my_cash) + " R", 200, 42, 300, 26, 18, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_cash)
	lbl_fuel = _lbl("Fuel: " + str(my_fuel) + "/" + str(my_capacity) + " L", 500, 42, 300, 26, 18, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel)
	lbl_price = _lbl("Price: " + str(int(my_price)) + " R/L", 800, 42, 200, 26, 18, Color(1, 0.9, 0.3), false)
	boot.add_child(lbl_price)
	lbl_time = _lbl("Time: 8:00", 1020, 10, 200, 26, 18, Color(0.5, 0.5, 0.6), false)
	boot.add_child(lbl_time)
	lbl_revenue = _lbl("Rev: 0R", 1020, 42, 200, 26, 18, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_revenue)
	lbl_fuel_sold = _lbl("Sold: 0L", 1240, 42, 200, 26, 18, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel_sold)
	lbl_status = _lbl("", 1240, 10, 300, 26, 16, Color(0.8, 0.7, 0.3), false)
	boot.add_child(lbl_status)
	lbl_msg = _lbl("", 600, 10, 400, 26, 16, Color(0.6, 0.6, 0.6), false)
	boot.add_child(lbl_msg)

	# ---- BOTTOM BAR (action buttons) ----
	var bb = ColorRect.new()
	bb.color = Color(0.06, 0.07, 0.12, 0.9)
	bb.position = Vector2(0, SH - bot_bar_h)
	bb.size = Vector2(SW, bot_bar_h)
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(bb)

	var by = SH - bot_bar_h + 10
	var bw = 220
	var bh2 = 50
	var gap = 15
	var bx = 20

	boot.add_child(_btn("Price -5", bx, by, bw, bh2, Color(0.2, 0.15, 0.1), 20, _on_price_down))
	bx += bw + gap
	boot.add_child(_btn("Price +5", bx, by, bw, bh2, Color(0.2, 0.15, 0.1), 20, _on_price_up))
	bx += bw + gap
	boot.add_child(_btn("Buy Fuel 1000L", bx, by, bw, bh2, Color(0.1, 0.2, 0.15), 20, _on_buy))
	bx += bw + gap
	boot.add_child(_btn("Buy MAX", bx, by, bw, bh2, Color(0.1, 0.15, 0.2), 20, _on_buy_max))
	bx += bw + gap
	boot.add_child(_btn("Upgrade Shop", bx, by, bw, bh2, Color(0.12, 0.12, 0.2), 20, _show_upgrade_shop))
	bx += bw + gap
	boot.add_child(_btn("Save", bx, by, 150, bh2, Color(0.12, 0.18, 0.12), 18, _on_save))

	by += bh2 + 10
	bx = 20
	# Opponents
	lbl_opp = _lbl("", bx, by, SW, 22, 16, Color(0.9, 0.6, 0.3), false)
	boot.add_child(lbl_opp)
	by += 24
	for opp in my_opponents:
		if opp.stations_count > 0:
			var bp = 60000 + current_level_num * 15000
			bp = int(bp * opp.loyalty)
			var ot = opp.name + " " + str(int(opp.price)) + "R/L BUYOUT:" + str(bp) + "R"
			boot.add_child(_btn(ot, bx, by, 500, 40, Color(0.2, 0.08, 0.08), 16, _on_buyout, opp.id))
			bx += 520

	# Legend
	boot.add_child(_lbl("P=You  E=Enemy  B=Building  Gray=Road  Warm cars=To you  Cool cars=To enemy", 0, SH - 20, SW, 20, 12, Color(0.3, 0.3, 0.4)))

func _on_back():
	back_pressed = true
	my_in_game = false
	cars = []
	map_view = null
	var s = _get_sim()
	if s != null:
		s.in_game = false
	show_main_menu(boot)

func _on_price_up():
	my_price = min(my_price + 5.0, 85.0)
	var s = _get_sim()
	if s != null:
		s.fuel_price = my_price
	_refresh_labels()

func _on_price_down():
	my_price = max(my_price - 5.0, 35.0)
	var s = _get_sim()
	if s != null:
		s.fuel_price = my_price
	_refresh_labels()

func _on_buy():
	var cost = int(1000 * 42.5)
	if my_cash >= cost:
		my_cash -= cost
		my_fuel = min(my_fuel + 1000, my_capacity)
		if lbl_msg != null:
			lbl_msg.text = "Bought 1000L for " + str(cost) + "R"
	else:
		if lbl_msg != null:
			lbl_msg.text = "Not enough cash!"
	var g = _get_gs()
	if g != null:
		g.cash = my_cash
	_refresh_labels()

func _on_buy_max():
	var space = my_capacity - my_fuel
	if space <= 0:
		if lbl_msg != null:
			lbl_msg.text = "Tank is full!"
		return
	var cost = int(space * 42.5)
	if my_cash >= cost:
		my_cash -= cost
		my_fuel += space
		if lbl_msg != null:
			lbl_msg.text = "Bought " + str(space) + "L for " + str(cost) + "R"
	else:
		var can = int(my_cash / 42.5)
		if can > 0:
			my_cash -= int(can * 42.5)
			my_fuel += can
			if lbl_msg != null:
				lbl_msg.text = "Bought " + str(can) + "L"
		else:
			if lbl_msg != null:
				lbl_msg.text = "Not enough cash!"
	var g = _get_gs()
	if g != null:
		g.cash = my_cash
	_refresh_labels()

func _on_buyout(opp_id):
	var bp = 60000 + current_level_num * 15000
	for opp in my_opponents:
		if opp.id == opp_id and opp.stations_count > 0:
			bp = int(bp * opp.loyalty)
			if my_cash >= bp:
				my_cash -= bp
				opp.stations_count = 0
				if lbl_msg != null:
					lbl_msg.text = "Bought out " + opp.name + " for " + str(bp) + "R!"
				var remaining = 0
				for o in my_opponents:
					if o.stations_count > 0:
						remaining += 1
				if remaining == 0:
					my_in_game = false
					var g = _get_gs()
					if g != null:
						g.cash = my_cash
						g.total_stars += 3
						g.save_game()
					show_result(true, 3, 3)
					return
			else:
				if lbl_msg != null:
					lbl_msg.text = "Need " + str(bp) + "R!"
	var g = _get_gs()
	if g != null:
		g.cash = my_cash
	_refresh_labels()

func update_gameplay_ui():
	_refresh_labels()

# ==================== UPGRADE SHOP ====================

func _show_upgrade_shop():
	_clear()
	_update_screen_size()
	current_screen = "upgrade_shop"
	boot.add_child(_bg(Color(0.05, 0.05, 0.1)))
	var content_w = min(SW - 40, 1200)
	var cx = (SW - content_w) / 2
	boot.add_child(_btn("<< Back", cx, 20, 250, 55, Color(0.2, 0.25, 0.3), 26, _on_shop_back))
	boot.add_child(_lbl("Upgrade Shop", cx + 200, 20, content_w - 200, 50, 38, Color(1, 0.9, 0.3)))
	var g = _get_gs()
	if g == null:
		boot.add_child(_lbl("GameState not available!", cx, 100, content_w, 40, 24, Color(1, 0.3, 0.3)))
		return
	boot.add_child(_lbl("Cash: " + str(g.cash) + " R  |  Stars: " + str(g.total_stars), cx, 80, content_w, 30, 20, Color(0.7, 0.9, 0.7), false))
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
			boot.add_child(_lbl("[OWNED] " + un + " - " + ud, cx, y, content_w, 50, 20, Color(0.4, 0.5, 0.4), false))
		else:
			var can = (g.cash >= uc and g.total_stars >= us)
			var bt = un + " - " + ud + " [" + str(uc) + "R, " + str(us) + "*]"
			if can:
				boot.add_child(_btn(bt, cx, y, content_w, 50, cc, 20, _on_buy_upg, uid))
			else:
				boot.add_child(_lbl("[LOCKED] " + bt, cx, y, content_w, 50, 18, Color(0.35, 0.35, 0.4), false))
		y += 58

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
		_show_district_select()

# ==================== WIN/LOSE ====================

func show_result(won, stars, stars_gained):
	_clear()
	_update_screen_size()
	current_screen = "result"
	if won:
		boot.add_child(_bg(Color(0.04, 0.08, 0.06)))
		boot.add_child(_lbl("VICTORY!", 0, 150, SW, 80, 56, Color(0.3, 1.0, 0.3)))
		boot.add_child(_lbl("Stars earned: " + str(stars), 0, 250, SW, 50, 32, Color(1, 0.9, 0.3)))
		var g = _get_gs()
		if g != null:
			boot.add_child(_lbl("Cash: " + str(g.cash) + " R", 0, 310, SW, 40, 24, Color(0.7, 0.9, 0.7)))
			boot.add_child(_lbl("Total Stars: " + str(g.total_stars), 0, 360, SW, 40, 24, Color(1, 0.9, 0.3)))
	else:
		boot.add_child(_bg(Color(0.1, 0.04, 0.04)))
		boot.add_child(_lbl("BANKRUPT!", 0, 150, SW, 80, 56, Color(1.0, 0.2, 0.2)))
		boot.add_child(_lbl("Your business went under.", 0, 250, SW, 50, 28, Color(0.8, 0.5, 0.5)))
	var bw = min(500, SW / 2 - 40)
	var bx = SW / 2 - bw - 10
	boot.add_child(_btn("Back to Menu", bx, 450, bw, 60, Color(0.15, 0.2, 0.25), 26, show_main_menu.bind(boot)))
	boot.add_child(_btn("Retry Level", bx + bw + 20, 450, bw, 60, Color(0.2, 0.15, 0.1), 26, _on_retry))

func _on_retry():
	_gen_map()
	show_gameplay(boot)
