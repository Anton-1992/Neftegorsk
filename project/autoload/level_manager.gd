## LevelManager.gd
## Manages districts, levels, procedural generation, and unlock progression

extends Node

class_name LevelManager

signal level_unlocked(level_id: StringName)
signal district_unlocked(district_id: StringName)

# Registry of all districts and levels
var districts: Dictionary = {}  # district_id -> DistrictData
var levels: Dictionary = {}     # level_id -> LevelData
var locked_levels: Array[StringName] = []
var locked_districts: Array[StringName] = []

# Generation cache
var generated_maps: Dictionary = {}  # level_id -> generated map data

func _ready() -> void:
	DebugLogger.log_node_ready("LevelManager", true, "start _ready")
	_initialize_districts()
	_initialize_levels()
	_apply_unlocks_from_save()
	DebugLogger.log_node_ready("LevelManager", true, "done")

func _initialize_districts() -> void:
	# Define all districts with progression order
	var district_order = [
		"business_center",
		"historic",
		"residential",
		"industrial",
		"waterfront",
		"suburban",
		"port",
		"airport",
		"university",
		"tourist"
	]
	
	# Business Center - dense, high traffic, aggressive opponents
	var dc = DistrictData.new()
	dc.district_id = "business_center"
	dc.display_name = "Деловой центр"
	dc.description = "Небоскрёбы, бизнес-центры, плотный трафик. Высокая конкуренция, дорогие аренды."
	dc.background_color = Color(0.25, 0.25, 0.35)
	dc.road_color = Color(0.15, 0.15, 0.2)
	dc.building_colors = [Color(0.3, 0.3, 0.4), Color(0.25, 0.3, 0.35), Color(0.35, 0.3, 0.35)]
	dc.density = 0.9
	dc.road_complexity = 0.8
	dc.grid_size = 8
	dc.traffic_base = 90
	dc.fuel_demand_multiplier = 1.4
	dc.land_price_multiplier = 2.0
	dc.opponent_aggression = 1.3
	dc.starting_capital_bonus = 20000
	dc.upgrade_cost_multiplier = 1.2
	dc.allowed_opponent_types = ["miser", "opportunist", "shark"]
	dc.min_opponents = 1
	dc.max_opponents = 3
	dc.opponent_station_count_range = Vector2i(1, 2)
	dc.required_stars_total = 0
	dc.levels_per_district = 4
	districts["business_center"] = dc
	
	# Historic District - narrow streets, tourism, moderate traffic
	var hd = DistrictData.new()
	hd.district_id = "historic"
	hd.display_name = "Исторический центр"
	hd.description = "Узкие улочки, достопримечательности, туристы. Сложная логистика, лояльные клиенты."
	hd.background_color = Color(0.35, 0.3, 0.25)
	hd.road_color = Color(0.25, 0.2, 0.15)
	hd.building_colors = [Color(0.5, 0.4, 0.3), Color(0.45, 0.35, 0.25), Color(0.55, 0.45, 0.35)]
	hd.density = 0.7
	hd.road_complexity = 0.9
	hd.grid_size = 7
	hd.park_areas = 2
	hd.traffic_base = 60
	hd.fuel_demand_multiplier = 1.1
	hd.land_price_multiplier = 1.5
	hd.opponent_aggression = 0.9
	hd.starting_capital_bonus = 5000
	hd.upgrade_cost_multiplier = 1.0
	hd.allowed_opponent_types = ["miser", "local", "opportunist"]
	hd.min_opponents = 1
	hd.max_opponents = 2
	hd.opponent_station_count_range = Vector2i(1, 2)
	hd.required_stars_total = 6  # Need 6 stars from business center
	hd.required_previous_district = "business_center"
	hd.levels_per_district = 4
	districts["historic"] = hd
	
	# Residential - spread out, steady demand, defensive opponents
	var rd = DistrictData.new()
	rd.district_id = "residential"
	rd.display_name = "Спальный район"
	rd.description = "Жилые комплексы, школы, магазины. Ровный спрос, предсказуемые пути."
	rd.background_color = Color(0.3, 0.35, 0.3)
	rd.road_color = Color(0.2, 0.25, 0.2)
	rd.building_colors = [Color(0.4, 0.5, 0.4), Color(0.35, 0.45, 0.35), Color(0.45, 0.5, 0.4)]
	rd.density = 0.6
	rd.road_complexity = 0.4
	rd.grid_size = 9
	rd.park_areas = 3
	rd.traffic_base = 50
	rd.fuel_demand_multiplier = 1.0
	rd.land_price_multiplier = 0.8
	rd.opponent_aggression = 0.7
	rd.starting_capital_bonus = 0
	rd.upgrade_cost_multiplier = 0.9
	rd.allowed_opponent_types = ["miser", "local"]
	rd.min_opponents = 1
	rd.max_opponents = 2
	rd.opponent_station_count_range = Vector2i(1, 1)
	rd.required_stars_total = 10
	rd.required_previous_district = "historic"
	rd.levels_per_district = 4
	districts["residential"] = rd
	
	# Industrial - heavy traffic, trucks, high volume, low margin
	var id_ = DistrictData.new()
	id_.district_id = "industrial"
	id_.display_name = "Промзона"
	id_.description = "Заводы, склады, грузовики. Объёмный спрос, низкие маржи, суровые конкуренты."
	id_.background_color = Color(0.25, 0.25, 0.3)
	id_.road_color = Color(0.18, 0.18, 0.22)
	id_.building_colors = [Color(0.35, 0.35, 0.4), Color(0.3, 0.3, 0.35), Color(0.4, 0.35, 0.35)]
	id_.density = 0.5
	id_.road_complexity = 0.5
	id_.grid_size = 10
	id_.water_bodies = 1
	id_.traffic_base = 70
	id_.fuel_demand_multiplier = 1.6
	id_.land_price_multiplier = 0.6
	id_.opponent_aggression = 1.5
	id_.starting_capital_bonus = 10000
	id_.upgrade_cost_multiplier = 1.1
	id_.allowed_opponent_types = ["shark", "tycoon", "opportunist"]
	id_.min_opponents = 2
	id_.max_opponents = 4
	id_.opponent_station_count_range = Vector2i(1, 3)
	id_.required_stars_total = 16
	id_.required_previous_district = "residential"
	id_.levels_per_district = 4
	districts["industrial"] = id_
	
	# Waterfront - premium, tourists, seasonal, eco-conscious
	var wd = DistrictData.new()
	wd.district_id = "waterfront"
	wd.display_name = "Прибрежный район"
	wd.description = "Набережные, яхт-клубы, рестораны. Премиум-аудитория, сезонность, эко-тренды."
	wd.background_color = Color(0.2, 0.35, 0.45)
	wd.road_color = Color(0.15, 0.25, 0.35)
	wd.building_colors = [Color(0.3, 0.5, 0.6), Color(0.25, 0.45, 0.55), Color(0.35, 0.55, 0.65)]
	wd.density = 0.4
	wd.road_complexity = 0.6
	wd.grid_size = 8
	wd.water_bodies = 3
	wd.park_areas = 2
	wd.traffic_base = 55
	wd.fuel_demand_multiplier = 1.2
	wd.land_price_multiplier = 1.8
	wd.opponent_aggression = 0.8
	wd.starting_capital_bonus = 15000
	wd.upgrade_cost_multiplier = 1.3
	wd.allowed_opponent_types = ["local", "green", "opportunist"]
	wd.min_opponents = 1
	wd.max_opponents = 3
	wd.opponent_station_count_range = Vector2i(1, 2)
	wd.required_stars_total = 24
	wd.required_previous_district = "industrial"
	wd.levels_per_district = 3
	districts["waterfront"] = wd
	
	# Suburban - spread out, car-dependent, family vehicles
	var sd = DistrictData.new()
	sd.district_id = "suburban"
	sd.display_name = "Пригород"
	sd.description = "Дачи, коттеджи, шоссе. Машина у каждой семьи, долгие поездки, верные клиенты."
	sd.background_color = Color(0.35, 0.4, 0.3)
	sd.road_color = Color(0.25, 0.3, 0.2)
	sd.building_colors = [Color(0.5, 0.55, 0.45), Color(0.45, 0.5, 0.4), Color(0.55, 0.6, 0.5)]
	sd.density = 0.3
	sd.road_complexity = 0.3
	sd.grid_size = 10
	sd.park_areas = 4
	sd.water_bodies = 2
	sd.traffic_base = 40
	sd.fuel_demand_multiplier = 0.9
	sd.land_price_multiplier = 0.5
	sd.opponent_aggression = 0.6
	sd.starting_capital_bonus = -5000
	sd.upgrade_cost_multiplier = 0.8
	sd.allowed_opponent_types = ["local", "miser"]
	sd.min_opponents = 1
	sd.max_opponents = 2
	sd.opponent_station_count_range = Vector2i(1, 1)
	sd.required_stars_total = 30
	sd.required_previous_district = "waterfront"
	sd.levels_per_district = 3
	districts["suburban"] = sd
	
	# Additional districts for extended content
	# Port - logistics, trucks, containers
	var pd = DistrictData.new()
	pd.district_id = "port"
	pd.display_name = "Портовый район"
	pd.description = "Контейнерные терминалы, фуры, логистика. Огромные объёмы дизеля."
	pd.background_color = Color(0.2, 0.3, 0.35)
	pd.road_color = Color(0.15, 0.2, 0.25)
	pd.building_colors = [Color(0.35, 0.4, 0.45), Color(0.3, 0.35, 0.4), Color(0.4, 0.45, 0.5)]
	pd.density = 0.45
	pd.road_complexity = 0.7
	pd.grid_size = 9
	pd.water_bodies = 2
	pd.traffic_base = 85
	pd.fuel_demand_multiplier = 1.8
	pd.land_price_multiplier = 0.7
	pd.opponent_aggression = 1.4
	pd.starting_capital_bonus = 25000
	pd.upgrade_cost_multiplier = 1.1
	pd.allowed_opponent_types = ["shark", "tycoon", "local"]
	pd.min_opponents = 2
	pd.max_opponents = 4
	pd.opponent_station_count_range = Vector2i(2, 3)
	pd.required_stars_total = 36
	pd.required_previous_district = "suburban"
	pd.levels_per_district = 3
	districts["port"] = pd
	
	# Airport - aviation fuel, premium, high security
	var ad = DistrictData.new()
	ad.district_id = "airport"
	ad.display_name = "Аэропорт"
	ad.description = "Авиатопливо, такси, шаттлы. Высокие требования, премиум-маржи."
	ad.background_color = Color(0.3, 0.3, 0.4)
	ad.road_color = Color(0.2, 0.2, 0.3)
	ad.building_colors = [Color(0.4, 0.4, 0.5), Color(0.35, 0.35, 0.45), Color(0.45, 0.45, 0.55)]
	ad.density = 0.4
	ad.road_complexity = 0.5
	ad.grid_size = 8
	ad.traffic_base = 65
	ad.fuel_demand_multiplier = 1.3
	ad.land_price_multiplier = 2.5
	ad.opponent_aggression = 1.0
	ad.starting_capital_bonus = 30000
	ad.upgrade_cost_multiplier = 1.5
	ad.allowed_opponent_types = ["tycoon", "green", "opportunist"]
	ad.min_opponents = 1
	ad.max_opponents = 2
	ad.opponent_station_count_range = Vector2i(1, 2)
	ad.required_stars_total = 42
	ad.required_previous_district = "port"
	ad.levels_per_district = 2
	districts["airport"] = ad
	
	# University - students, cheap fuel, bicycles, scooters
	var ud = DistrictData.new()
	ud.district_id = "university"
	ud.display_name = "Университетский городок"
	ud.description = "Студенты, бюджетное топливо, электросамокаты, велодорожки."
	ud.background_color = Color(0.3, 0.4, 0.35)
	ud.road_color = Color(0.2, 0.3, 0.25)
	ud.building_colors = [Color(0.4, 0.55, 0.45), Color(0.35, 0.5, 0.4), Color(0.45, 0.6, 0.5)]
	ud.density = 0.65
	ud.road_complexity = 0.6
	ud.grid_size = 7
	ud.park_areas = 3
	ud.traffic_base = 45
	ud.fuel_demand_multiplier = 0.8
	ud.land_price_multiplier = 0.9
	ud.opponent_aggression = 0.5
	ud.starting_capital_bonus = 0
	ud.upgrade_cost_multiplier = 0.85
	ud.allowed_opponent_types = ["miser", "green", "opportunist"]
	ud.min_opponents = 1
	ud.max_opponents = 2
	ud.opponent_station_count_range = Vector2i(1, 1)
	ud.required_stars_total = 46
	ud.required_previous_district = "airport"
	ud.levels_per_district = 2
	districts["university"] = ud
	
	# Tourist - seasonal, high variance, souvenir shops
	var td = DistrictData.new()
	td.district_id = "tourist"
	td.display_name = "Туристический центр"
	td.description = "Отели, музеи, сувенирки. Сезонный пик, кэш-флоу только летом."
	td.background_color = Color(0.4, 0.35, 0.3)
	td.road_color = Color(0.3, 0.25, 0.2)
	td.building_colors = [Color(0.6, 0.5, 0.4), Color(0.55, 0.45, 0.35), Color(0.65, 0.55, 0.45)]
	td.density = 0.55
	td.road_complexity = 0.7
	td.grid_size = 8
	td.park_areas = 2
	td.water_bodies = 1
	td.traffic_base = 50  # Off-season, peaks to 120
	td.fuel_demand_multiplier = 1.0
	td.land_price_multiplier = 1.4
	td.opponent_aggression = 0.9
	td.starting_capital_bonus = 10000
	td.upgrade_cost_multiplier = 1.0
	td.allowed_opponent_types = ["local", "opportunist", "shark"]
	td.min_opponents = 1
	td.max_opponents = 3
	td.opponent_station_count_range = Vector2i(1, 2)
	td.required_stars_total = 50
	td.required_previous_district = "university"
	td.levels_per_district = 2
	districts["tourist"] = td

func _initialize_levels() -> void:
	# Create levels for each district
	for district_id in districts:
		var district = districts[district_id]
		var opponent_pool = district.allowed_opponent_types
		
		for i in range(1, district.levels_per_district + 1):
			var level_id = LevelData.create_level_id(district_id, i)
			var level = LevelData.new()
			level.level_id = level_id
			level.district_id = district_id
			level.level_number = i
			level.display_name = "%s %d".format([district.display_name, i])
			
			# Progressive difficulty within district
			var progress = (i - 1) / max(1, district.levels_per_district - 1)
			
			# Opponent count scales
			var opp_count = district.min_opponents + int(progress * (district.max_opponents - district.min_opponents))
			level.forced_opponent_count = opp_count
			
			# Opponent types unlock progressively
			var available_types = opponent_pool.slice(0, min(opponent_pool.size(), 1 + int(progress * (opponent_pool.size() - 1))))
			level.forced_opponent_types = available_types
			
			# Economy scales
			level.player_starting_cash = 50000 + district.starting_capital_bonus + int(progress * 15000)
			level.opponent_starting_cash = 30000 + int(progress * 20000)
			level.market_base_price = 50.0 * district.fuel_demand_multiplier
			level.daily_costs_multiplier = 1.0 + progress * 0.5
			
			# Rewards scale
			level.base_stars = 3
			if i == district.levels_per_district:
				level.base_stars = 4  # Boss level gives more stars
			
			# Bonus stars
			level.bonus_star_conditions = [
				{"type": "time", "threshold": 600 - int(progress * 200)},  # Faster = bonus
				{"type": "cash", "threshold": level.player_starting_cash * 3},
				{"type": "no_bankruptcy", "threshold": 1}
			]
			
			# Narrative
			level.intro_dialogue = _generate_intro_dialogue(district_id, i, opp_count)
			level.outro_dialogue_victory = "Район завоёван! Конкуренты ушли с убытками."
			level.outro_dialogue_defeat = "Бизнес обанкротился. Попробуйте другую стратегию."
			
			levels[level_id] = level
			
			# Lock all except first level of first district
			if district_id != "business_center" or i != 1:
				locked_levels.append(level_id)

func _generate_intro_dialogue(district_id: StringName, level_num: int, opp_count: int) -> String:
	var district = districts[district_id]
	var opp_text = "один противник" if opp_count == 1 else "%d противника".format([opp_count])
	return "Добро пожаловать в %s! Уровень %d. Ваша задача: выкупить %s.".format([district.display_name, level_num, opp_text])

func _apply_unlocks_from_save() -> void:
	# Called after GameManager loads save data
	# GameManager will call unlock_level/unlock_district as needed
	pass

func get_district(district_id: StringName) -> DistrictData:
	return districts.get(district_id)

func get_level(level_id: StringName) -> LevelData:
	return levels.get(level_id)

func get_districts_in_order() -> Array[DistrictData]:
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", 
	             "suburban", "port", "airport", "university", "tourist"]
	var result = []
	for id in order:
		if districts.has(id):
			result.append(districts[id])
	return result

func get_levels_for_district(district_id: StringName) -> Array[LevelData]:
	var result = []
	var district = districts.get(district_id)
	if not district:
		return result
	
	for i in range(1, district.levels_per_district + 1):
		var lid = LevelData.create_level_id(district_id, i)
		if levels.has(lid):
			result.append(levels[lid])
	return result

func get_next_level(district_id: StringName, current_level_num: int) -> LevelData:
	var next_num = current_level_num + 1
	var district = districts.get(district_id)
	if not district or next_num > district.levels_per_district:
		return null
	var lid = LevelData.create_level_id(district_id, next_num)
	return levels.get(lid)

func get_next_district(current_district_id: StringName) -> DistrictData:
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", 
	             "suburban", "port", "airport", "university", "tourist"]
	var idx = order.find(current_district_id)
	if idx >= 0 and idx + 1 < order.size():
		return districts.get(order[idx + 1])
	return null

func unlock_level(level_id: StringName) -> void:
	if level_id in locked_levels:
		locked_levels.remove(level_id)
		level_unlocked.emit(level_id)

func unlock_district(district_id: StringName) -> void:
	if district_id in locked_districts:
		locked_districts.remove(district_id)
	district_unlocked.emit(district_id)

func is_level_unlocked(level_id: StringName) -> bool:
	return level_id not in locked_levels

func is_district_unlocked(district_id: StringName) -> bool:
	return district_id not in locked_districts

func generate_level_map(level_data: LevelData, force_new_seed: bool = false) -> Dictionary:
	"""Procedurally generate a level map based on district parameters"""
	var cache_key = "%s_%d".format([level_data.level_id, level_data.seed])
	if not force_new_seed and generated_maps.has(cache_key):
		return generated_maps[cache_key]
	
	var district = districts.get(level_data.district_id)
	if not district:
		return {}
	
	# Use level seed or generate new one
	var seed = level_data.seed if level_data.seed != 0 else randi()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	var grid_size = level_data.forced_grid_size if level_data.forced_grid_size > 0 else district.grid_size
	var map_data = {
		"seed": seed,
		"grid_size": grid_size,
		"district_id": level_data.district_id,
		"level_id": level_data.level_id,
		"tiles": [],      # Grid tiles: 0=empty, 1=road, 2=building, 3=water, 4=park, 5=player_station, 6=opponent_station
		"roads": [],      # Road network graph
		"buildings": [],  # Building footprints
		"water_bodies": [],
		"parks": [],
		"player_start": Vector2i(0, 0),
		"opponent_stations": [],
		"traffic_nodes": [],  # High traffic intersections
		"land_values": []     # Per-tile land price multipliers
	}
	
	# Generate base terrain
	_generate_terrain(map_data, district, rng)
	
	# Generate road network
	_generate_roads(map_data, district, rng)
	
	# Place buildings
	_generate_buildings(map_data, district, rng)
	
	# Place water and parks
	_generate_features(map_data, district, rng)
	
	# Calculate traffic heatmap
	_calculate_traffic(map_data, district, rng)
	
	# Place player starting station (always at a good location)
	_place_player_station(map_data, district, rng)
	
	# Place opponent stations
	_place_opponent_stations(map_data, district, level_data, rng)
	
	# Calculate land values
	_calculate_land_values(map_data, district)
	
	generated_maps[cache_key] = map_data
	return map_data

func _generate_terrain(map_data: Dictionary, district: DistrictData, rng: RandomNumberGenerator) -> void:
	var size = map_data.grid_size
	map_data.tiles = []
	for y in range(size):
		row = []
		for x in range(size):
			row.append(0)  # Empty
		map_data.tiles.append(row)

func _generate_roads(map_data: Dictionary, district: DistrictData, rng: RandomNumberGenerator) -> void:
	var size = map_data.grid_size
	var complexity = district.road_complexity
	
	# Main arteries - always connect edges
	var main_roads = max(2, int(complexity * 4))
	
	# Horizontal main roads
	for i in range(main_roads):
		var y = rng.randi_range(1, size - 2)
		for x in range(size):
			if map_data.tiles[y][x] == 0:
				map_data.tiles[y][x] = 1  # Road
		map_data.roads.append({"type": "main", "orientation": "h", "coord": y})
	
	# Vertical main roads
	for i in range(main_roads):
		var x = rng.randi_range(1, size - 2)
		for y in range(size):
			if map_data.tiles[y][x] == 0:
				map_data.tiles[y][x] = 1
		map_data.roads.append({"type": "main", "orientation": "v", "coord": x})
	
	# Secondary roads (branching)
	var secondary_count = int(complexity * size * 0.5)
	for i in range(secondary_count):
		var x = rng.randi_range(1, size - 2)
		var y = rng.randi_range(1, size - 2)
		var length = rng.randi_range(2, 5)
		var dir = rng.randi_range(4)
		var dx = [0, 1, 0, -1][dir]
		var dy = [-1, 0, 1, 0][dir]
		
		for l in range(length):
			var nx = x + dx * l
			var ny = y + dy * l
			if nx >= 0 and nx < size and ny >= 0 and ny < size:
				if map_data.tiles[ny][nx] == 0:
					map_data.tiles[ny][nx] = 1
				elif map_data.tiles[ny][nx] == 1:
					break  # Hit main road, connect and stop

func _generate_buildings(map_data: Dictionary, district: DistrictData, rng: RandomNumberGenerator) -> void:
	var size = map_data.grid_size
	var density = district.density
	
	for y in range(size):
		for x in range(size):
			if map_data.tiles[y][x] == 0 and rng.randi_range(100) < density * 100:
				# Check if adjacent to road
				var near_road = false
				for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]:
					var nx, ny = x + dx, y + dy
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						if map_data.tiles[ny][nx] == 1:
							near_road = true
							break
				if near_road:
					map_data.tiles[y][x] = 2  # Building
					map_data.buildings.append({"pos": Vector2i(x, y), "type": rng.randi_range(3)})

func _generate_features(map_data: Dictionary, district: DistrictData, rng: RandomNumberGenerator) -> void:
	var size = map_data.grid_size
	
	# Water bodies
	for i in range(district.water_bodies):
		var cx = rng.randi_range(2, size - 3)
		var cy = rng.randi_range(2, size - 3)
		var radius = rng.randi_range(2, 4)
		
		for y in range(max(0, cy - radius), min(size, cy + radius + 1)):
			for x in range(max(0, cx - radius), min(size, cx + radius + 1)):
				var dist = Vector2(x - cx, y - cy).length()
				if dist <= radius and map_data.tiles[y][x] == 0:
					map_data.tiles[y][x] = 3  # Water
		map_data.water_bodies.append({"center": Vector2i(cx, cy), "radius": radius})
	
	# Parks
	for i in range(district.park_areas):
		var cx = rng.randi_range(2, size - 3)
		var cy = rng.randi_range(2, size - 3)
		var radius = rng.randi_range(1, 3)
		
		for y in range(max(0, cy - radius), min(size, cy + radius + 1)):
			for x in range(max(0, cx - radius), min(size, cx + radius + 1)):
				var dist = Vector2(x - cx, y - cy).length()
				if dist <= radius and map_data.tiles[y][x] == 0:
					map_data.tiles[y][x] = 4  # Park
		map_data.parks.append({"center": Vector2i(cx, cy), "radius": radius})

func _calculate_traffic(map_data: Dictionary, district: DistrictData, rng: RandomNumberGenerator) -> void:
	var size = map_data.grid_size
	var base_traffic = district.traffic_base
	
	# Traffic is highest at road intersections
	for y in range(size):
		for x in range(size):
			if map_data.tiles[y][x] == 1:  # Road
				var connections = 0
				for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]:
					var nx, ny = x + dx, y + dy
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						if map_data.tiles[ny][nx] == 1:
							connections += 1
				
				if connections >= 3:  # Intersection
					var traffic = base_traffic * (1.0 + connections * 0.2)
					# Boost near buildings
					for dx, dy in [(0,1),(0,-1),(1,0),(-1,0),(1,1),(-1,1),(1,-1),(-1,-1)]:
						var nx, ny = x + dx, y + dy
						if nx >= 0 and nx < size and ny >= 0 and ny < size:
							if map_data.tiles[ny][nx] == 2:
								traffic *= 1.1
					map_data.traffic_nodes.append({"pos": Vector2i(x, y), "value": traffic})

func _place_player_station(map_data: Dictionary, district: DistrictData, rng: RandomNumberGenerator) -> void:
	# Find best traffic intersection not near water
	var best_pos = Vector2i(1, 1)
	var best_traffic = 0
	
	for node in map_data.traffic_nodes:
		var pos = node.pos
		var traffic = node.value
		
		# Penalize water proximity
		var water_penalty = 1.0
		for water in map_data.water_bodies:
			var dist = (pos - water.center).length()
			if dist < 4:
				water_penalty *= 0.5
		
		var effective = traffic * water_penalty
		if effective > best_traffic:
			best_traffic = effective
			best_pos = pos
	
	map_data.player_start = best_pos
	map_data.tiles[best_pos.y][best_pos.x] = 5  # Player station

func _place_opponent_stations(map_data: Dictionary, district: DistrictData, level_data: LevelData, rng: RandomNumberGenerator) -> void:
	var opp_count = level_data.forced_opponent_count if level_data.forced_opponent_count > 0 else 
	                rng.randi_range(district.min_opponents, district.max_opponents)
	
	var available_types = level_data.forced_opponent_types
	if available_types.is_empty():
		available_types = district.allowed_opponent_types
	
	# Sort traffic nodes by value descending
	var sorted_nodes = map_data.traffic_nodes.duplicate()
	sorted_nodes.sort_custom(self, "_compare_traffic_desc")
	
	# Player takes best, opponents take next best
	var player_node = map_data.traffic_nodes.find({"pos": map_data.player_start, "value": 0})
	# Simpler: just skip player position
	
	var placed = 0
	for node in sorted_nodes:
		if placed >= opp_count:
			break
		if node.pos == map_data.player_start:
			continue
		# Check distance from player (at least 3 tiles)
		if (node.pos - map_data.player_start).length() < 3:
			continue
		# Check not on water/park
		if map_data.tiles[node.pos.y][node.pos.x] in [3, 4, 5]:
			continue
		
		var opp_type = available_types[rng.randi_range(available_types.size())]
		var station_count = rng.randi_range(district.opponent_station_count_range.x, district.opponent_station_count_range.y)
		
		for s in range(station_count):
			# Place additional stations near first one for clustering types
			var station_pos = node.pos
			if s > 0:
				# Find adjacent road
				for dx, dy in [(0,1),(0,-1),(1,0),(-1,0),(1,1),(-1,1),(1,-1),(-1,-1)]:
					var nx, ny = node.pos.x + dx, node.pos.y + dy
					if nx >= 0 and nx < map_data.grid_size and ny >= 0 and ny < map_data.grid_size:
						if map_data.tiles[ny][nx] == 1:
							station_pos = Vector2i(nx, ny)
							break
			
			if map_data.tiles[station_pos.y][station_pos.x] == 1:
				map_data.tiles[station_pos.y][station_pos.x] = 6
				map_data.opponent_stations.append({
					"pos": station_pos,
					"archetype": opp_type,
					"owner_index": placed
				})
		
		placed += 1

func _compare_traffic_desc(a: Dictionary, b: Dictionary) -> int:
	return -sign(a.value - b.value)

func _calculate_land_values(map_data: Dictionary, district: DistrictData) -> void:
	var size = map_data.grid_size
	map_data.land_values = []
	
	for y in range(size):
		row = []
		for x in range(size):
			var base_value = 1000 * district.land_price_multiplier
			var tile_type = map_data.tiles[y][x]
			
			if tile_type == 1:  # Road frontage
				base_value *= 1.5
			elif tile_type == 2:  # Building (demolish cost)
				base_value *= 2.0
			elif tile_type == 3:  # Waterfront premium
				base_value *= 1.8
			elif tile_type == 4:  # Park view
				base_value *= 1.3
			elif tile_type == 0:  # Empty lot
				base_value *= 0.8
			
			# Traffic bonus
			for node in map_data.traffic_nodes:
				var dist = Vector2(x - node.pos.x, y - node.pos.y).length()
				if dist < 3:
					base_value *= 1.0 + (3 - dist) * 0.15
			
			row.append(int(base_value))
		map_data.land_values.append(row)

func get_cached_map(level_id: StringName) -> Dictionary:
	return generated_maps.get(level_id, {})

func clear_cache() -> void:
	generated_maps.clear()