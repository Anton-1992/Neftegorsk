## DistrictMap.gd
## Level selection screen within a district

extends Control

@onready var level_grid = %LevelGrid
@onready var district_title = %DistrictTitle
@onready var district_cash = %DistrictCash
@onready var district_stars = %DistrictStars
@onready var btn_back = %BtnBack
@onready var btn_upgrades = %BtnUpgrades2
@onready var btn_settings = %BtnSettings2
@onready var info_desc = %InfoDesc
@onready var detail_dialog = %LevelDetailDialog
@onready var detail_title = %DetailTitle
@onready var detail_desc = %DetailDesc
@onready var detail_opponents = %DetailOpponentsVal
@onready var detail_stations = %DetailStationsVal
@onready var detail_cash = %DetailCashVal
@onready var detail_stars = %DetailStarsVal
@onready var btn_start = %BtnStartLevel

var current_district_id: StringName = ""
var level_buttons: Array[Button] = []

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_load_district(GameManager.current_district_id)
	
	AudioManager.play_music("district_map")
	AudioManager.play_district_ambient(GameManager.current_district_id)

func _setup_ui() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	btn_upgrades.pressed.connect(_on_upgrades_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_start.pressed.connect(_on_start_level)
	detail_dialog.confirmed.connect(_on_start_level)

func _connect_signals() -> void:
	GameManager.currency_changed.connect(_update_currency)
	GameManager.stars_changed.connect(_update_currency)
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _load_district(district_id: StringName) -> void:
	current_district_id = district_id
	var district = LevelManager.get_district(district_id)
	if not district:
		return
	
	district_title.text = district.display_name.upper()
	info_desc.text = district.description
	
	# Clear existing buttons
	for btn in level_buttons:
		btn.queue_free()
	level_buttons.clear()
	for child in level_grid.get_children(): child.queue_free()
	
	# Create level buttons
	var levels = LevelManager.get_levels_for_district(district_id)
	for level in levels:
		var btn = _create_level_button(level)
		level_grid.add_child(btn)
		level_buttons.append(btn)

func _create_level_button(level: LevelData) -> Button:
	var btn = Button.new()
	btn.name = "LevelBtn_%s" % level.level_id
	btn.custom_minimum_size = Vector2(200, 200)
	btn.tooltip_text = level.display_name
	
	var unlocked = LevelManager.is_level_unlocked(level.level_id)
	var completed = GameManager.completed_levels.get(level.level_id, {"stars": 0})
	var stars = completed.stars
	
	# Use a container for layout
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_FULL_RECT
	container.theme_override_constants/separation = 8
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(container)
	
	# Level number
	var lbl_num = Label.new()
	lbl_num.text = level.display_name
	lbl_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_num.theme_override_font_sizes/font_size = 24
	lbl_num.theme_override_colors/font_color = Color(1, 0.9, 0.3) if unlocked else Color(0.5, 0.5, 0.5)
	container.add_child(lbl_num)
	
	# Stars display
	var stars_container = HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.theme_override_constants/separation = 4
	
	var max_stars = level.get_total_possible_stars()
	for i in range(max_stars):
		var star = Label.new()
		star.text = "★"
		star.theme_override_font_sizes/font_size = 20
		if i < stars:
			star.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
		else:
			star.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		stars_container.add_child(star)
	container.add_child(stars_container)
	
	# Status label
	var lbl_status = Label.new()
	lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_status.theme_override_font_sizes/font_size = 16
	if not unlocked:
		lbl_status.text = "ЗАКРЫТ"
		lbl_status.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
	elif stars >= max_stars:
		lbl_status.text = "МАКС ЗВЁЗД"
		lbl_status.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	elif stars > 0:
		lbl_status.text = "Можно улучшить"
		lbl_status.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		lbl_status.text = "НЕ ПРОЙДЕН"
		lbl_status.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	container.add_child(lbl_status)
	
	# Lock overlay
	if not unlocked:
		var lock = TextureRect.new()
		lock.anchors_preset = Control.PRESET_FULL_RECT
		lock.modulate = Color(0, 0, 0, 0.6)
		btn.add_child(lock)
	
	btn.pressed.connect(_on_level_button_pressed.bind(level.level_id))
	btn.mouse_entered.connect(_on_level_hover.bind(level.level_id, true))
	btn.mouse_exited.connect(_on_level_hover.bind(level.level_id, false))
	
	return btn

func _on_level_button_pressed(level_id: StringName) -> void:
	if not LevelManager.is_level_unlocked(level_id):
		AudioManager.sfx_error()
		return
	
	AudioManager.sfx_button_click()
	_show_level_detail(level_id)

func _on_level_hover(level_id: StringName, entered: bool) -> void:
	if entered:
		AudioManager.sfx_button_hover()

func _show_level_detail(level_id: StringName) -> void:
	var level = LevelManager.get_level(level_id)
	if not level:
		return
	
	var district = LevelManager.get_district(level.district_id)
	var unlocked = LevelManager.is_level_unlocked(level_id)
	var completed = GameManager.completed_levels.get(level_id, {"stars": 0})
	
	detail_title.text = "%s %d" % [district.display_name, level.level_number]
	detail_desc.text = level.intro_dialogue
	
	# Calculate opponent info
	var opp_count = level.forced_opponent_count
	if opp_count < 0:
		opp_count = district.max_opponents
	detail_opponents.text = str(opp_count)
	
	var station_range = district.opponent_station_count_range
	var total_stations = opp_count * station_range.y  # Max possible
	detail_stations.text = "%d-%d" % [opp_count * station_range.x, total_stations]
	
	detail_cash.text = "%s ₽" % _format_number(level.player_starting_cash)
	detail_stars.text = "%d ★" % level.get_total_possible_stars()
	
	btn_start.disabled = not unlocked
	if not unlocked:
		btn_start.text = "УРОВЕНЬ ЗАКРЫТ"
	else:
		btn_start.text = "НАЧАТЬ УРОВЕНЬ"
	
	detail_dialog.popup_centered()

func _on_start_level() -> void:
	var selected_idx = -1
	# Find which level was selected (we'd need to track this)
	# For now, get from detail_dialog metadata
	var level_id = detail_dialog.get_meta("level_id", "")
	if level_id != "":
		AudioManager.sfx_button_click()
		detail_dialog.hide()
		GameManager.start_level(LevelManager.get_level(level_id))

func _on_back_pressed() -> void:
	AudioManager.sfx_button_click()
	GameManager.go_to_main_menu()

func _on_upgrades_pressed() -> void:
	AudioManager.sfx_button_click()
	GameManager._game_state_changed(GameManager.GameState.UPGRADE_TREE)
	get_tree().change_scene_to_file("res://scenes/upgrade_tree/upgrade_tree.tscn")

func _on_settings_pressed() -> void:
	AudioManager.sfx_button_click()
	# Reuse settings dialog from main menu
	get_tree().get_root().get_node("MainMenu/SettingsDialog").popup_centered()

func _on_game_state_changed(state: int) -> void:
	if state == GameManager.GameState.DISTRICT_MAP:
		_update_currency()

func _update_currency() -> void:
	district_cash.text = "%s ₽" % _format_number(GameManager.cash)
	district_stars.text = "★ %d" % GameManager.total_stars

