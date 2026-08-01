## BootLoader.gd — v0.1.46: diagnostic boot — shows exactly where show_main_menu crashes
## The boot_loader's _process() checks ui.menu_step after calling show_main_menu()
## If show_main_menu crashes, the menu_step value tells us EXACTLY where.
extends Control

var font = null
var boot_step = 0
var boot_error = ""
var _boot_phase = 0
var _boot_timer = 0.0
var _loading_label = null
var _continue_btn = null

func _ready():
	_safe_clear_children()
	boot_step = 1
	_set_landscape()
	boot_step = 2
	_load_font()
	boot_step = 3
	_show_loading_screen()
	boot_step = 4
	_boot_phase = 1

func _process(delta):
	_boot_timer += delta
	
	if _boot_phase == 1:
		_boot_phase = 2
		_update_loading("Step 1: Init GameState...")
		boot_step = 5
		var gs = _safe_get_node("/root/GameState")
		if gs != null and gs.has_method("init_state"):
			gs.init_state(self)
		boot_step = 6
		_update_loading("Step 2: Load main menu...")
		_boot_phase = 3
	
	elif _boot_phase == 3:
		_boot_phase = 4
		boot_step = 7
		var ui = _safe_get_node("/root/UIRenderer")
		if ui != null and ui.has_method("show_main_menu"):
			ui.show_main_menu(self)
			boot_step = 8
			_boot_phase = 100
			return
		boot_error = "UIRenderer missing"
		_update_loading("ERROR: " + boot_error)
		_boot_phase = 5
	
	elif _boot_phase == 4:
		# show_main_menu() was called but we're still here — it crashed!
		# Read menu_step from UIRenderer to see where it crashed
		var ui = _safe_get_node("/root/UIRenderer")
		var ms = -1
		if ui != null:
			ms = ui.menu_step
		_update_loading("MENU CRASH! menu_step=" + str(ms))
		_boot_phase = 5
	
	# Show CONTINUE button immediately if boot failed
	if _boot_phase == 5 and _continue_btn == null:
		_show_continue_button()

func _show_loading_screen():
	var sw = _get_sw()
	var sh = _get_sh()
	
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09)
	bg.size = Vector2(sw, sh)
	bg.position = Vector2(0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	_loading_label = Label.new()
	_loading_label.text = "NEFTEGORSK v0.1.46\nLoading..."
	_loading_label.position = Vector2(0, sh / 2 - 80)
	_loading_label.size = Vector2(sw, 160)
	_loading_label.add_theme_font_size_override("font_size", 28)
	_loading_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_loading_label.horizontal_alignment = 1
	_loading_label.vertical_alignment = 1
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		_loading_label.add_theme_font_override("font", font)
	add_child(_loading_label)

func _update_loading(text):
	if _loading_label != null and is_instance_valid(_loading_label):
		_loading_label.text = "NEFTEGORSK v0.1.46\n" + text + "\nStep: " + str(boot_step)

func _show_continue_button():
	var sw = _get_sw()
	var sh = _get_sh()
	
	_continue_btn = Button.new()
	_continue_btn.text = "RETRY"
	_continue_btn.position = Vector2((sw - 400) / 2, sh - 200)
	_continue_btn.size = Vector2(400, 80)
	_continue_btn.add_theme_font_size_override("font_size", 32)
	if font != null:
		_continue_btn.add_theme_font_override("font", font)
	_continue_btn.pressed.connect(_on_continue_pressed)
	add_child(_continue_btn)

func _on_continue_pressed():
	_boot_phase = 1
	_boot_timer = 0.0
	if _continue_btn != null and is_instance_valid(_continue_btn):
		remove_child(_continue_btn)
		_continue_btn.free()
	_continue_btn = null

func _get_sw():
	var vp = get_viewport()
	if vp != null:
		var rect = vp.get_visible_rect()
		if rect.size.x >= 100:
			return int(rect.size.x)
	return 1920

func _get_sh():
	var vp = get_viewport()
	if vp != null:
		var rect = vp.get_visible_rect()
		if rect.size.y >= 100:
			return int(rect.size.y)
	return 1080

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
