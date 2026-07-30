extends Node

var boot = null
var font = null
var lbl_msg = null
var lbl_opp_msg = null

func show_main_menu(boot_node):
	boot = boot_node
	if font == null:
		font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")
	var children = boot.get_children()
	for child in children:
		boot.remove_child(child)
		child.free()
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot.add_child(bg)
	var title = Label.new()
	title.text = "NEFTEGORSK v25"
	title.position = Vector2(0, 30)
	title.size = Vector2(1080, 70)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.horizontal_alignment = 1
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		title.add_theme_font_override("font", font)
	boot.add_child(title)
	var gs = get_node_or_null("/root/GameState")
	var info = Label.new()
	info.text = "UIRenderer: OK"
	if gs != null:
		info.text += "\nCash: " + str(gs.cash) + " R"
		var dn = gs.district_names.get("business_center", "?")
		info.text += "\nDistrict: " + dn
	info.position = Vector2(40, 150)
	info.size = Vector2(1000, 200)
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		info.add_theme_font_override("font", font)
	boot.add_child(info)
	if gs != null:
		var y = 400
		var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
		for d_id in order:
			var d_name = gs.district_names.get(d_id, d_id)
			var is_unlocked = gs.is_district_unlocked(d_id)
			if is_unlocked:
				var btn = Button.new()
				btn.text = ">> " + d_name
				btn.position = Vector2(40, y)
				btn.size = Vector2(1000, 60)
				btn.add_theme_font_size_override("font_size", 22)
				if font != null:
					btn.add_theme_font_override("font", font)
				btn.pressed.connect(_on_district.bind(d_id))
				boot.add_child(btn)
			else:
				var lbl = Label.new()
				lbl.text = d_name + " [Locked]"
				lbl.position = Vector2(40, y)
				lbl.size = Vector2(1000, 60)
				lbl.add_theme_font_size_override("font_size", 20)
				lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if font != null:
					lbl.add_theme_font_override("font", font)
				boot.add_child(lbl)
			y += 70

func _on_district(d_id):
	pass

func show_gameplay(boot_node):
	boot = boot_node

func show_result(won, stars, stars_gained):
	pass

func update_gameplay_ui():
	pass
