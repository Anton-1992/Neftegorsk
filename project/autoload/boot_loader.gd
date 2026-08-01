## BootLoader.gd — v0.1.45: step-by-step boot with diagnostics
## CRITICAL: Previous v0.1.44 stuck on "Loading..." because _boot_continue()
## crashed silently. Now each boot step runs in a separate _process() frame,
## with visible step counter. If a step crashes, user sees which step failed.
## After 3 seconds, a CONTINUE button appears as fallback.
extends Control

var font = null
var boot_step = 0
var boot_error = ""
var _boot_phase = 0
var _boot_timer = 0.0
var _loading_label = null
var _continue_btn = null

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
	
	# STEP 3: Show loading screen with step counter
	_show_loading_screen()
	boot_step = 4
	
	# Start boot in _process() instead of call_deferred
	_boot_phase = 1

func _process(delta):
	_boot_timer += delta
	
	if _boot_phase == 1:
		_boot_phase = 2  # Set BEFORE calling to prevent retry loop
		_update_loading("Step 1: Init GameState...")
		boot_step = 5
		var gs = _safe_get_node("/root/GameState")
		if gs != null and gs.has_method("init_state"):
			gs.init_state(self)
		boot_step = 6
		_update_loading("Step 2: Load main menu...")
		_boot_phase = 3
	
	elif _boot_phase == 3:
		_boot_phase = 4  # Set BEFORE calling
		boot_step = 7
		var ui = _safe_get_node("/root/UIRenderer")
		if ui != null and ui.has_method("show_main_menu"):
			ui.show_main_menu(self)
			boot_step = 8
			_boot_phase = 100  # Done
			return
		boot_error = "UIRenderer missing"
		_update_loading("ERROR: " + boot_error)
		_boot_phase = 5
	
	# Show CONTINUE button after 3 seconds if boot is stuck
	if _boot_timer > 3.0 and _boot_phase < 100 and _continue_btn == null:
		_show_continue_button()

func _show_loading_screen():
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
	
	_loading_label = Label.new()
	_loading_label.text = "NEFTEGORSK v0.1.45\nLoading..."
	_loading_label.position = Vector2(0, sh / 2 - 80)
	_loading_label.size = Vector2(sw, 160)
	_loading_label.add_theme_font_size_override("font_size", 32)
	_loading_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_loading_label.horizontal_alignment = 1
	_loading_label.vertical_alignment = 1
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		_loading_label.add_theme_font_override("font", font)
	add_child(_loading_label)

func _update_loading(text):
	if _loading_label != null and is_instance_valid(_loading_label):
		_loading_label.text = "NEFTEGORSK v0.1.45\n" + text + "\nStep: " + str(boot_step)

func _show_continue_button():
	if _continue_btn != null:
		return
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
	
	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.position = Vector2((sw - 400) / 2, sh - 200)
	_continue_btn.size = Vector2(400, 80)
	_continue_btn.add_theme_font_size_override("font_size", 32)
	if font != null:
		_continue_btn.add_theme_font_override("font", font)
	_continue_btn.pressed.connect(_on_continue_pressed)
	add_child(_continue_btn)

func _on_continue_pressed():
	# Retry boot
	_boot_phase = 1
	_boot_timer = 0.0
	if _continue_btn != null and is_instance_valid(_continue_btn):
		remove_child(_continue_btn)
		_continue_btn.free()
	_continue_btn = null

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
