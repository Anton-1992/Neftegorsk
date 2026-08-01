## BootLoader.gd — v0.1.44: robust boot with call_deferred
## CRITICAL: This script must NEVER crash in _ready().
## Previous v0.1.43 showed diagnostic screen at step 3, then crashed
## when calling gs.init_state(self) — likely because data.name / data.color
## dot notation on Dictionary conflicts with built-in properties on Android.
## Fix: 
## 1. Show simple "Loading..." screen in _ready()
## 2. Use call_deferred() for init and menu transition
## 3. GameState now uses bracket notation for all dict access
## 4. If boot fails, show error screen with CONTINUE button
extends Control

var font = null
var boot_step = 0
var boot_error = ""

func _ready():
	# STEP 0: Clear default tscn children
	_safe_clear_children()
	boot_step = 1
	
	# STEP 1: Force landscape
	_set_landscape()
	boot_step = 2
	
	# STEP 2: Load font
	_load_font()
	boot_step = 3
	
	# STEP 3: Show simple "Loading..." screen
	_show_loading_screen()
	boot_step = 4
	
	# STEP 4: Continue boot in next frame via call_deferred
	# This ensures _ready() completes without errors
	call_deferred("_boot_continue")

func _boot_continue():
	# STEP 5: Try to init GameState
	boot_step = 5
	var gs = _safe_get_node("/root/GameState")
	if gs != null and gs.has_method("init_state"):
		gs.init_state(self)
	boot_step = 6
	
	# STEP 6: Try to load main menu via UIRenderer
	var ui = _safe_get_node("/root/UIRenderer")
	if ui != null and ui.has_method("show_main_menu"):
		ui.show_main_menu(self)
		boot_step = 7
		return
	
	# If we get here, show error screen with CONTINUE button
	boot_error = "UIRenderer not found or has no show_main_menu"
	_show_error_screen()

func _show_loading_screen():
	# Simple loading screen — no diagnostic info, just "Loading..."
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
	bg.color = Color(0.04, 0.05, 0.09)
	bg.size = Vector2(sw, sh)
	bg.position = Vector2(0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	var lbl = Label.new()
	lbl.text = "NEFTEGORSK v0.1.44\nLoading..."
	lbl.position = Vector2(0, sh / 2 - 60)
	lbl.size = Vector2(sw, 120)
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	lbl.horizontal_alignment = 1
	lbl.vertical_alignment = 1
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		lbl.add_theme_font_override("font", font)
	add_child(lbl)

func _safe_clear_children():
	var children = get_children()
	for child in children:
		if is_instance_valid(child):
			remove_child(child)
			child.free()

func _set_landscape():
	if DisplayServer.screen_get_orientation() != DisplayServer.SCREEN_SENSOR_LANDSCAPE:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _load_font():
	if font == null:
		if ResourceLoader.exists("res://assets/fonts/DejaVuSans.ttf"):
			font = ResourceLoader.load("res://assets/fonts/DejaVuSans.ttf")

func _safe_get_node(path):
	var node = get_node_or_null(path)
	if node != null and not is_instance_valid(node):
		return null
	return node

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
	lbl.text = "NEFTEGORSK v0.1.44\n\nBOOT ERROR!\n\nStep: " + str(boot_step) + "\nError: " + boot_error + "\n\nPress CONTINUE to retry."
	lbl.position = Vector2(40, 100)
	lbl.size = Vector2(sw - 80, 800)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	
	var btn = Button.new()
	btn.text = "CONTINUE"
	btn.position = Vector2((sw - 400) / 2, sh - 200)
	btn.size = Vector2(400, 80)
	btn.add_theme_font_size_override("font_size", 32)
	if font != null:
		btn.add_theme_font_override("font", font)
	btn.pressed.connect(_on_continue_pressed)
	add_child(btn)

func _on_continue_pressed():
	# Retry the boot process
	call_deferred("_boot_continue")
