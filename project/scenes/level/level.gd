## Level.gd
## Core gameplay level - procedural map, economy simulation, station management

extends Node2D

@onready var map_renderer = %MapRenderer
@onready var ground_tilemap = %GroundTileMap
@onready var road_tilemap = %RoadTileMap
@onready var water_tilemap = %WaterTileMap
@onready var park_tilemap = %ParkTileMap
@onready var building_layer = %BuildingLayer
@onready var station_layer = %StationLayer
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
var game_time: float = 0.0
var time_speed: float = 2.0
var is_paused: bool = false

# Station data
var player_stations_data: Array[Dictionary] = []
var opponent_data: Dictionary = {}
var selected_station_id: int = 0
var selected_opponent_id: int = -1

# Stats
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

var simulation_timer: float = 0.0
var simulation_interval: float = 1.0

# TileMap tile IDs (from TileMapSetup)
const TILE = TileMapSetup.TILE_IDS
const TILE_SIZE = 64

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_initialize_level()

func _setup_ui() -> void:
	btn_speed1.pressed.connect(_set_speed.bind(1.0))
	btn_speed2.pressed.connect(_set_speed.bind(2.0))
	btn_speed3.pressed.connect(_set_speed.bind(4.0))
	btn_pause.pressed.connect(_toggle_pause)
	
	btn_station_menu.pressed.connect(_toggle_station_panel)
	close_station_panel.pressed.connect(_close_station_panel)
	price_spinbox.value_changed.connect(_on_price_changed)
	upgrades_btn.pressed.connect(_open_station_upgrades)
	
	btn_buy_fuel.pressed.connect(_open_buy_fuel)
	fuel_slider.value_changed.connect(_on_fuel_slider_changed)
	btn_confirm_buy.pressed.connect(_confirm_buy_fuel)
	
	btn_opponents.pressed.connect(_open_opponents)
	opponents_list.item_selected.connect(_on_opponent_selected)
	btn_buyout.pressed.connect(_buyout_opponent_station)
	
	btn_next.pressed.connect(_on_next_level)
	btn_replay.pressed.connect(_on_replay)
	btn_to_map.pressed.connect(_on_to_map)
	
	_set_speed(2.0)

func _connect_signals() -> void:
	GameManager.currency_changed.connect(_update_cash_display)
	GameManager.stars_changed.connect(_update_cash_display)

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
	
	# Create TileSet and render map
	_setup_tilemaps()
	_render_map_with_tiles()
	
	# Create stations
	_create_stations()
	
	# Initialize game state
	game_time = 0.0
	level_stats.start_time = Time.get_unix_time_from_system()
	
	_set_speed(2.0)
	
	AudioManager.play_music(district_data.district_id)
	AudioManager.play_district_ambient(district_data.district_id)

func _setup_tilemaps() -> void:
	"""Create shared TileSet for all tilemaps"""
	var tile_set = TileMapSetup.create_composite_tile_set()
	
	ground_tilemap.tile_set = tile_set.duplicate()
	road_tilemap.tile_set = tile_set.duplicate()
	water_tilemap.tile_set = tile_set.duplicate()
	park_tilemap.tile_set = tile_set.duplicate()
	
	# Set layers
	ground_tilemap.set_layer_z_index(0, 0)
	road_tilemap.set_layer_z_index(0, 1)
	water_tilemap.set_layer_z_index(0, 1)
	park_tilemap.set_layer_z_index(0, 2)

func _render_map_with_tiles() -> void:
	"""Render procedural map using TileMap"""
	var size = map_data.grid_size
	
	# Clear all layers
	for tm in [ground_tilemap, road_tilemap, water_tilemap, park_tilemap]:
		tm.clear_layer(0)
	
	building_layer.queue_free_children()
	
	# Get district tile palette
	var palette = TileMapSetup.get_district_tiles(district_data.district_id)
	
	# 1. Ground layer - fill base
	var ground_fill = TILE.get(palette.ground[0], TILE.GRASS)
	for y in range(size):
		for x in range(size):
			ground_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(ground_fill % 8, ground_fill / 8))
	
	# 2. Roads
	for road in map_data.roads:
		if road.orientation == "h":
			var tile_id = _get_road_tile("H", palette.ground)
			for x in range(size):
				road_tilemap.set_cell(0, Vector2i(x, road.coord), 0, Vector2i(tile_id % 8, tile_id / 8))
		else:
			var tile_id = _get_road_tile("V", palette.ground)
			for y in range(size):
				road_tilemap.set_cell(0, Vector2i(road.coord, y), 0, Vector2i(tile_id % 8, tile_id / 8))
	
	# 3. Intersections (where H and V roads cross)
	for road_h in map_data.roads:
		if road_h.orientation != "h": continue
		for road_v in map_data.roads:
			if road_v.orientation != "v": continue
			var ix = road_v.coord
			var iy = road_h.coord
			var tile_id = _get_intersection_tile(palette.ground)
			road_tilemap.set_cell(0, Vector2i(ix, iy), 0, Vector2i(tile_id % 8, tile_id / 8))
	
	# 4. Water bodies
	for water in map_data.water_bodies:
		var cx = water.center.x
		var cy = water.center.y
		var r = water.radius
		var tile_id = TILE.WATER_SHALLOW
		if r > 2: tile_id = TILE.WATER_DEEP
		
		for y in range(max(0, cy - r), min(size, cy + r + 1)):
			for x in range(max(0, cx - r), min(size, cx + r + 1)):
				var dist = Vector2(x - cx, y - cy).length()
				if dist <= r:
					water_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(tile_id % 8, tile_id / 8))
					# Shore transition
					if dist > r - 1.5 and dist <= r:
						water_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(TILE.WATER_SHORE % 8, TILE.WATER_SHORE / 8))
	
	# 5. Parks
	for park in map_data.parks:
		var cx = park.center.x
		var cy = park.center.y
		var r = park.radius
		var tile_id = TILE.PARK_GRASS_PARK
		
		for y in range(max(0, cy - r), min(size, cy + r + 1)):
			for x in range(max(0, cx - r), min(size, cx + r + 1)):
				var dist = Vector2(x - cx, y - cy).length()
				if dist <= r:
					park_tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(tile_id % 8, tile_id / 8))
	
	# 6. Buildings (as sprites for variety)
	for building in map_data.buildings:
		_create_building_sprite(building)
	
	# 7. Special: crosswalks at high-traffic intersections
	for node in map_data.traffic_nodes:
		if node.value > 100:
			var pos = node.pos
			road_tilemap.set_cell(0, pos, 0, Vector2i(TILE.CROSSWALK % 8, TILE.CROSSWALK / 8))

func _get_road_tile(orientation: String, ground_tiles: Array[String]) -> int:
	"""Get appropriate road tile ID for district"""
	var base = "ROAD_BASE"
	if "HIGHWAY" in ground_tiles: base = "HIGHWAY"
	elif "DIRT_ROAD" in ground_tiles: base = "DIRT_ROAD"
	elif "COBBLESTONE" in ground_tiles: base = "COBBLESTONE"
	
	return TILE.get("%s_%s" % [base, orientation], TILE.get("%s_H" % base, TILE.ROAD_BASE))

func _get_intersection_tile(ground_tiles: Array[String]) -> int:
	var base = "INTERSECTION"
	if "HIGHWAY" in ground_tiles: base = "HIGHWAY_INTERSECTION"
	elif "DIRT_ROAD" in ground_tiles: base = "DIRT_INTERSECTION"
	elif "COBBLESTONE" in ground_tiles: base = "COBBLESTONE_INTERSECTION"
	return TILE.get(base, TILE.INTERSECTION_SOLID)

func _create_building_sprite(building: Dictionary) -> void:
	var tile_size = TILE_SIZE
	var pos = building.pos * tile_size
	
	# Use ColorRect with district colors for now
	# In production, use Sprite2D with building atlas
	var rect = ColorRect.new()
	rect.color = district_data.building_colors[building.type % district_data.building_colors.size()]
	rect.custom_minimum_size = Vector2(tile_size * 0.85, tile_size * 0.85)
	rect.position = pos + Vector2(tile_size * 0.075, tile_size * 0.075)
	building_layer.add_child(rect)
	
	# Add subtle variation
	rect.modulate = rect.color * Color(0.9 + randf() * 0.2, 0.9 + randf() * 0.2, 0.9 + randf() * 0.2, 1)

func _create_stations() -> void:
	opponent_stations.queue_free_children()
	player_stations_data.clear()
	opponent_data.clear()
	
	# Player station
	var player_pos = map_data.player_start
	_create_station_node(0, player_pos, "standard", true, 0)
	
	var station_data = {
		"id": 0,
		"node": station_layer.get_node("Station_0"),
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
		
		var station_type = _archetype_to_station_type(archetype_id)
		_create_station_node(comp_id, pos, station_type, false, i)
		
		if not opponent_data.has(comp_id):
			opponent_data[comp_id] = {
				"archetype": archetype_id,
				"stations": [],
				"cash": EconomyManager.competitor_cash.get(comp_id, 30000),
				"price": EconomyManager.competitor_prices.get(comp_id, EconomyManager.current_market_price)
			}
		
		var new_station = station_layer.get_node("Station_%d_%d" % [comp_id, i])
		var station_info = {
			"id": opponent_data[comp_id].stations.size(),
			"node": new_station,
			"pos": pos,
			"owner": comp_id
		}
		opponent_data[comp_id].stations.append(station_info)

func _create_station_node(comp_id: int, pos: Vector2i, station_type: String, is_player: bool, index: int) -> void:
	var tile_size = TILE_SIZE
	var node = StationNode.new()
	node.name = "Station_%d_%d" % [comp_id, index]
	node.station_id = comp_id * 10 + index
	node.is_player_station = is_player
	node.station_type = station_type
	if not is_player:
		node.owner_archetype = map_data.opponent_stations[index].archetype
	node.position = pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)
	
	node.station_clicked.connect(_on_station_clicked)
	node.station_hovered.connect(_on_station_hovered)
	
	station_layer.add_child(node)
	node.ready.connect(node._ready.bind())

func _archetype_to_station_type(archetype: StringName) -> String:
	var mapping = {
		"shark": "shark",
		"miser": "miser",
		"opportunist": "opportunist",
		"tycoon": "tycoon",
		"local": "local",
		"green": "green",
	}
	return mapping.get(archetype, "standard")

func _process(delta: float) -> void:
	if is_paused: return
	
	var real_delta = delta * time_speed
	game_time += real_delta / 3600.0
	simulation_timer += real_delta / 3600.0
	
	if simulation_timer >= simulation_interval:
		_simulate_hour()
		simulation_timer = 0.0
	
	_update_time_display()
	_update_station_displays()

func _simulate_hour() -> void:
	var summary = EconomyManager.simulate_hour(1.0)
	level_stats.fuel_sold += summary.player_fuel_sold
	level_stats.revenue += summary.player_revenue
	
	for station in player_stations_data:
		var sold = _calculate_station_sales(station)
		station.fuel -= sold
		station.revenue_hour = sold * station.price
	
	_check_win_condition()
	_check_lose_condition()

func _calculate_station_sales(station: Dictionary) -> int:
	return 0

func _check_win_condition() -> void:
	var total = 0
	for data in opponent_data.values():
		total += data.stations.size()
	if total == 0:
		_victory()

func _check_lose_condition() -> void:
	if GameManager.cash < -10000:
		level_stats.went_bankrupt = true
		_defeat("Банкротство! Деньги закончились.")

func _victory() -> void:
	is_paused = true
	var stars = _calculate_stars()
	var completion_time = Time.get_unix_time_from_system() - level_stats.start_time
	
	level_stats.completion_time = completion_time
	level_stats.final_cash = GameManager.cash
	
	_show_result(true, stars, level_stats)
	GameManager.complete_level(stars, level_stats)

func _defeat(reason: String) -> void:
	is_paused = true
	_show_result(false, 0, level_stats)
	GameManager.fail_level(reason)

func _calculate_stars() -> int:
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
	
	var star_labels = [result_stars.get_child(i) for i in range(result_stars.get_child_count()) if result_stars.get_child(i) is Label]
	for i, star in enumerate(star_labels):
		star.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if i < stars:
			var tween = create_tween()
			tween.set_delay(i * 0.3)
			tween.tween_property(star, "theme_override_colors/font_color", Color(1, 0.9, 0.2), 0.5)
			tween.tween_callback(AudioManager.sfx_star.bind)
	
	stat_stations.text = str(stats.stations_bought)
	var hours = int(stats.completion_time / 3600)
	var mins = int((stats.completion_time % 3600) / 60)
	stat_time.text = "%02d:%02d" % [hours, mins]
	stat_cash.text = "%s ₽" % _format_number(stats.final_cash)
	stat_revenue.text = "%s ₽" % _format_number(stats.revenue)
	
	btn_next.visible = victory && LevelManager.get_next_level(level_data.district_id, level_data.level_number) != null
	btn_replay.visible = true
	btn_to_map.visible = true
	
	result_dialog.popup_centered()

# Station event handlers
func _on_station_clicked(station_id: int, is_player: bool) -> void:
	if is_player:
		_open_station_panel(0)
	else:
		var comp_id = station_id / 10
		selected_opponent_id = comp_id
		_open_opponents()
		for i in range(opponents_list.get_item_count()):
			if opponents_list.get_item_metadata(i) == comp_id:
				opponents_list.select(i)
				opponents_list.ensure_current_is_visible()
				break

func _on_station_hovered(station_id: int, is_player: bool, entered: bool) -> void:
	if entered:
		AudioManager.sfx_button_hover()

# UI Updates
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
	if not station: return
	
	var node = station.node
	if node:
		node.update_display(station.price, station.fuel, station.storage, station.level)
	
	if station_id == selected_station_id:
		fuel_value.text = "%d / %d л" % [station.fuel, station.storage]
		revenue_value.text = "%s ₽/ч" % _format_number(station.revenue_hour)
		price_spinbox.value = station.price

func _get_player_station(station_id: int) -> Dictionary:
	for s in player_stations_data:
		if s.id == station_id: return s
	return null

# Control handlers
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
	if station_panel.visible: _close_station_panel()
	else: _open_station_panel(0)

func _open_station_panel(station_id: int) -> void:
	selected_station_id = station_id
	var station = _get_player_station(station_id)
	if not station: return
	
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
		var node = station.node
		if node: node.update_display(value, station.fuel, station.storage, station.level)
		EconomyManager.set_player_price(value)
		level_stats.price_changes += 1
		AudioManager.sfx_price_change()

func _open_buy_fuel() -> void:
	var station = _get_player_station(selected_station_id)
	if not station: return
	
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
		var name = _get_archetype_display_name(data.archetype)
		opponents_list.add_item("%s (%d запр.)" % [name, data.stations.size()])
		opponents_list.set_item_metadata(opponents_list.get_item_count() - 1, comp_id)
	
	opponents_dialog.popup_centered()
	AudioManager.sfx_button_click()

func _on_opponent_selected(index: int) -> void:
	selected_opponent_id = opponents_list.get_item_metadata(index)
	_update_opponent_detail()

func _update_opponent_detail() -> void:
	if selected_opponent_id < 0 or not opponent_data.has(selected_opponent_id): return
	
	var data = opponent_data[selected_opponent_id]
	var name = _get_archetype_display_name(data.archetype)
	
	opponent_name.text = name
	opponent_stations_label.text = "Заправок: %d" % data.stations.size()
	opponent_price_label.text = "Цена: %.2f ₽" % data.price
	
	var buyout = _calculate_buyout_price(selected_opponent_id)
	opponent_buyout_label.text = "Выкуп: %s ₽" % _format_number(buyout)
	
	btn_buyout.disabled = buyout > GameManager.cash
	btn_buyout.text = "ВЫКУПИТЬ ЗАПРАВКУ (%s ₽)" % _format_number(buyout)

func _calculate_buyout_price(comp_id: int) -> int:
	var data = opponent_data[comp_id]
	var base = 50000 * data.stations.size()
	var archetype = _get_archetype_data(data.archetype)
	var loyalty = archetype.loyalty if hasattr(archetype, "loyalty") else 1.0
	var rep = 2.0 - GameManager.player_reputation * 0.5
	return int(base * loyalty * rep)

func _buyout_opponent_station() -> void:
	if selected_opponent_id < 0: return
	
	var buyout = _calculate_buyout_price(selected_opponent_id)
	if GameManager.spend_cash(buyout):
		var data = opponent_data[selected_opponent_id]
		if data.stations.size() > 0:
			var station = data.stations.pop_back()
			station.node.play_purchase_animation()
			await get_tree().create_timer(0.4).timeout
			station.node.queue_free()
			
			var new_id = player_stations_data.size()
			var new_station = {
				"id": new_id,
				"node": _create_station_node(0, station.pos, "standard", true, new_id),
				"pos": station.pos,
				"price": EconomyManager.current_market_price,
				"storage": 5000,
				"fuel": 2000,
				"pumps": 2,
				"level": 1,
				"revenue_hour": 0
			}
			player_stations_data.append(new_station)
			
			level_stats.stations_bought += 1
			level_stats.opponents_defeated += 1
			AudioManager.sfx_station_buy()
			_update_opponent_detail()
			_open_station_panel(new_id)
		else:
			opponent_data.erase(selected_opponent_id)
			opponents_list.clear()
			for cid, cdata in opponent_data:
				var n = _get_archetype_display_name(cdata.archetype)
				opponents_list.add_item("%s (%d запр.)" % [n, cdata.stations.size()])
				opponents_list.set_item_metadata(opponents_list.get_item_count() - 1, cid)

func _open_station_upgrades() -> void:
	GameManager._game_state_changed(GameManager.GameState.UPGRADE_TREE)
	get_tree().change_scene_to_file("res://scenes/upgrade_tree/upgrade_tree.tscn")

func _on_next_level() -> void:
	AudioManager.sfx_button_click()
	result_dialog.hide()
	var next_level = LevelManager.get_next_level(level_data.district_id, level_data.level_number)
	if next_level: GameManager.start_level(next_level)
	else: GameManager.go_to_district_map(level_data.district_id)

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
		"shark": "Акула", "miser": "Скупой", "opportunist": "Опортунист",
		"tycoon": "Магнат", "local": "Местный", "green": "Эколог"
	}
	return names.get(archetype_id, str(archetype_id))

func _get_archetype_data(archetype_id: StringName) -> Resource:
	return null

func _format_number(num: int) -> String:
	var str = str(num)
	var result = ""
	for i, ch in enumerate(str.reversed()):
		if i > 0 and i % 3 == 0: result = " " + result
		result = ch + result
	return result