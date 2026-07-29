## BootLoader.gd — v23: minimal test
extends Control

var font = null

func _ready():
	font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")
	var gs_ok = false
	var ui_ok = false
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("init_state"):
		gs_ok = true
		gs.init_state(self)
	var ui = get_node_or_null("/root/UIRenderer")
	if ui != null and ui.has_method("show_main_menu"):
		ui_ok = true
	if gs_ok and ui_ok:
		ui.show_main_menu(self)
	else:
		_show_diag(gs_ok, ui_ok)

func _show_diag(gs_ok, ui_ok):
	_clear_children()
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1080, 1920)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var diag_text = "NEFTEGORSK DIAGNOSTIC\n\n"
	diag_text += "GameState: "
	if gs_ok:
		diag_text += "OK\n"
	else:
		diag_text += "FAIL\n"
	diag_text += "UIRenderer: "
	if ui_ok:
		diag_text += "OK\n"
	else:
		diag_text += "FAIL\n"
	diag_text += "\nSimulation merged into UIRenderer v23\n"
	diag_text += "\nIf any FAIL above, that script has a parse error."
	var lbl = Label.new()
	lbl.text = diag_text
	lbl.position = Vector2(40, 100)
	lbl.size = Vector2(1000, 800)
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
