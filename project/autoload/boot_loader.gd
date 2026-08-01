## BootLoader.gd — v0.1.43: ultra-robust boot
## CRITICAL: This script must NEVER crash in _ready().
## If it does, the user sees only the default tscn labels and nothing else.
## Every step is wrapped in error checking. Every call is guarded.
extends Control

var font = null
var boot_step = 0
var boot_error = ""

func _ready():
	# STEP 0: IMMEDIATELY clear default tscn children so user sees SOMETHING
	_safe_clear_children()
	boot_step = 1
	
	# STEP 1: Force landscape (non-critical, can fail)
	_set_landscape()
	boot_step = 2
	
	# STEP 2: Load font (non-critical, can fail)
	_load_font()
	boot_step = 3
	
	# STEP 3: Show EARLY diagnostic screen — user sees this even if everything else fails
	_show_early_diag()
	boot_step = 4
	
	# STEP 4: Try to init GameState (critical for gameplay)
	var gs = _safe_get_node("/root/GameState")
	if gs != null and gs.has_method("init_state"):
		gs.init_state(self)
	boot_step = 5
	
	# STEP 5: Try to load main menu via UIRenderer
	var ui = _safe_get_node("/root/UIRenderer")
	if ui != null and ui.has_method("show_main_menu"):
		ui.show_main_menu(self)
		boot_step = 6
		return
	
	# If we get here, UIRenderer is not available — show error
	boot_error = "UIRenderer not found or has no show_main_menu"
	_show_error_screen()

func _safe_clear_children():
	var children = get_children()
	for child in children:
		if is_instance_valid(child):
			remove_child(child)
			child.free()

func _set_landscape():
	# Non-critical: force landscape orientation
	if DisplayServer.screen_get_orientation() != DisplayServer.SCREEN_SENSOR_LANDSCAPE:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _load_font():
	# Non-critical: load font for Cyrillic
	if font == null:
		if ResourceLoader.exists("res://assets/fonts/DejaVuSans.ttf"):
			font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")

func _safe_get_node(path):
	var node = get_node_or_null(path)
	if node != null and not is_instance_valid(node):
		return null
	return node

func _show_early_diag():
	# Show a diagnostic screen that tells the user what's happening
	_safe_clear_children()
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
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.size = Vector2(sw, sh)
	bg.position = Vector2(0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# Check autoloads
	var autoloads = ["GameState", "GameManager", "LevelManager", "EconomyManager", "UpgradeManager", "SaveManager", "AudioManager", "Simulation", "UIRenderer"]
	var diag_text = "NEFTEGORSK v0.1.43\nBoot step: " + str(boot_step) + "\nScreen: " + str(sw) + "x" + str(sh) + "\n\n"
	var ok_count = 0
	for name in autoloads:
		var node = _safe_get_node("/root/" + name)
		if node != null:
			diag_text += name + ": OK\n"
			ok_count += 1
		else:
			diag_text += name + ": FAIL\n"
	diag_text += "\n" + str(ok_count) + "/" + str(autoloads.size()) + " autoloads OK"
	if boot_error != "":
		diag_text += "\n\nError: " + boot_error
	if ok_count == autoloads.size():
		diag_text += "\n\nAll OK! Loading game..."
	
	var lbl = Label.new()
	lbl.text = diag_text
	lbl.position = Vector2(40, 100)
	lbl.size = Vector2(sw - 80, 1200)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	if font != null:
		lbl.add_theme_font_override("font", font)
	add_child(lbl)

func _show_error_screen():
	_safe_clear_children()
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
	bg.color = Color(0.15, 0.04, 0.04)
	bg.size = Vector2(sw, sh)
	bg.position = Vector2(0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	var lbl = Label.new()
	lbl.text = "NEFTEGORSK v0.1.43\n\nBOOT ERROR!\n\nStep: " + str(boot_step) + "\nError: " + boot_error + "\n\nThe game could not load.\nPlease report this error."
	lbl.position = Vector2(40, 100)
	lbl.size = Vector2(sw - 80, 1200)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if font != null:
		lbl.add_theme_font_override("font", font)
	add_child(lbl)
