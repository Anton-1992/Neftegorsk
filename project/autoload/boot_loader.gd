## BootLoader.gd — v0.1.41: force landscape orientation
extends Control

var font = null

func _ready():
	# Force landscape orientation at runtime
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("init_state"):
		gs.init_state(self)
	var ui = get_node_or_null("/root/UIRenderer")
	if ui != null and ui.has_method("show_main_menu"):
		ui.show_main_menu(self)
	else:
		_show_diag()

func _show_diag():
	_clear_children()
	var sw = 1920
	var sh = 1080
	var vp = get_viewport()
	if vp != null:
		var rect = vp.get_visible_rect()
		sw = int(rect.size.x)
		sh = int(rect.size.y)
	if sw < 100:
		sw = 1920
	if sh < 100:
		sh = 1080
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(sw, sh)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var autoloads = ["GameState", "GameManager", "LevelManager", "EconomyManager", "UpgradeManager", "SaveManager", "AudioManager", "Simulation", "UIRenderer"]
	var diag_text = "NEFTEGORSK v0.1.41\n9 autoloads\nScreen: " + str(sw) + "x" + str(sh) + "\n\n"
	var ok_count = 0
	for name in autoloads:
		var node = get_node_or_null("/root/" + name)
		if node != null:
			diag_text += name + ": OK\n"
			ok_count += 1
		else:
			diag_text += name + ": FAIL\n"
	diag_text += "\n" + str(ok_count) + "/" + str(autoloads.size()) + " autoloads OK"
	if ok_count == autoloads.size():
		diag_text += "\n\nAll OK! Loading game..."
		var ui = get_node_or_null("/root/UIRenderer")
		if ui != null and ui.has_method("show_main_menu"):
			ui.show_main_menu(self)
			return
	var lbl = Label.new()
	lbl.text = diag_text
	lbl.position = Vector2(40, 100)
	lbl.size = Vector2(sw - 80, 1200)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	if font != null:
		lbl.add_theme_font_override("font", font)
	add_child(lbl)

func _clear_children():
	var children = get_children()
	for child in children:
		remove_child(child)
		child.free()
