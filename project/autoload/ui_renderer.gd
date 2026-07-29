## UIRenderer.gd — v23: MINIMAL test — does this compile on Android?
extends Node

var boot = null
var font = null
var gs = null

func show_main_menu(boot_node):
	boot = boot_node
	gs = get_node_or_null("/root/GameState")
	if font == null:
		font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")
	
	var children = boot.get_children()
	for child in children:
		boot.remove_child(child)
		child.free()
	
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(bg)
	
	var title = Label.new()
	title.text = "NEFTEGORSK v23"
	title.position = Vector2(0, 30)
	title.size = Vector2(1080, 70)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.horizontal_alignment = 1
	title.vertical_alignment = 1
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		title.add_theme_font_override("font", font)
	boot.add_child(title)
	
	var info = Label.new()
	info.text = "UIRenderer: OK\nSimulation: merged\nGameState: " + ("OK" if gs != null else "FAIL") + "\nCash: " + str(gs.cash) + "R"
	info.position = Vector2(40, 200)
	info.size = Vector2(1000, 400)
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		info.add_theme_font_override("font", font)
	boot.add_child(info)
	
	var d_name = "Деловой центр"
	var btn = Button.new()
	btn.text = ">> " + d_name
	btn.position = Vector2(40, 600)
	btn.size = Vector2(1000, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	if font != null:
		btn.add_theme_font_override("font", font)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.18, 0.22)
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
	btn.pressed.connect(_on_test_pressed)
	boot.add_child(btn)

func _on_test_pressed():
	_show_level_select()

func _show_level_select():
	var children = boot.get_children()
	for child in children:
		boot.remove_child(child)
		child.free()
	
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(bg)
	
	var bb = Button.new()
	bb.text = "<< Назад"
	bb.position = Vector2(20, 20)
	bb.size = Vector2(180, 45)
	bb.add_theme_font_size_override("font_size", 22)
	bb.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	if font != null:
		bb.add_theme_font_override("font", font)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.2, 0.25, 0.3)
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bb.add_theme_stylebox_override("normal", bs)
	bb.add_theme_stylebox_override("hover", bs)
	bb.add_theme_stylebox_override("pressed", bs)
	bb.add_theme_stylebox_override("focus", bs)
	bb.pressed.connect(show_main_menu.bind(boot))
	boot.add_child(bb)
	
	var lbl = Label.new()
	lbl.text = "Деловой центр - Уровни"
	lbl.position = Vector2(220, 20)
	lbl.size = Vector2(860, 55)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	lbl.horizontal_alignment = 1
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		lbl.add_theme_font_override("font", font)
	boot.add_child(lbl)
	
	var y = 160
	for i in range(1, 5):
		var lb = Button.new()
		lb.text = "Ур." + str(i) + "  1 противник  Новый"
		lb.position = Vector2(40, y)
		lb.size = Vector2(1000, 65)
		lb.add_theme_font_size_override("font_size", 22)
		lb.add_theme_color_override("font_color", Color(0.8, 1, 0.7))
		if font != null:
			lb.add_theme_font_override("font", font)
		var ls = StyleBoxFlat.new()
		ls.bg_color = Color(0.1, 0.2, 0.15)
		ls.corner_radius_bottom_left = 6
		ls.corner_radius_bottom_right = 6
		ls.corner_radius_top_left = 6
		ls.corner_radius_top_right = 6
		lb.add_theme_stylebox_override("normal", ls)
		lb.add_theme_stylebox_override("hover", ls)
		lb.add_theme_stylebox_override("pressed", ls)
		lb.add_theme_stylebox_override("focus", ls)
		lb.pressed.connect(_on_level_pressed.bind(i))
		boot.add_child(lb)
		y += 72

func _on_level_pressed(num):
	_show_gameplay(num)

func _show_gameplay(num):
	var children = boot.get_children()
	for child in children:
		boot.remove_child(child)
		child.free()
	
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(bg)
	
	var bb = Button.new()
	bb.text = "<< Назад"
	bb.position = Vector2(20, 15)
	bb.size = Vector2(160, 40)
	bb.add_theme_font_size_override("font_size", 20)
	bb.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	if font != null:
		bb.add_theme_font_override("font", font)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.2, 0.25, 0.3)
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bb.add_theme_stylebox_override("normal", bs)
	bb.add_theme_stylebox_override("hover", bs)
	bb.add_theme_stylebox_override("pressed", bs)
	bb.add_theme_stylebox_override("focus", bs)
	bb.pressed.connect(_show_level_select)
	boot.add_child(bb)
	
	var title = Label.new()
	title.text = "Деловой центр Ур." + str(num)
	title.position = Vector2(200, 15)
	title.size = Vector2(400, 40)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.horizontal_alignment = 1
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		title.add_theme_font_override("font", font)
	boot.add_child(title)
	
	# Isometric map - simple version
	var grid_size = 8
	var tw = 50
	var th = 25
	var origin_x = 540
	var origin_y = 90
	var rng = RandomNumberGenerator.new()
	rng.seed = num * 12345
	
	for iy in range(grid_size):
		for ix in range(grid_size):
			var tt = rng.randi_range(0, 2)
			var color = Color(0.15, 0.18, 0.22)
			if tt == 1:
				color = Color(0.35, 0.35, 0.4)
			elif tt == 2:
				color = Color(0.4, 0.35, 0.28)
			if ix == 4 and iy == 4:
				color = Color(0.2, 0.65, 0.2)
			var sx = origin_x + (ix - iy) * tw
			var sy = origin_y + (ix + iy) * th
			var poly = Polygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(0, -th), Vector2(tw, 0), Vector2(0, th), Vector2(-tw, 0)])
			poly.color = color
			poly.position = Vector2(sx, sy)
			boot.add_child(poly)
	
	# Opponent panel
	var opp_y = 500
	var opp_lbl = Label.new()
	opp_lbl.text = "Противник: Акула"
	opp_lbl.position = Vector2(40, opp_y)
	opp_lbl.size = Vector2(400, 35)
	opp_lbl.add_theme_font_size_override("font_size", 20)
	opp_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	opp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		opp_lbl.add_theme_font_override("font", font)
	boot.add_child(opp_lbl)
	
	# Price controls
	var ctrl_y = 600
	var price_lbl = Label.new()
	price_lbl.text = "Цена: 50 R/L"
	price_lbl.position = Vector2(40, ctrl_y)
	price_lbl.size = Vector2(200, 35)
	price_lbl.add_theme_font_size_override("font_size", 22)
	price_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		price_lbl.add_theme_font_override("font", font)
	boot.add_child(price_lbl)
	
	# Buyout button
	var buyout_btn = Button.new()
	buyout_btn.text = "ВЫКУПИТЬ 60000R"
	buyout_btn.position = Vector2(40, ctrl_y + 50)
	buyout_btn.size = Vector2(1000, 50)
	buyout_btn.add_theme_font_size_override("font_size", 22)
	buyout_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	if font != null:
		buyout_btn.add_theme_font_override("font", font)
	var bks = StyleBoxFlat.new()
	bks.bg_color = Color(0.15, 0.08, 0.08)
	bks.corner_radius_bottom_left = 6
	bks.corner_radius_bottom_right = 6
	bks.corner_radius_top_left = 6
	bks.corner_radius_top_right = 6
	buyout_btn.add_theme_stylebox_override("normal", bks)
	buyout_btn.add_theme_stylebox_override("hover", bks)
	buyout_btn.add_theme_stylebox_override("pressed", bks)
	buyout_btn.add_theme_stylebox_override("focus", bks)
	buyout_btn.pressed.connect(_on_buyout)
	boot.add_child(buyout_btn)
	
	# Status
	var status = Label.new()
	status.text = "Утренний пик! Клиенты ждут. Топливо: 5000/5000L"
	status.position = Vector2(40, ctrl_y + 120)
	status.size = Vector2(1000, 35)
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		status.add_theme_font_override("font", font)
	boot.add_child(status)

func _on_buyout():
	var lbl = Label.new()
	lbl.text = "Выкуплено! +1 колонка"
	lbl.position = Vector2(40, 800)
	lbl.size = Vector2(1000, 35)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		lbl.add_theme_font_override("font", font)
	boot.add_child(lbl)
