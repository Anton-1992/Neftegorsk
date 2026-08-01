## MainMenu.gd
## Main menu with St. Petersburg-style city map and district selection
## Uses Dictionary instead of DistrictData/LevelData for Android compatibility

extends Control

@onready var map_container: Control = $MapContainer
@onready var district_layer: Node2D = $MapContainer/DistrictLayer
@onready var district_info: Panel = $UILayer/DistrictInfoPanel
@onready var district_name: Label = $UILayer/DistrictInfoPanel/DistrictInfoContent/DistrictName
@onready var district_desc: Label = $UILayer/DistrictInfoPanel/DistrictInfoContent/DistrictDesc
@onready var stat_levels: Label = $UILayer/DistrictInfoPanel/DistrictInfoContent/DistrictStats/StatLevelsVal
@onready var stat_stars: Label = $UILayer/DistrictInfoPanel/DistrictInfoContent/DistrictStats/StatStarsVal
@onready var stat_difficulty: Label = $UILayer/DistrictInfoPanel/DistrictInfoContent/DistrictStats/StatDifficultyVal
@onready var btn_enter: Button = $UILayer/DistrictInfoPanel/DistrictInfoContent/BtnEnterDistrict
@onready var cash_label: Label = $UILayer/TopBar/CurrencyDisplay/CashLabel
@onready var stars_label: Label = $UILayer/TopBar/CurrencyDisplay/StarsLabel
@onready var btn_continue: Button = $UILayer/BottomBar/BtnContinue
@onready var btn_upgrades: Button = $UILayer/BottomBar/BtnUpgradeTree
@onready var btn_settings: Button = $UILayer/BottomBar/BtnSettings
@onready var level_select_dialog: AcceptDialog = $LevelSelectDialog
@onready var level_list: ItemList = $LevelSelectDialog/LevelSelectContainer/LevelList
@onready var btn_level_confirm: Button = $LevelSelectDialog/LevelSelectContainer/BtnLevelSelectConfirm
@onready var settings_dialog: AcceptDialog = $SettingsDialog
@onready var music_volume: HSlider = $SettingsDialog/SettingsContainer/AudioSection/MusicVolume
@onready var sfx_volume: HSlider = $SettingsDialog/SettingsContainer/AudioSection/SfxVolume
@onready var btn_reset: Button = $SettingsDialog/SettingsContainer/DataSection/BtnResetProgress
@onready var reset_dialog: ConfirmationDialog = $ResetConfirmDialog
@onready var new_game_dialog: ConfirmationDialog = $NewGameDialog

var selected_district: StringName = ""
var district_buttons: Dictionary = {}  # district_id -> Button
var level_select_callback: Callable = null

func _ready() -> void:
	_setup_ui()
	_create_district_map()
	_connect_signals()
	_update_currency_display()
	
	# Play menu music
	AudioManager.play_music("main_menu")
	
	# Check for save game
	if SaveManager.has_save_file():
		btn_continue.text = "ПРОДОЛЖИТЬ"
		btn_continue.disabled = false
	else:
		btn_continue.text = "НОВАЯ ИГРА"
		btn_continue.disabled = false

func _setup_ui() -> void:
	district_info.visible = false
	btn_enter.pressed.connect(_on_enter_district)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_upgrades.pressed.connect(_on_upgrades_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_level_confirm.pressed.connect(_on_level_confirm)
	btn_reset.pressed.connect(_on_reset_pressed)
	reset_dialog.confirmed.connect(_on_reset_confirmed)
	new_game_dialog.confirmed.connect(_on_new_game_confirmed)
	music_volume.value_changed.connect(_on_music_volume_changed)
	sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	
	# Load saved volume settings
	music_volume.value = AudioManager.music_volume
	sfx_volume.value = AudioManager.sfx_volume

func _connect_signals() -> void:
	GameManager.currency_changed.connect(_update_currency_display)
	GameManager.stars_changed.connect(_update_currency_display)
	GameManager.district_unlocked.connect(_on_district_unlocked)
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _create_district_map() -> void:
# Create district buttons on the map (St. Petersburg style layout)
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

func _create_district_button(district: Dictionary, position: Vector2) -> Button:
	# district is now a Dictionary, not DistrictData
	var district_id = district.get("id", "")
	var display_name = district.get("name", district_id)
	var levels = district.get("levels", 4)
	
	var btn = Button.new()
	btn.name = "DistrictBtn_%s" % district_id
	btn.custom_minimum_size = Vector2(80, 80)
	btn.text = display_name
	btn.tooltip_text = display_name
	
	# Position relative to map container
	btn.anchors_preset = Control.PRESET_TOP_LEFT
	btn.offset_left = position.x - 40
	btn.offset_top = position.y - 40
	btn.offset_right = position.x + 40
	btn.offset_bottom = position.y + 40
	
	# Style the button based on unlock status
	var is_unlocked = GameManager.is_district_unlocked(StringName(district_id))
	var progress = GameManager.get_level_progress(district_id)
	
	# Color scheme
	var base_color = district.get("color", Color(0.3, 0.3, 0.35))
	if not is_unlocked:
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		btn.text = "🔒 " + display_name
	else:
		# Show completion status in text
		var completed = progress.get("completed", 0)
		var total = progress.get("total", levels)
		var stars = progress.get("stars", 0)
		btn.text = "%s\n%d/%d ★%d" % [display_name, completed, total, stars]
	
	btn.pressed.connect(_on_district_pressed.bind(StringName(district_id)))
	btn.mouse_entered.connect(_on_district_hover.bind(StringName(district_id), true))
	btn.mouse_exited.connect(_on_district_hover.bind(StringName(district_id), false))
	
	return btn

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
	# district is now a Dictionary
	var district = LevelManager.get_district(district_id)
	if district.is_empty():
		return
	
	var progress = GameManager.get_level_progress(district_id)
	
	# Use bracket notation for Dictionary access (Android safe)
	district_name.text = district.get("name", str(district_id))
	district_desc.text = district.get("description", "Район Нефтегорска")
	stat_levels.text = "%d/%d" % [progress.get("completed", 0), progress.get("total", district.get("levels", 4))]
	stat_stars.text = "%d ★" % progress.get("stars", 0)
	
	# Difficulty based on traffic value (higher = harder)
	var traffic = district.get("traffic", 50)
	var diff = traffic / 20  # Convert to 1-5 scale roughly
	var diff_stars = "★" * int(diff) + "☆" * (5 - int(diff))
	stat_difficulty.text = diff_stars
	
	district_info.visible = true
	# Animate in
	district_info.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(district_info, "modulate:a", 1.0, 0.2)

func _open_level_select(district_id: StringName) -> void:
	# district is now a Dictionary
	var district = LevelManager.get_district(district_id)
	if district.is_empty():
		return
	
	level_list.clear()
	
	# Get levels count from district dictionary
	var levels_count = district.get("levels", 4)
	var district_name_str = district.get("name", str(district_id))
	
	for i in range(1, levels_count + 1):
		# Create level_id like "business_center_1"
		var level_id = str(district_id) + "_" + str(i)
		
		var level_data = LevelManager.get_level(district_id, i)
		if level_data.is_empty():
			continue
		
		var unlocked = LevelManager.is_level_unlocked(level_id)
		var completed_data = GameManager.completed_levels.get(level_id, {})
		var stars = completed_data.get("stars", 0) if completed_data is Dictionary else 0
		
		var item_text = "%s %d" % [district_name_str, i]
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
	
	level_select_dialog.title = "Район: %s" % district_name_str
	level_select_dialog.popup_centered()

func _on_level_confirm() -> void:
	var selected = level_list.get_selected_items()
	if selected.is_empty():
		return
	
	var idx = selected[0]
	var level_id = level_list.get_item_metadata(idx)  # This is already the full level_id like "business_center_1"
	
	if not LevelManager.is_level_unlocked(level_id):
		AudioManager.sfx_error()
		return
	
	AudioManager.sfx_button_click()
	level_select_dialog.hide()
	district_info.visible = false
	
	# Parse district_id and level_num from level_id
	var parts = level_id.split("_")
	if parts.size() >= 2:
		var district_id = parts[0]
		var level_num = parts[1].to_int()
		var level_data = LevelManager.get_level(district_id, level_num)
		GameManager.start_level(level_data)

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
	var str = str(num)
	var result = ""
	for i, ch in enumerate(str.reversed()):
		if i > 0 and i % 3 == 0:
			result = " " + result
		result = ch + result
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