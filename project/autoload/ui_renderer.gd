## UIRenderer.gd — v27: isometric view + animated cars
extends Node

var boot = null
var font = null
var gs = null
var sim = null
var current_district_id = ""
var current_level_num = 0
var current_screen = "main_menu"
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

# Screen dimensions
var SW = 1080
var SH = 1920

# Isometric map references
var map_node = null
var map_svp = null
var cars = []

# Isometric tile size
var TW = 64
var TH = 32
var BLOCK_H = 20

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
		SW = 1080
	if SH < 100:
		SH = 1920

func _clear():
	if boot == null:
		return
	var ch = boot.get_children()
	for c in ch:
		boot.remove_child(c)
		c.free()
	map_node = null
	map_svp = null
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

func _iso_to_screen(gx, gy, cx, cy):
	# Convert grid coords to isometric screen coords
	var sx = cx + (gx - gy) * TW / 2
	var sy = cy + (gx + gy) * TH / 2
	return Vector2(sx, sy)

func _make_diamond(cx, cy, w, h, color):
	var p = Polygon2D.new()
	var verts = PackedVector2Array()
	verts.append(Vector2(0, -h / 2))
	verts.append(Vector2(w / 2, 0))
	verts.append(Vector2(0, h / 2))
	verts.append(Vector2(-w / 2, 0))
	p.polygon = verts
	p.color = color
	p.position = Vector2(cx, cy)
	return p

func _make_left_face(cx, cy, w, h, bh, color):
	var p = Polygon2D.new()
	var verts = PackedVector2Array()
	verts.append(Vector2(-w / 2, 0))
	verts.append(Vector2(0, h / 2))
	verts.append(Vector2(0, h / 2 + bh))
	verts.append(Vector2(-w / 2, bh))
	p.polygon = verts
	p.color = color
	p.position = Vector2(cx, cy)
	return p

func _make_right_face(cx, cy, w, h, bh, color):
	var p = Polygon2D.new()
	var verts = PackedVector2Array()
	verts.append(Vector2(w / 2, 0))
	verts.append(Vector2(0, h / 2))
	verts.append(Vector2(0, h / 2 + bh))
	verts.append(Vector2(w / 2, bh))
	p.polygon = verts
	p.color = color
	p.position = Vector2(cx, cy)
	return p

func _make_label(cx, cy, text, fs, color):
	var l = Label.new()
	l.text = text
	l.position = Vector2(cx - 20, cy - fs / 2)
	l.size = Vector2(40, fs + 4)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = 1
	l.vertical_alignment = 1
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		l.add_theme_font_override("font", font)
	return l

# ==================== PROCESS ====================

func _process(delta):
	_update_screen_size()
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
	var path = _find_road_path(edge.x, edge.y, player_pos.x, player_pos.y)
	if path.size() < 2:
		return
	var car_color = Color(0.9, 0.8, 0.2)
	var r = randi() % 4
	if r == 0:
		car_color = Color(0.9, 0.3, 0.2)
	elif r == 1:
		car_color = Color(0.2, 0.5, 0.9)
	elif r == 2:
		car_color = Color(0.9, 0.9, 0.9)
	elif r == 3:
		car_color = Color(0.2, 0.8, 0.3)
	cars.append({
		"path": path,
		"step": 0,
		"t": 0.0,
		"speed": 1.5 + randf() * 1.0,
		"color": car_color,
		"node": null,
	})

func _update_cars(delta):
	if map_node == null:
		return
	for car in cars:
		car.t += delta * car.speed
		if car.t >= 1.0:
			car.t = 0.0
			car.step += 1
		if car.step >= car.path.size() - 1:
			# Car reached destination
			if car.node != null:
				map_node.remove_child(car.node)
				car.node.free()
				car.node = null
			car.step = -1
			continue
		if car.step < 0:
			continue
		var from = car.path[car.step]
		var to = car.path[car.step + 1]
		var fx = from.x
		var fy = from.y
		var tx = to.x
		var ty = to.y
		var t = car.t
		var gx = fx + (tx - fx) * t
		var gy = fy + (ty - fy) * t
		# Convert to isometric screen position
		var map_w = my_grid * TW
		var map_h = my_grid * TH
		var mcx = map_w / 2
		var mcy = TH
		var spos = _iso_to_screen(gx, gy, mcx, mcy)
		if car.node == null:
			var p = Polygon2D.new()
			var verts = PackedVector2Array()
			verts.append(Vector2(-6, -3))
			verts.append(Vector2(6, -3))
			verts.append(Vector2(6, 3))
			verts.append(Vector2(-6, 3))
			p.polygon = verts
			p.color = car.color
			p.position = spos
			map_node.add_child(p)
			car.node = p
		else:
			car.node.position = spos
	# Remove dead cars
	var alive = []
	for car in cars:
		if car.step >= 0:
			alive.append(car)
		elif car.node != null:
			map_node.remove_child(car.node)
			car.node.free()
	cars = alive

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
		lbl_status.text = p + " | Pumps:" + str(my_pumps) + " | Fuel:" + str(my_fuel) + "L"
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

# ==================== MAIN MENU ====================

func show_main_menu(boot_node):
	boot = boot_node
	_load_font()
	_update_screen_size()
	_clear()
	current_screen = "main_menu"
	boot.add_child(_bg())
	boot.add_child(_lbl("NEFTEGORSK", 0, 30, SW, 80, 56, Color(1, 0.9, 0.3)))
	boot.add_child(_lbl("v27 Isometric", 0, 100, SW, 30, 18, Color(0.5, 0.5, 0.6)))
	var g = _get_gs()
	var cash_str = "0"
	var stars_str = "0"
	if g != null:
		cash_str = str(g.cash)
		stars_str = str(g.total_stars)
	var content_w = min(SW - 40, 1000)
	var cx = (SW - content_w) / 2
	boot.add_child(_lbl("Money: " + cash_str + " R", cx, 150, content_w / 2, 40, 22, Color(0.7, 0.9, 0.7), false))
	boot.add_child(_lbl("Stars: " + stars_str, cx + content_w / 2, 150, content_w / 2, 40, 22, Color(1, 0.9, 0.3), false))
	boot.add_child(_lbl("Select District:", cx, 210, content_w, 40, 24, Color(0.7, 0.7, 0.8), false))
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
			boot.add_child(_btn(t, cx, y, content_w, 65, dc, 22, _on_district, d_id))
		else:
			boot.add_child(_lbl(d_name + "  [Need " + str(req) + " stars]", cx, y, content_w, 65, 20, Color(0.35, 0.35, 0.4), false))
		y += 75
	y += 20
	boot.add_child(_btn("Upgrade Shop", cx, y, content_w, 60, Color(0.15, 0.12, 0.25), 24, _show_upgrade_shop))
	y += 70
	var half_w = content_w / 2 - 10
	boot.add_child(_btn("Save Game", cx, y, half_w, 50, Color(0.12, 0.18, 0.12), 20, _on_save))
	boot.add_child(_btn("Reset", cx + half_w + 20, y, half_w, 50, Color(0.25, 0.1, 0.1), 20, _on_reset))

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
	boot.add_child(_btn("<< Back", cx, 20, 180, 45, Color(0.2, 0.25, 0.3), 22, show_main_menu.bind(boot)))
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
			boot.add_child(_btn(t, cx, y, content_w, 65, c, 22, _on_level, i))
		else:
			boot.add_child(_lbl("Level " + str(i) + "  [Locked]", cx, y, content_w, 65, 20, Color(0.35, 0.35, 0.4), false))
		y += 75

func _on_level(num):
	current_level_num = num
	_gen_map()
	show_gameplay(boot)

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

	# Calculate tile size to fit screen
	var map_area_w = SW - 40
	var map_area_h = SH / 2 - 80
	# Iso map bounding box: width = sz * TW, height = sz * TH + some block height
	TW = int(map_area_w / sz)
	TH = TW / 2
	if sz * TH + BLOCK_H > map_area_h:
		TH = int((map_area_h - BLOCK_H) / sz)
		TW = TH * 2
	TW = max(TW, 20)
	TH = max(TH, 10)

	boot.add_child(_bg(Color(0.02, 0.03, 0.06)))

	# Top bar
	var content_w = min(SW - 40, 1000)
	var cx = (SW - content_w) / 2
	boot.add_child(_btn("<< Back", cx, 10, 120, 36, Color(0.25, 0.15, 0.15), 18, _on_back))
	var d_name = ""
	if g != null:
		d_name = g.district_names.get(current_district_id, "")
	boot.add_child(_lbl(d_name + " Lv." + str(current_level_num), cx + 130, 10, content_w - 260, 36, 22, Color(1, 0.9, 0.3)))
	lbl_cash = _lbl("Cash:" + str(my_cash) + "R", cx + content_w - 200, 10, 200, 36, 18, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_cash)

	# ---- ISOMETRIC MAP using SubViewportContainer ----
	var map_w = sz * TW
	var map_h = sz * TH + BLOCK_H + 20
	var map_x = (SW - map_w) / 2
	var map_y = 52

	# Border
	var brd = ColorRect.new()
	brd.color = Color(0.1, 0.1, 0.15)
	brd.position = Vector2(map_x - 4, map_y - 4)
	brd.size = Vector2(map_w + 8, map_h + 8)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(brd)

	# SubViewportContainer
	var svc = SubViewportContainer.new()
	svc.position = Vector2(map_x, map_y)
	svc.size = Vector2(map_w, map_h)
	svc.stretch = true
	boot.add_child(svc)

	# SubViewport
	var svp = SubViewport.new()
	svp.size = Vector2(map_w, map_h)
	svp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(svp)
	map_svp = svp

	# Map root Node2D
	var root = Node2D.new()
	svp.add_child(root)
	map_node = root

	# Center of isometric grid
	var mcx = map_w / 2
	var mcy = TH

	# District color
	var dc = Color(0.2, 0.2, 0.3)
	if g != null:
		dc = g.district_colors.get(current_district_id, dc)

	# Draw tiles back-to-front (sorted by gx+gy)
	for depth in range(0, sz * 2):
		for gx in range(0, sz):
			var gy = depth - gx
			if gy < 0 or gy >= sz:
				continue
			var tt = 0
			if my_map.size() > gy and my_map[gy].size() > gx:
				tt = my_map[gy][gx]
			var spos = _iso_to_screen(gx, gy, mcx, mcy)

			# Tile colors
			var top_color = Color(dc.r * 0.4, dc.g * 0.4, dc.b * 0.4)
			var left_color = Color(dc.r * 0.3, dc.g * 0.3, dc.b * 0.3)
			var right_color = Color(dc.r * 0.25, dc.g * 0.25, dc.b * 0.25)
			var bh = 0
			var label_text = ""
			var label_color = Color(0.8, 0.8, 0.8)

			if tt == 0:
				# Empty ground
				top_color = Color(dc.r * 0.35, dc.g * 0.35, dc.b * 0.35)
				left_color = Color(dc.r * 0.25, dc.g * 0.25, dc.b * 0.25)
				right_color = Color(dc.r * 0.2, dc.g * 0.2, dc.b * 0.2)
				bh = 2
			elif tt == 1:
				# Road
				top_color = Color(0.35, 0.35, 0.4)
				left_color = Color(0.25, 0.25, 0.3)
				right_color = Color(0.2, 0.2, 0.25)
				bh = 0
			elif tt == 2:
				# Building
				top_color = Color(dc.r + 0.2, dc.g + 0.12, dc.b + 0.06)
				left_color = Color(dc.r + 0.1, dc.g + 0.06, dc.b + 0.03)
				right_color = Color(dc.r + 0.05, dc.g + 0.03, dc.b + 0.01)
				bh = BLOCK_H
				label_text = "B"
				label_color = Color(0.6, 0.5, 0.4)
			elif tt == 5:
				# Player station
				top_color = Color(0.15, 0.65, 0.2)
				left_color = Color(0.1, 0.45, 0.15)
				right_color = Color(0.08, 0.35, 0.12)
				bh = BLOCK_H / 2
				label_text = "P"
				label_color = Color(1, 1, 1)
			elif tt == 6:
				# Enemy station
				top_color = Color(0.75, 0.15, 0.15)
				left_color = Color(0.5, 0.1, 0.1)
				right_color = Color(0.4, 0.08, 0.08)
				bh = BLOCK_H / 2
				label_text = "E"
				label_color = Color(1, 1, 1)

			# Draw left face (if block height > 0)
			if bh > 0:
				var lf = _make_left_face(spos.x, spos.y, TW, TH, bh, left_color)
				root.add_child(lf)
				var rf = _make_right_face(spos.x, spos.y, TW, TH, bh, right_color)
				root.add_child(rf)

			# Draw top face
			var diamond = _make_diamond(spos.x, spos.y, TW, TH, top_color)
			root.add_child(diamond)

			# Draw label
			if label_text != "":
				var lbl = _make_label(spos.x, spos.y - bh / 2, label_text, max(TW / 4, 10), label_color)
				root.add_child(lbl)

	# Map legend
	var cy = map_y + map_h + 4
	boot.add_child(_lbl("P=You  E=Enemy  B=Building  Gray=Road  Cars=Yellow/Red/Blue", cx, cy, content_w, 22, 13, Color(0.5, 0.5, 0.5), false))
	cy += 28

	# Fuel info
	boot.add_child(_lbl("-- Fuel Station --", cx, cy, content_w, 26, 18, Color(0.5, 0.5, 0.6)))
	cy += 28
	var map_ctrl_w = content_w
	lbl_fuel = _lbl("Fuel: " + str(my_fuel) + "/" + str(my_capacity) + " L", cx, cy, map_ctrl_w / 2, 26, 18, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel)
	lbl_price = _lbl("Price: " + str(int(my_price)) + " R/L", cx + map_ctrl_w / 2, cy, map_ctrl_w / 2, 26, 18, Color(1, 0.9, 0.3), false)
	boot.add_child(lbl_price)
	cy += 30
	var bw = map_ctrl_w / 4 - 6
	boot.add_child(_btn("Price -5", cx, cy, bw, 44, Color(0.2, 0.15, 0.1), 18, _on_price_down))
	boot.add_child(_btn("Price +5", cx + bw + 8, cy, bw, 44, Color(0.2, 0.15, 0.1), 18, _on_price_up))
	boot.add_child(_btn("Buy Fuel", cx + bw * 2 + 16, cy, bw, 44, Color(0.1, 0.2, 0.15), 18, _on_buy))
	boot.add_child(_btn("Buy MAX", cx + bw * 3 + 24, cy, bw, 44, Color(0.1, 0.15, 0.2), 18, _on_buy_max))
	cy += 50
	lbl_time = _lbl("Time: 8:00", cx, cy, map_ctrl_w / 3, 26, 18, Color(0.5, 0.5, 0.6), false)
	boot.add_child(lbl_time)
	lbl_revenue = _lbl("Revenue: 0 R", cx + map_ctrl_w / 3, cy, map_ctrl_w / 3, 26, 18, Color(0.7, 0.9, 0.7), false)
	boot.add_child(lbl_revenue)
	lbl_fuel_sold = _lbl("Sold: 0 L", cx + map_ctrl_w * 2 / 3, cy, map_ctrl_w / 3, 26, 18, Color(0.6, 0.8, 1.0), false)
	boot.add_child(lbl_fuel_sold)
	cy += 28
	lbl_msg = _lbl("", cx, cy, map_ctrl_w, 26, 16, Color(0.6, 0.6, 0.6), false)
	boot.add_child(lbl_msg)
	cy += 26
	lbl_status = _lbl("", cx, cy, map_ctrl_w, 26, 16, Color(0.8, 0.7, 0.3), false)
	boot.add_child(lbl_status)
	cy += 30
	boot.add_child(_lbl("-- Opponents --", cx, cy, map_ctrl_w, 26, 18, Color(0.5, 0.5, 0.6)))
	cy += 26
	lbl_opp = _lbl("", cx, cy, map_ctrl_w, 26, 16, Color(0.9, 0.6, 0.3), false)
	boot.add_child(lbl_opp)
	cy += 28
	for opp in my_opponents:
		if opp.stations_count > 0:
			var bp = 60000 + current_level_num * 15000
			bp = int(bp * opp.loyalty)
			var ot = opp.name + "  Price:" + str(int(opp.price)) + "R  BUYOUT:" + str(bp) + "R"
			boot.add_child(_btn(ot, cx, cy, map_ctrl_w, 50, Color(0.2, 0.08, 0.08), 18, _on_buyout, opp.id))
			cy += 56
	cy += 12
	boot.add_child(_btn("Upgrade Shop", cx, cy, map_ctrl_w, 46, Color(0.12, 0.12, 0.2), 20, _show_upgrade_shop))

func _on_back():
	my_in_game = false
	cars = []
	var s = _get_sim()
	if s != null:
		s.in_game = false
	_show_level_select()

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
	var content_w = min(SW - 40, 1000)
	var cx = (SW - content_w) / 2
	boot.add_child(_btn("<< Back", cx, 20, 180, 45, Color(0.2, 0.25, 0.3), 22, _on_shop_back))
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
			boot.add_child(_lbl("[OWNED] " + un + " - " + ud, cx, y, content_w, 55, 20, Color(0.4, 0.5, 0.4), false))
		else:
			var can = (g.cash >= uc and g.total_stars >= us)
			var bt = un + " - " + ud + " [" + str(uc) + "R, " + str(us) + "*]"
			if can:
				boot.add_child(_btn(bt, cx, y, content_w, 55, cc, 20, _on_buy_upg, uid))
			else:
				boot.add_child(_lbl("[LOCKED] " + bt, cx, y, content_w, 55, 18, Color(0.35, 0.35, 0.4), false))
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
	_update_screen_size()
	current_screen = "result"
	if won:
		boot.add_child(_bg(Color(0.04, 0.08, 0.06)))
		boot.add_child(_lbl("VICTORY!", 0, 200, SW, 80, 56, Color(0.3, 1.0, 0.3)))
		boot.add_child(_lbl("Stars earned: " + str(stars), 0, 300, SW, 50, 32, Color(1, 0.9, 0.3)))
		var g = _get_gs()
		if g != null:
			boot.add_child(_lbl("Cash: " + str(g.cash) + " R", 0, 370, SW, 40, 24, Color(0.7, 0.9, 0.7)))
			boot.add_child(_lbl("Total Stars: " + str(g.total_stars), 0, 420, SW, 40, 24, Color(1, 0.9, 0.3)))
	else:
		boot.add_child(_bg(Color(0.1, 0.04, 0.04)))
		boot.add_child(_lbl("BANKRUPT!", 0, 200, SW, 80, 56, Color(1.0, 0.2, 0.2)))
		boot.add_child(_lbl("Your business went under.", 0, 300, SW, 50, 28, Color(0.8, 0.5, 0.5)))
	var bw = min(500, SW - 80)
	var bx = (SW - bw) / 2
	boot.add_child(_btn("Back to Menu", bx, 550, bw, 60, Color(0.15, 0.2, 0.25), 26, show_main_menu.bind(boot)))
	boot.add_child(_btn("Retry Level", bx, 630, bw, 60, Color(0.2, 0.15, 0.1), 26, _on_retry))

func _on_retry():
	_gen_map()
	show_gameplay(boot)
