## MainMenu.gd
## Main menu with St. Petersburg-style city map and district selection

extends Control

@onready var map_container = %MapContainer
@onready var district_layer = %DistrictLayer
@onready var district_info = %DistrictInfoPanel
@onready var district_name = %DistrictName
@onready var district_desc = %DistrictDesc
@onready var stat_levels = %StatLevelsVal
@onready var stat_stars = %StatStarsVal
@onready var stat_difficulty = %StatDifficultyVal
@onready var btn_enter = %BtnEnterDistrict
@onready var cash_label = %CashLabel
@onready var stars_label = %StarsLabel
@onready var btn_continue = %BtnContinue
@onready var btn_upgrades = %BtnUpgradeTree
@onready var btn_settings = %BtnSettings
@onready var level_select_dialog = %LevelSelectDialog
@onready var level_list = %LevelList
@onready var btn_level_confirm = %BtnLevelSelectConfirm
@onready var settings_dialog = %SettingsDialog
@onready var music_volume = %MusicVolume
@onready var sfx_volume = %SfxVolume
@onready var btn_reset = %BtnResetProgress
@onready var reset_dialog = %ResetConfirmDialog
@onready var new_game_dialog = %NewGameDialog

var selected_district: StringName = ""
var district_buttons: Dictionary = {}  # district_id -> Button
var level_select_callback: Callable = null

func _ready() -> void:
	DebugLogger.log_node_ready("MainMenu", true, "start _ready")
	
	# Add visible debug label
	_add_debug_overlay()
	
	_setup_ui()
	DebugLogger.log_node_ready("MainMenu", true, "_setup_ui done")
	_create_district_map()
	_connect_signals()
	_update_currency_display()
	DebugLogger.log_node_ready("MainMenu", true, "core setup done")
	
	# Play menu music (ignore errors - audio files may not exist)
	AudioManager.play_music("main_menu")
	DebugLogger.log_node_ready("MainMenu", true, "music requested")
	
	# Check for save game
	if SaveManager.has_save_file():
		btn_continue.text = "ПРОДОЛЖИТЬ"
		btn_continue.disabled = false
	else:
		btn_continue.text = "НОВАЯ ИГРА"
		btn_continue.disabled = false
	
	# Hide debug label after successful init (keep for 3 seconds for testing)
	DebugLogger.log_node_ready("MainMenu", true, "ALL DONE - game loaded successfully!")
	_hide_debug_after_delay()

func _add_debug_overlay() -> void:
	# Create a visible debug label at top of screen
	var debug_label = Label.new()
	debug_label.name = "DebugOverlay"
	debug_label.text = "NEFTEGORSK LOADING..."
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_label.anchors_preset = Control.PRESET_CENTER_TOP
	debug_label.position = Vector2(0, 50)
	debug_label.size = Vector2(1080, 40)
	debug_label.theme_override_font_sizes/font_size = 24
	debug_label.theme_override_colors/font_color = Color(1, 0.3, 0.3)
	debug_label.theme_override_colors/font_outline_color = Color(0, 0, 0)
	debug_label.theme_override_constants/outline_size = 2
	add_child(debug_label)

func _hide_debug_after_delay() -> void:
	var debug = get_node_or_null("DebugOverlay")
	if debug:
		debug.text = "OK ✓"
		debug.theme_override_colors/font_color = Color(0.4, 1, 0.4)
		# Keep visible for 3 seconds then hide
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(3.0)
		tween.tween_callback(debug.queue_free.bind)

func _setup_ui() -> void:
	# Null-check all @onready references and log which ones are null
	var null_nodes = []
	for var_name in ["map_container", "district_layer", "district_info", "district_name", "district_desc", "stat_levels", "stat_stars", "stat_difficulty", "btn_enter", "cash_label", "stars_label", "btn_continue", "btn_upgrades", "btn_settings", "level_select_dialog", "level_list", "btn_level_confirm", "settings_dialog", "music_volume", "sfx_volume", "btn_reset", "reset_dialog", "new_game_dialog"]:
		if get(var_name) == null:
			null_nodes.append(var_name)
	
	if null_nodes.size() > 0:
		DebugLogger.log_error("MainMenu: null @onready nodes: %s" % str(null_nodes))
		var debug = get_node_or_null("DebugOverlay")
		if debug:
			debug.text = "NULL NODES: %s" % str(null_nodes)
	else:
		DebugLogger.log_node_ready("MainMenu", true, "all @onready nodes found")
	
	district_info.visible = false
	if btn_enter: btn_enter.pressed.connect(_on_enter_district)
	if btn_continue: btn_continue.pressed.connect(_on_continue_pressed)
	if btn_upgrades: btn_upgrades.pressed.connect(_on_upgrades_pressed)
	if btn_settings: btn_settings.pressed.connect(_on_settings_pressed)
	if btn_level_confirm: btn_level_confirm.pressed.connect(_on_level_confirm)
	if btn_reset: btn_reset.pressed.connect(_on_reset_pressed)
	if reset_dialog: reset_dialog.confirmed.connect(_on_reset_confirmed)
	if new_game_dialog: new_game_dialog.confirmed.connect(_on_new_game_confirmed)
	if music_volume: music_volume.value_changed.connect(_on_music_volume_changed)
	if sfx_volume: sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	
	# Load saved volume settings
	if music_volume: music_volume.value = AudioManager.music_volume
	if sfx_volume: sfx_volume.value = AudioManager.sfx_volume

func _connect_signals() -> void:
	GameManager.currency_changed.connect(_update_currency_display)
	GameManager.stars_changed.connect(_update_currency_display)
	GameManager.district_unlocked.connect(_on_district_unlocked)
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _create_district_map() -> void:
	"""Create district buttons on the map (St. Petersburg style layout)"""
	var districts = LevelManager.get_districts_in_order()
	
	# Approximate St. Petersburg district positions on normalized map (0-1)
	# Based on actual SPb geography: center, north, south, east, west, islands
	var positions = {
		"business_center": Vector2(0.45, 0.35),      # Center (Admiralty/Vasileostrovsky)
		"historic": Vector2(0.4, 0.28),              # Historic center (Admiralty/St. Isaac)
		"residential": Vector2(0.6, 0.55),           # Residential (Moskovsky/Kupchino)
		"industrial": Vector2(0.25, 0.6),            # Industrial (Nevsky gate/Kirovsky)
		"waterfront": Vector2(0.5, 0.2),             # Waterfront (Vasilevsky/Neva)
		"suburban": Vector2(0.75, 0.75),             # Suburbs (Pushkin/Pavlovsk)
		"port": Vector2(0.3, 0.75),                  # Port (Sea port area)
		"airport": Vector2(0.15, 0.45),              # Airport (Pulkovo - south)
		"university": Vector2(0.55, 0.3),            # University (Petrograd side)
		"tourist": Vector2(0.65, 0.25)               # Tourist (Peterhof - west)
	}
	
	var map_size = map_container.get_rect().size
	if map_size == Vector2(0, 0):
		# Wait for layout
		call_deferred("_create_district_map")
		return
	
	for district_data in districts:
		var pos = positions.get(district_data.district_id, Vector2(0.5, 0.5))
		var btn = _create_district_button(district_data, pos * map_size)
		district_layer.add_child(btn)
		district_buttons[district_data.district_id] = btn

func _create_district_button(district: DistrictData, position: Vector2) -> Button:
	var btn = Button.new()
	btn.name = "DistrictBtn_%s" % district.district_id
	btn.custom_minimum_size = Vector2(60, 60)
	btn.tooltip_text = district.display_name
	
	# Position relative to map container
	btn.anchors_preset = Control.PRESET_TOP_LEFT
	btn.offset_left = position.x - 30
	btn.offset_top = position.y - 30
	
	# Custom drawing for district icon
	var is_unlocked = GameManager.is_district_unlocked(district.district_id)
	var progress = GameManager.get_level_progress(district.district_id)
	
	# draw_rect_callback removed (not a valid Button property in Godot 4)
	# Custom drawing handled via _draw_district_button and queue_redraw
	btn.pressed.connect(_on_district_pressed.bind(district.district_id))
	btn.mouse_entered.connect(_on_district_hover.bind(district.district_id, true))
	btn.mouse_exited.connect(_on_district_hover.bind(district.district_id, false))
	
	# Force redraw
	btn.queue_redraw()
	return btn

func _draw_district_button(btn: Button, district: DistrictData, unlocked: bool, progress: Dictionary) -> void:
	var rect = Rect2(Vector2(0, 0), btn.custom_minimum_size)
	var center = rect.size / 2
	var radius = 25
	
	# Background circle
	var bg_color = district.background_color
	if not unlocked:
		bg_color = Color(0.2, 0.2, 0.25, 0.7)
	btn.draw_circle(center, radius, bg_color)
	
	# Border
	var border_color = district.building_colors[0] if district.building_colors.size() > 0 else Color(0.5, 0.5, 0.6)
	if not unlocked:
		border_color = Color(0.4, 0.4, 0.5)
	if btn == _get_hovered_button():
		border_color = Color(1, 0.9, 0.3)
	btn.draw_circle(center, radius, border_color, false, 3)
	
	# Lock icon if locked
	if not unlocked:
		btn.draw_string(btn.get_theme_font("font", "Label"), center + Vector2(-8, 4), "🔒", 
		                HorizontalAlignment.CENTER, -1, 24)
	else:
		# Stars earned
		var stars = progress.stars
		var max_stars = progress.max_stars if progress.max_stars > 0 else district.levels_per_district * 3
		var star_text = "%d/%d" % [stars, max_stars]
		btn.draw_string(btn.get_theme_font("font", "Label"), center + Vector2(0, 4), star_text,
		                HorizontalAlignment.CENTER, -1, 18)
		
		# Completion indicator
		if progress.completed == progress.total and progress.total > 0:
			btn.draw_circle(center + Vector2(20, -20), 12, Color(0.4, 1, 0.4))
			btn.draw_string(btn.get_theme_font("font", "Label"), center + Vector2(20, -16), "✓",
			                HorizontalAlignment.CENTER, -1, 20)

var _hovered_district: StringName = ""

func _get_hovered_button() -> Button:
	return district_buttons.get(_hovered_district)

func _on_district_pressed(district_id: StringName) -> void:
	if not GameManager.is_district_unlocked(district_id):
		AudioManager.sfx_error()
		_show_locked_message(district_id)
		return
	
	AudioManager.sfx_button_click()
	selected_district = district_id
	_show_district_info(district_id)
	_open_level_select(district_id)

func _on_district_hover(district_id: StringName, entered: bool) -> void:
	if entered:
		_hovered_district = district_id
		if GameManager.is_district_unlocked(district_id):
			AudioManager.sfx_button_hover()
	else:
		if _hovered_district == district_id:
			_hovered_district = ""
	district_buttons.get(district_id)?.queue_redraw()

func _show_district_info(district_id: StringName) -> void:
	var district = LevelManager.get_district(district_id)
	if not district:
		return
	
	var progress = GameManager.get_level_progress(district_id)
	
	district_name.text = district.display_name
	district_desc.text = district.description
	stat_levels.text = "%d/%d" % [progress.completed, progress.total]
	stat_stars.text = "%d ★" % progress.stars
	
	# Difficulty stars
	var diff = district.get_difficulty_rating()
	var diff_stars = "★" * int(diff * 5 + 0.5) + "☆" * (5 - int(diff * 5 + 0.5))
	stat_difficulty.text = diff_stars
	
	district_info.visible = true
	# Animate in
	district_info.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(district_info, "modulate:a", 1.0, 0.2)

func _open_level_select(district_id: StringName) -> void:
	var district = LevelManager.get_district(district_id)
	if not district:
		return
	
	level_list.clear()
	
	for i in range(1, district.levels_per_district + 1):
		var level_id = LevelData.create_level_id(district_id, i)
		var level = LevelManager.get_level(level_id)
		if not level:
			continue
		
		var unlocked = LevelManager.is_level_unlocked(level_id)
		var completed_data = GameManager.completed_levels.get(level_id, {"stars": 0})
		var stars = completed_data.stars
		
		var item_text = "%s %d" % [district.display_name, i]
		if stars > 0:
			item_text += "  ★ %d" % stars
		if not unlocked:
			item_text += "  (закрыт)"
		
		level_list.add_item(item_text)
		var idx = level_list.get_item_count() - 1
		level_list.set_item_metadata(idx, level_id)
		
		if not unlocked:
			level_list.set_item_custom_bg_color(idx, Color(0.2, 0.2, 0.25))
			level_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
		elif stars >= 3:
			level_list.set_item_custom_fg_color(idx, Color(0.4, 1, 0.4))
	
	level_select_dialog.title = "Район: %s" % district.display_name
	level_select_dialog.popup_centered()

func _on_level_confirm() -> void:
	var selected = level_list.get_selected_items()
	if selected.is_empty():
		return
	
	var idx = selected[0]
	var level_id = level_list.get_item_metadata(idx)
	
	if not LevelManager.is_level_unlocked(level_id):
		AudioManager.sfx_error()
		return
	
	AudioManager.sfx_button_click()
	level_select_dialog.hide()
	district_info.visible = false
	GameManager.start_level(LevelManager.get_level(level_id))

func _on_enter_district() -> void:
	if selected_district != "":
		_open_level_select(selected_district)

func _on_continue_pressed() -> void:
	if SaveManager.has_save_file():
		# Continue - go to last district or map
		AudioManager.sfx_button_click()
		GameManager.go_to_district_map(GameManager.current_district_id if GameManager.current_district_id != "" else "business_center")
	else:
		# New game
		new_game_dialog.popup_centered()

func _on_new_game_confirmed() -> void:
	AudioManager.sfx_button_click()
	GameManager.reset_game()
	GameManager.go_to_district_map("business_center")

func _on_upgrades_pressed() -> void:
	AudioManager.sfx_button_click()
	GameManager._game_state_changed(GameManager.GameState.UPGRADE_TREE)
	get_tree().change_scene_to_file("res://scenes/upgrade_tree/upgrade_tree.tscn")

func _on_settings_pressed() -> void:
	AudioManager.sfx_button_click()
	settings_dialog.popup_centered()

func _on_reset_pressed() -> void:
	AudioManager.sfx_button_click()
	reset_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	AudioManager.sfx_button_click()
	SaveManager.delete_save()
	GameManager.reset_game()

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

func _update_currency_display() -> void:
	cash_label.text = "%s ₽" % _format_number(GameManager.cash)
	stars_label.text = "★ %d" % GameManager.total_stars

func _format_number(num: int) -> String:
	var num_str = str(num)
	var result = ""
	var count = 0
	for i in range(num_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = num_str[i] + result
		count += 1
	return result

func _on_district_unlocked(district_id: StringName) -> void:
	var btn = district_buttons.get(district_id)
	if btn:
		btn.queue_redraw()

func _on_game_state_changed(state: int) -> void:
	if state == GameManager.GameState.MAIN_MENU:
		# Returning to menu - refresh
		_update_currency_display()
		for btn in district_buttons.values():
			btn.queue_redraw()

func _show_locked_message(district_id: StringName) -> void:
	var district = LevelManager.get_district(district_id)
	if not district:
		return
	
	var req_stars = district.required_stars_total
	var current = GameManager.total_stars
	var msg = "%s пока недоступен.\nНужно %d ★ (у вас %d ★)." % [district.display_name, req_stars, current]
	
	# Show as tooltip or temporary label
	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	label.add_theme_font_size_override("font_size", 24)
	label.global_position = get_viewport_rect().size / 2
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	tween.tween_callback(label.queue_free.bind())