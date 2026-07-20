## Level.gd
## Core gameplay level - procedural map, economy simulation, station management

extends Node2D

@onready var map_renderer = %MapRenderer
@onready var grid_layer = %GridLayer
@onready var road_layer = %RoadLayer
@onready var building_layer = %BuildingLayer
@onready var station_layer = %StationLayer
@onready var player_station = %PlayerStation
@onready var opponent_stations = %OpponentStations
@onready var level_title = %LevelTitle
@onready var time_display = %TimeDisplay
@onready var cash_display = %CashDisplay
@onready var market_price_display = %MarketPriceDisplay
@onready var btn_speed1 = %BtnSpeed1
@onready var btn_speed2 = %BtnSpeed2
@onready var btn_speed3 = %BtnSpeed3
@onready var btn_pause = %BtnPause
@onready var btn_station_menu = %BtnStationMenu
@onready var btn_buy_fuel = %BtnBuyFuel
@onready var btn_opponents = %BtnOpponents
@onready var btn_map = %BtnMap
@onready var station_panel = %StationPanel
@onready var price_spinbox = %PriceSpinBox
@onready var fuel_value = %FuelValue
@onready var revenue_value = %RevenueValue
@onready var upgrades_btn = %UpgradesBtn
@onready var close_station_panel = %CloseStationPanel
@onready var buy_fuel_dialog = %BuyFuelDialog
@onready var fuel_slider = %FuelSlider
@onready var fuel_amount_label = %FuelAmountLabel
@onready var wholesale_price_label = %WholesalePrice
@onready var btn_confirm_buy = %BtnConfirmBuy
@onready var opponents_dialog = %OpponentsDialog
@onready var opponents_list = %OpponentsList
@onready var opponent_name = %OpponentName
@onready var opponent_stations_label = %OpponentStationsLabel
@onready var opponent_price_label = %OpponentPriceLabel
@onready var opponent_buyout_label = %OpponentBuyoutLabel
@onready var btn_buyout = %BtnBuyout
@onready var result_dialog = %ResultDialog
@onready var result_title = %ResultTitle
@onready var result_stars = %ResultStars
@onready var stat_stations = %StatStationsVal
@onready var stat_time = %StatTimeVal
@onready var stat_cash = %StatCashVal
@onready var stat_revenue = %StatRevenueVal
@onready var btn_next = %BtnNextLevel
@onready var btn_replay = %BtnReplay
@onready var btn_to_map = %BtnToMap

# Level state
var level_data: LevelData = null
var map_data: Dictionary = {}
var district_data: DistrictData = null
var game_time: float = 0.0  # Hours since start
var time_speed: float = 2.0  # 1x, 2x, 4x
var is_paused: bool = false

# Station data
var player_stations_data: Array[Dictionary] = []
var opponent_data: Dictionary = {}  # comp_id -> {stations: [], archetype, cash, price}
var selected_station_id: int = 0
var selected_opponent_id: int = -1

# Stats tracking
var level_stats: Dictionary = {
	"start_time": 0,
	"stations_bought": 0,
	"fuel_bought": 0,
	"fuel_sold": 0,
	"revenue": 0,
	"expenses": 0,
	"price_changes": 0,
	"opponents_defeated": 0,
	"price_wars_won": 0,
	"went_bankrupt": false
}

# Simulation
var simulation_timer: float = 0.0
var simulation_interval: float = 1.0  # Simulate every game hour

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_initialize_level()

func _setup_ui() -> void:
	# Speed controls
	btn_speed1.pressed.connect(_set_speed.bind(1.0))
	btn_speed2.pressed.connect(_set_speed.bind(2.0))
	btn_speed3.pressed.connect(_set_speed.bind(4.0))
	btn_pause.pressed.connect(_toggle_pause)
	
	# Station panel
	btn_station_menu.pressed.connect(_toggle_station_panel)
	close_station_panel.pressed.connect(_close_station_panel)
	price_spinbox.value_changed.connect(_on_price_changed)
	upgrades_btn.pressed.connect(_open_station_upgrades)
	
	# Buy fuel
	btn_buy_fuel.pressed.connect(_open_buy_fuel)
	fuel_slider.value_changed.connect(_on_fuel_slider_changed)
	btn_confirm_buy.pressed.connect(_confirm_buy_fuel)
	
	# Opponents
	btn_opponents.pressed.connect(_open_opponents)
	opponents_list.item_selected.connect(_on_opponent_selected)
	btn_buyout.pressed.connect(_buyout_opponent_station)
	
	# Result
	btn_next.pressed.connect(_on_next_level)
	btn_replay.pressed.connect(_on_replay)
	btn_to_map.pressed.connect(_on_to_map)
	
	# Set initial button states
	_set_speed(2.0)

func _connect_signals() -> void:
	GameManager.currency_changed.connect(_update_cash_display)
	GameManager.stars_changed.connect(_update_cash_display)  # Just refresh

func _initialize_level() -> void:
	level_data = GameManager.current_level_data
	if not level_data:
		push_error("Level: No level data!")
		return
	
	district_data = LevelManager.get_district(level_data.district_id)
	if not district_data:
		push_error("Level: No district data for %s" % level_data.district_id)
		return
	
	# Generate map
	map_data = LevelManager.generate_level_map(level_data)
	
	# Initialize economy
	EconomyManager.initialize_level(level_data, map_data)
	
	# Setup UI
	level_title.text = "%s %d" % [district_data.display_name, level_data.level_number]
	
	# Render map
	_render_map()
	
	# Create stations
	_create_stations()
	
	# Initialize game state
	game_time = 0.0
	level_stats.start_time = Time.get_unix_time_from_system()
	
	# Start simulation
	_set_speed(2.0)
	
	# Play district music/ambient
	AudioManager.play_music(district_data.district_id)
	AudioManager.play_district_ambient(district_data.district_id)

func _render_map() -> void:
	"""Render procedural map using TileMap or custom drawing"""
	# For now, draw simple colored rectangles
	# In production, use TileMap with a proper tileset
	
	var size = map_data.grid_size
	var tile_size = 64  # pixels per tile
	
	# Clear previous
	building_layer.queue_free_children()
	
	# Draw buildings
	for building in map_data.buildings:
		var pos = building.pos * tile_size
		var rect = RectangleShape2D.new()
		rect.size = Vector2(tile_size * 0.9, tile_size * 0.9)
		
		var sprite = Sprite2D.new()
		sprite.position = pos + Vector2(tile_size * 0.5, tile_size * 0.5)
		sprite.modulate = district_data.building_colors[building.type % district_data.building_colors.size()]
		sprite.scale = Vector2(0.9, 0.9)
		# Use a simple colored rect for now
		var rect_node = ColorRect.new()
		rect_node.color = sprite.modulate
		rect_node.custom_minimum_size = Vector2(tile_size * 0.9, tile_size * 0.9)
		rect_node.position = pos + Vector2(tile_size * 0.05, tile_size * 0.05)
		building_layer.add_child(rect_node)
	
	# Draw water
	for water in map_data.water_bodies:
		var center = water.center * tile_size
		var radius = water.radius * tile_size
		# Draw as circle approximation
		var circle = ColorRect.new()
		circle.color = Color(0.2, 0.4, 0.7, 0.8)
		circle.custom_minimum_size = Vector2(radius * 2, radius * 2)
		circle.position = center - Vector2(radius, radius)
		building_layer.add_child(circle)
	
	# Draw parks
	for park in map_data.parks:
		var center = park.center * tile_size
		var radius = park.radius * tile_size
		var circle = ColorRect.new()
		circle.color = Color(0.2, 0.6, 0.3, 0.7)
		circle.custom_minimum_size = Vector2(radius * 2, radius * 2)
		circle.position = center - Vector2(radius, radius)
		building_layer.add_child(circle)
	
	# Draw roads (simple lines)
	for road in map_data.roads:
		if road.orientation == "h":
			var y = road.coord * tile_size + tile_size * 0.5
			var line = ColorRect.new()
			line.color = district_data.road_color
			line.custom_minimum_size = Vector2(size * tile_size, 8)
			line.position = Vector2(0, y - 4)
			road_layer.add_child(line)
		else:
			var x = road.coord * tile_size + tile_size * 0.5
			var line = ColorRect.new()
			line.color = district_data.road_color
			line.custom_minimum_size = Vector2(8, size * tile_size)
			line.position = Vector2(x - 4, 0)
			road_layer.add_child(line)

func _create_stations() -> void:
	"""Create player and opponent station nodes"""
	# Clear existing
	opponent_stations.queue_free_children()
	player_stations_data.clear()
	opponent_data.clear()
	
	# Player station
	var player_pos = map_data.player_start
	var tile_size = 64
	player_station.position = player_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
	player_station.name = "Station_0"
	
	var station_data = {
		"id": 0,
		"node": player_station,
		"pos": player_pos,
		"price": EconomyManager.current_market_price,
		"storage": 5000,
		"fuel": 5000,
		"pumps": 2,
		"level": 1,
		"revenue_hour": 0
	}
	player_stations_data.append(station_data)
	_update_station_ui(0)
	
	# Opponent stations
	for i, opp_station in enumerate(map_data.opponent_stations):
		var comp_id = opp_station.owner_index + 1
		var pos = opp_station.pos
		var archetype_id = opp_station.archetype
		
		# Create station node
		var station_node = _create_station_node(comp_id, pos, archetype_id, false)
		opponent_stations.add_child(station_node)
		
		# Track opponent data
		if not opponent_data.has(comp_id):
			opponent_data[comp_id] = {
				"archetype": archetype_id,
				"stations": [],
				"cash": EconomyManager.competitor_cash.get(comp_id, 30000),
				"price": EconomyManager.competitor_prices.get(comp_id, EconomyManager.current_market_price)
			}
		
		var station_info = {
			"id": opponent_data[comp_id].stations.size(),
			"node": station_node,
			"pos": pos,
			"owner": comp_id
		}
		opponent_data[comp_id].stations.append(station_info)

func _create_station_node(comp_id: int, pos: Vector2i, archetype_id: StringName, is_player: bool) -> Node2D:
	var tile_size = 64
	var node = Node2D.new()
	node.name = "Station_%d_%d" % [comp_id, is_player ? 0 : 1]
	node.position = pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
	
	# Visual
	var sprite = ColorRect.new()
	if is_player:
		sprite.color = Color(0.2, 0.8, 0.3)
	else:
		# Color by archetype
		var colors = {
			"shark": Color(1, 0.3, 0.3),
			"miser": Color(0.7, 0.7, 0.3),
			"opportunist": Color(0.5, 0.5, 1),
			"tycoon": Color(1, 0.8, 0.2),
			"local": Color(0.4, 0.7, 1),
			"green": Color(0.3, 1, 0.4)
		}
		sprite.color = colors.get(archetype_id, Color(0.8, 0.4, 0.8))
	sprite.custom_minimum_size = Vector2(40, 40)
	node.add_child(sprite)
	
	# Label
	var label = Label.new()
	label.text = is_player ? "Я" : archetype_id[0].to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(40, 20)
	label.position = Vector2(-20, 25)
	label.theme_override_font_sizes/font_size = 14
	label.theme_override_colors/font_color = Color(1, 1, 1)
	label.theme_override_colors/font_outline_color = Color(0, 0, 0)
	label.theme_override_constants/outline_size = 2
	node.add_child(label)
	
	# Price label
	var price_label = Label.new()
	price_label.name = "PriceLabel"
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.position = Vector2(-30, -35)
	price_label.custom_minimum_size = Vector2(60, 20)
	price_label.theme_override_font_sizes/font_size = 12
	price_label.theme_override_colors/font_color = Color(1, 1, 1)
	price_label.theme_override_colors/font_outline_color = Color(0, 0, 0)
	price_label.theme_override_constants/outline_size = 1
	node.add_child(price_label)
	
	# Clickable area
	var btn = Button.new()
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	if is_player:
		btn.pressed.connect(_on_player_station_clicked)
	else:
		btn.pressed.connect(_on_opponent_station_clicked.bind(comp_id, opponent_data[comp_id].stations.size() - 1))
	node.add_child(btn)
	
	return node

func _process(delta: float) -> void:
	if is_paused:
		return
	
	# Update game time
	var real_delta = delta * time_speed
	game_time += real_delta / 3600.0  # Convert to hours (assuming 1 sec = 1 hour at 1x)
	simulation_timer += real_delta / 3600.0
	
	# Run simulation every game hour
	if simulation_timer >= simulation_interval:
		_simulate_hour()
		simulation_timer = 0.0
	
	_update_time_display()
	_update_station_displays()

func _simulate_hour() -> void:
	"""Run one hour of economic simulation"""
	var summary = EconomyManager.simulate_hour(1.0)
	
	# Update player stats
	level_stats.fuel_sold += summary.player_fuel_sold
	level_stats.revenue += summary.player_revenue
	
	# Update station fuel levels
	for station in player_stations_data:
		var sold = _calculate_station_sales(station)
		station.fuel -= sold
		station.revenue_hour = sold * station.price
	
	# Check win/lose conditions
	_check_win_condition()
	_check_lose_condition()

func _calculate_station_sales(station: Dictionary) -> int:
	"""Calculate fuel sold by a station this hour"""
	# Simplified - use EconomyManager's simulation
	return 0  # EconomyManager handles this

func _check_win_condition() -> void:
	"""Check if all opponent stations bought"""
	var total_opponent_stations = 0
	for comp_data in opponent_data.values():
		total_opponent_stations += comp_data.stations.size()
	
	if total_opponent_stations == 0:
		_victory()

func _check_lose_condition() -> void:
	"""Check bankruptcy"""
	if GameManager.cash < -10000:
		level_stats.went_bankrupt = true
		_defeat("Банкротство! Деньги закончились.")

func _victory() -> void:
	"""Level completed successfully"""
	is_paused = true
	
	# Calculate stars
	var stars = _calculate_stars()
	
	# Prepare stats
	var completion_time = Time.get_unix_time_from_system() - level_stats.start_time
	var hours = int(completion_time / 3600)
	var mins = int((completion_time % 3600) / 60)
	
	level_stats.completion_time = completion_time
	level_stats.final_cash = GameManager.cash
	
	# Show result
	_show_result(true, stars, level_stats)
	
	# Complete in GameManager
	GameManager.complete_level(stars, level_stats)

func _defeat(reason: String) -> void:
	"""Level failed"""
	is_paused = true
	_show_result(false, 0, level_stats)
	GameManager.fail_level(reason)

func _calculate_stars() -> int:
	"""Calculate stars earned (base + bonuses)"""
	var stars = level_data.base_stars
	
	for condition in level_data.bonus_star_conditions:
		if level_data.is_bonus_condition_met(condition, level_stats):
			stars += 1
	
	return stars

func _show_result(victory: bool, stars: int, stats: Dictionary) -> void:
	if victory:
		result_title.text = "ПОБЕДА!"
		result_title.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		AudioManager.sfx_level_up()
	else:
		result_title.text = "ПОРАЖЕНИЕ"
		result_title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		AudioManager.sfx_error()
	
	# Animate stars
	var star_labels = [result_stars.get_child(i) for i in range(result_stars.get_child_count()) if result_stars.get_child(i) is Label]
	for i, star in enumerate(star_labels):
		star.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if i < stars:
			var tween = create_tween()
			tween.set_delay(i * 0.3)
			tween.tween_property(star, "theme_override_colors/font_color", Color(1, 0.9, 0.2), 0.5)
			tween.tween_callback(AudioManager.sfx_star.bind)
	
	# Stats
	stat_stations.text = str(stats.stations_bought)
	var hours = int(stats.completion_time / 3600)
	var mins = int((stats.completion_time % 3600) / 60)
	stat_time.text = "%02d:%02d" % [hours, mins]
	stat_cash.text = "%s ₽" % _format_number(stats.final_cash)
	stat_revenue.text = "%s ₽" % _format_number(stats.revenue)
	
	# Buttons
	btn_next.visible = victory && LevelManager.get_next_level(level_data.district_id, level_data.level_number) != null
	btn_replay.visible = true
	btn_to_map.visible = true
	
	result_dialog.popup_centered()

# UI Update methods
func _update_time_display() -> void:
	var day = int(game_time / 24) + 1
	var hour = int(game_time % 24)
	time_display.text = "День %d, %02d:00" % [day, hour]

func _update_cash_display() -> void:
	cash_display.text = "%s ₽" % _format_number(GameManager.cash)
	market_price_display.text = "Рынок: %.2f ₽" % EconomyManager.current_market_price

func _update_station_displays() -> void:
	for station in player_stations_data:
		_update_station_ui(station.id)

func _update_station_ui(station_id: int) -> void:
	var station = _get_player_station(station_id)
	if not station:
		return
	
	# Update price label on station node
	var price_label = station.node.get_node_or_null("PriceLabel")
	if price_label:
		price_label.text = "%.2f ₽" % station.price
	
	# Update panel if this station is selected
	if station_id == selected_station_id:
		fuel_value.text = "%d / %d л" % [station.fuel, station.storage]
		revenue_value.text = "%s ₽/ч" % _format_number(station.revenue_hour)
		price_spinbox.value = station.price

func _get_player_station(station_id: int) -> Dictionary:
	for s in player_stations_data:
		if s.id == station_id:
			return s
	return null

# Event handlers
func _set_speed(speed: float) -> void:
	time_speed = speed
	btn_speed1.button_pressed = (speed == 1.0)
	btn_speed2.button_pressed = (speed == 2.0)
	btn_speed3.button_pressed = (speed == 4.0)

func _toggle_pause() -> void:
	is_paused = not is_paused
	btn_pause.button_pressed = is_paused
	btn_pause.text = "▶" if is_paused else "⏸"
	AudioManager.sfx_button_click()

func _toggle_station_panel() -> void:
	if station_panel.visible:
		_close_station_panel()
	else:
		_open_station_panel(0)

func _open_station_panel(station_id: int) -> void:
	selected_station_id = station_id
	var station = _get_player_station(station_id)
	if not station:
		return
	
	fuel_value.text = "%d / %d л" % [station.fuel, station.storage]
	revenue_value.text = "%s ₽/ч" % _format_number(station.revenue_hour)
	price_spinbox.value = station.price
	
	station_panel.visible = true
	AudioManager.sfx_button_click()

func _close_station_panel() -> void:
	station_panel.visible = false

func _on_price_changed(value: float) -> void:
	var station = _get_player_station(selected_station_id)
	if station:
		station.price = value
		# Update label on station
		var price_label = station.node.get_node_or_null("PriceLabel")
		if price_label:
			price_label.text = "%.2f ₽" % value
		EconomyManager.set_player_price(value)
		level_stats.price_changes += 1
		AudioManager.sfx_price_change()

func _open_buy_fuel() -> void:
	var station = _get_player_station(selected_station_id)
	if not station:
		return
	
	var wholesale = EconomyManager.wholesale_price
	wholesale_price_label.text = "Оптовая цена: %.2f ₽/л" % wholesale
	
	var max_buy = station.storage - station.fuel
	fuel_slider.max_value = max_buy
	fuel_slider.value = 0
	_on_fuel_slider_changed(0)
	
	buy_fuel_dialog.popup_centered()
	AudioManager.sfx_button_click()

func _on_fuel_slider_changed(value: float) -> void:
	var wholesale = EconomyManager.wholesale_price
	var cost = int(value * wholesale)
	fuel_amount_label.text = "%d л (%s ₽)" % [int(value), _format_number(cost)]
	btn_confirm_buy.disabled = (value == 0) || (cost > GameManager.cash)

func _confirm_buy_fuel() -> void:
	var amount = int(fuel_slider.value)
	if EconomyManager.buy_fuel(amount):
		var station = _get_player_station(selected_station_id)
		if station:
			station.fuel += amount
		level_stats.fuel_bought += amount
		level_stats.expenses += int(amount * EconomyManager.wholesale_price)
		AudioManager.sfx_cash()
		buy_fuel_dialog.hide()
		_update_station_ui(selected_station_id)

func _open_opponents() -> void:
	opponents_list.clear()
	selected_opponent_id = -1
	
	for comp_id, data in opponent_data:
		var archetype_name = _get_archetype_display_name(data.archetype)
		var station_count = data.stations.size()
		opponents_list.add_item("%s (%d запр.)" % [archetype_name, station_count])
		opponents_list.set_item_metadata(opponents_list.get_item_count() - 1, comp_id)
	
	opponents_dialog.popup_centered()
	AudioManager.sfx_button_click()

func _on_opponent_selected(index: int) -> void:
	selected_opponent_id = opponents_list.get_item_metadata(index)
	_update_opponent_detail()

func _update_opponent_detail() -> void:
	if selected_opponent_id < 0 or not opponent_data.has(selected_opponent_id):
		return
	
	var data = opponent_data[selected_opponent_id]
	var archetype_name = _get_archetype_display_name(data.archetype)
	
	opponent_name.text = archetype_name
	opponent_stations_label.text = "Заправок: %d" % data.stations.size()
	opponent_price_label.text = "Цена: %.2f ₽" % data.price
	
	var buyout_price = _calculate_buyout_price(selected_opponent_id)
	opponent_buyout_label.text = "Выкуп: %s ₽" % _format_number(buyout_price)
	
	btn_buyout.disabled = buyout_price > GameManager.cash
	btn_buyout.text = "ВЫКУПИТЬ ЗАПРАВКУ (%s ₽)" % _format_number(buyout_price)

func _calculate_buyout_price(comp_id: int) -> int:
	var data = opponent_data[comp_id]
	var base = 50000 * data.stations.size()
	var archetype = _get_archetype_data(data.archetype)
	var loyalty = archetype.loyalty if hasattr(archetype, "loyalty") else 1.0
	var rep_factor = 2.0 - GameManager.player_reputation * 0.5
	return int(base * loyalty * rep_factor)

func _buyout_opponent_station() -> void:
	if selected_opponent_id < 0:
		return
	
	var buyout_price = _calculate_buyout_price(selected_opponent_id)
	if GameManager.spend_cash(buyout_price):
		# Remove one station from opponent
		var data = opponent_data[selected_opponent_id]
		if data.stations.size() > 0:
			var station = data.stations.pop_back()
			station.node.queue_free()
			
			# Add to player
			var new_id = player_stations_data.size()
			var new_station = {
				"id": new_id,
				"node": station.node,
				"pos": station.pos,
				"price": EconomyManager.current_market_price,
				"storage": 5000,
				"fuel": 2000,
				"pumps": 2,
				"level": 1,
				"revenue_hour": 0
			}
			player_stations_data.append(new_station)
			
			# Update station visual to player
			var sprite = station.node.get_node("ColorRect")
			if sprite:
				sprite.color = Color(0.2, 0.8, 0.3)
			var label = station.node.get_node("Label")
			if label:
				label.text = "Я"
			
			# Reconnect button
			var btn = station.node.get_node("Button")
			if btn:
				btn.pressed.disconnect()
				btn.pressed.connect(_on_player_station_clicked)
			
			level_stats.stations_bought += 1
			level_stats.opponents_defeated += 1
			
			AudioManager.sfx_station_buy()
			_update_opponent_detail()
			_open_station_panel(new_id)
		else:
			# Opponent eliminated
			opponent_data.erase(selected_opponent_id)
			opponents_list.clear()
			for cid, cdata in opponent_data:
				var name = _get_archetype_display_name(cdata.archetype)
				opponents_list.add_item("%s (%d запр.)" % [name, cdata.stations.size()])
				opponents_list.set_item_metadata(opponents_list.get_item_count() - 1, cid)

func _on_player_station_clicked() -> void:
	_open_station_panel(0)

func _on_opponent_station_clicked(comp_id: int, station_index: int) -> void:
	selected_opponent_id = comp_id
	_open_opponents()
	# Select in list
	for i in range(opponents_list.get_item_count()):
		if opponents_list.get_item_metadata(i) == comp_id:
			opponents_list.select(i)
			opponents_list.ensure_current_is_visible()
			break

func _open_station_upgrades() -> void:
	# Open upgrade tree filtered to station upgrades
	GameManager._game_state_changed(GameManager.GameState.UPGRADE_TREE)
	get_tree().change_scene_to_file("res://scenes/upgrade_tree/upgrade_tree.tscn")

func _on_next_level() -> void:
	AudioManager.sfx_button_click()
	result_dialog.hide()
	var next_level = LevelManager.get_next_level(level_data.district_id, level_data.level_number)
	if next_level:
		GameManager.start_level(next_level)
	else:
		GameManager.go_to_district_map(level_data.district_id)

func _on_replay() -> void:
	AudioManager.sfx_button_click()
	result_dialog.hide()
	GameManager.start_level(level_data)

func _on_to_map() -> void:
	AudioManager.sfx_button_click()
	result_dialog.hide()
	GameManager.go_to_district_map(level_data.district_id)

func _get_archetype_display_name(archetype_id: StringName) -> String:
	var names = {
		"shark": "Акула",
		"miser": "Скупой",
		"opportunist": "Опортунист",
		"tycoon": "Магнат",
		"local": "Местный",
		"green": "Эколог"
	}
	return names.get(archetype_id, str(archetype_id))

func _get_archetype_data(archetype_id: StringName) -> Resource:
	# Would load from OpponentArchetype resource
	return null

func _format_number(num: int) -> String:
	var str = str(num)
	var result = ""
	for i, ch in enumerate(str.reversed()):
		if i > 0 and i % 3 == 0:
			result = " " + result
		result = ch + result
	return result