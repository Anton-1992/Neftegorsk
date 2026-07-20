## generate_resources.gd
## Tool script to generate .tres resource files from code definitions
## Run from Godot editor: Script → Run

@tool
extends EditorScript

func _run() -> void:
	var dir = DirAccess.open("res://resources/generated")
	if not dir:
		DirAccess.make_dir_recursive_absolute("res://resources/generated")
		dir = DirAccess.open("res://resources/generated")
	
	# Generate DistrictData resources
	_generate_districts(dir)
	
	# Generate OpponentArchetype resources
	_generate_archetypes(dir)
	
	# Generate UpgradeData resources
	_generate_upgrades(dir)
	
	# Generate LevelData resources
	_generate_levels(dir)
	
	print("All resources generated successfully!")

func _generate_districts(dir: DirAccess) -> void:
	var districts_data = {
		"business_center": {
			"district_id": "business_center",
			"display_name": "Деловой центр",
			"description": "Небоскрёбы, бизнес-центры, плотный трафик. Высокая конкуренция, дорогие аренды.",
			"background_color": Color(0.25, 0.25, 0.35),
			"road_color": Color(0.15, 0.15, 0.2),
			"building_colors": [Color(0.3, 0.3, 0.4), Color(0.25, 0.3, 0.35), Color(0.35, 0.3, 0.35)],
			"density": 0.9,
			"road_complexity": 0.8,
			"grid_size": 8,
			"traffic_base": 90,
			"fuel_demand_multiplier": 1.4,
			"land_price_multiplier": 2.0,
			"opponent_aggression": 1.3,
			"starting_capital_bonus": 20000,
			"upgrade_cost_multiplier": 1.2,
			"allowed_opponent_types": ["miser", "opportunist", "shark"],
			"min_opponents": 1,
			"max_opponents": 3,
			"opponent_station_count_range": Vector2i(1, 2),
			"required_stars_total": 0,
			"levels_per_district": 4
		},
		"historic": {
			"district_id": "historic",
			"display_name": "Исторический центр",
			"description": "Узкие улочки, достопримечательности, туристы. Сложная логистика, лояльные клиенты.",
			"background_color": Color(0.35, 0.3, 0.25),
			"road_color": Color(0.25, 0.2, 0.15),
			"building_colors": [Color(0.5, 0.4, 0.3), Color(0.45, 0.35, 0.25), Color(0.55, 0.45, 0.35)],
			"density": 0.7,
			"road_complexity": 0.9,
			"grid_size": 7,
			"park_areas": 2,
			"traffic_base": 60,
			"fuel_demand_multiplier": 1.1,
			"land_price_multiplier": 1.5,
			"opponent_aggression": 0.9,
			"starting_capital_bonus": 5000,
			"upgrade_cost_multiplier": 1.0,
			"allowed_opponent_types": ["miser", "local", "opportunist"],
			"min_opponents": 1,
			"max_opponents": 2,
			"opponent_station_count_range": Vector2i(1, 2),
			"required_stars_total": 6,
			"required_previous_district": "business_center",
			"levels_per_district": 4
		},
		"residential": {
			"district_id": "residential",
			"display_name": "Спальный район",
			"description": "Жилые комплексы, школы, магазины. Ровный спрос, предсказуемые пути.",
			"background_color": Color(0.3, 0.35, 0.3),
			"road_color": Color(0.2, 0.25, 0.2),
			"building_colors": [Color(0.4, 0.5, 0.4), Color(0.35, 0.45, 0.35), Color(0.45, 0.5, 0.4)],
			"density": 0.6,
			"road_complexity": 0.4,
			"grid_size": 9,
			"park_areas": 3,
			"traffic_base": 50,
			"fuel_demand_multiplier": 1.0,
			"land_price_multiplier": 0.8,
			"opponent_aggression": 0.7,
			"upgrade_cost_multiplier": 0.9,
			"allowed_opponent_types": ["miser", "local"],
			"min_opponents": 1,
			"max_opponents": 2,
			"opponent_station_count_range": Vector2i(1, 1),
			"required_stars_total": 10,
			"required_previous_district": "historic",
			"levels_per_district": 4
		},
		"industrial": {
			"district_id": "industrial",
			"display_name": "Промзона",
			"description": "Заводы, склады, грузовики. Объёмный спрос, низкие маржи, суровые конкуренты.",
			"background_color": Color(0.25, 0.25, 0.3),
			"road_color": Color(0.18, 0.18, 0.22),
			"building_colors": [Color(0.35, 0.35, 0.4), Color(0.3, 0.3, 0.35), Color(0.4, 0.35, 0.35)],
			"density": 0.5,
			"road_complexity": 0.5,
			"grid_size": 10,
			"water_bodies": 1,
			"traffic_base": 70,
			"fuel_demand_multiplier": 1.6,
			"land_price_multiplier": 0.6,
			"opponent_aggression": 1.5,
			"starting_capital_bonus": 10000,
			"upgrade_cost_multiplier": 1.1,
			"allowed_opponent_types": ["shark", "tycoon", "opportunist"],
			"min_opponents": 2,
			"max_opponents": 4,
			"opponent_station_count_range": Vector2i(1, 3),
			"required_stars_total": 16,
			"required_previous_district": "residential",
			"levels_per_district": 4
		},
		"waterfront": {
			"district_id": "waterfront",
			"display_name": "Прибрежный район",
			"description": "Набережные, яхт-клубы, рестораны. Премиум-аудитория, сезонность, эко-тренды.",
			"background_color": Color(0.2, 0.35, 0.45),
			"road_color": Color(0.15, 0.25, 0.35),
			"building_colors": [Color(0.3, 0.5, 0.6), Color(0.25, 0.45, 0.55), Color(0.35, 0.55, 0.65)],
			"density": 0.4,
			"road_complexity": 0.6,
			"grid_size": 8,
			"water_bodies": 3,
			"park_areas": 2,
			"traffic_base": 55,
			"fuel_demand_multiplier": 1.2,
			"land_price_multiplier": 1.8,
			"opponent_aggression": 0.8,
			"starting_capital_bonus": 15000,
			"upgrade_cost_multiplier": 1.3,
			"allowed_opponent_types": ["local", "green", "opportunist"],
			"min_opponents": 1,
			"max_opponents": 3,
			"opponent_station_count_range": Vector2i(1, 2),
			"required_stars_total": 24,
			"required_previous_district": "industrial",
			"levels_per_district": 3
		},
		"suburban": {
			"district_id": "suburban",
			"display_name": "Пригород",
			"description": "Дачи, коттеджи, шоссе. Машина у каждой семьи, долгие поездки, верные клиенты.",
			"background_color": Color(0.35, 0.4, 0.3),
			"road_color": Color(0.25, 0.3, 0.2),
			"building_colors": [Color(0.5, 0.55, 0.45), Color(0.45, 0.5, 0.4), Color(0.55, 0.6, 0.5)],
			"density": 0.3,
			"road_complexity": 0.3,
			"grid_size": 10,
			"park_areas": 4,
			"water_bodies": 2,
			"traffic_base": 40,
			"fuel_demand_multiplier": 0.9,
			"land_price_multiplier": 0.5,
			"opponent_aggression": 0.6,
			"starting_capital_bonus": -5000,
			"upgrade_cost_multiplier": 0.8,
			"allowed_opponent_types": ["local", "miser"],
			"min_opponents": 1,
			"max_opponents": 2,
			"opponent_station_count_range": Vector2i(1, 1),
			"required_stars_total": 30,
			"required_previous_district": "waterfront",
			"levels_per_district": 3
		}
	}
	
	for id, data in districts_data:
		var resource = ResourceLoader.load("res://scripts/resources/district_data.gd").new()
		for key, value in data:
			resource.set(key, value)
		
		var path = "res://resources/generated/district_%s.tres" % id
		ResourceSaver.save(resource, path)
		print("Generated: %s" % path)

func _generate_archetypes(dir: DirAccess) -> void:
	var archetypes = OpponentArchetype.create_archetypes()
	
	for id, arch in archetypes:
		var path = "res://resources/generated/archetype_%s.tres" % id
		ResourceSaver.save(arch, path)
		print("Generated: %s" % path)

func _generate_upgrades(dir: DirAccess) -> void:
	var upgrades = UpgradeData.create_upgrade_tree()
	
	for id, upg in upgrades:
		var path = "res://resources/generated/upgrade_%s.tres" % id
		ResourceSaver.save(upg, path)
		print("Generated: %s" % path)

func _generate_levels(dir: DirAccess) -> void:
	# Levels are generated dynamically in LevelManager, but we can pre-create them
	var districts = {
		"business_center": 4,
		"historic": 4,
		"residential": 4,
		"industrial": 4,
		"waterfront": 3,
		"suburban": 3
	}
	
	for district_id, count in districts:
		for i in range(1, count + 1):
			var level_id = LevelData.create_level_id(district_id, i)
			var level = LevelData.new()
			level.level_id = level_id
			level.district_id = district_id
			level.level_number = i
			level.display_name = "%s %d" % [district_id.capitalize(), i]
			
			var path = "res://resources/generated/level_%s.tres" % level_id
			ResourceSaver.save(level, path)
			print("Generated: %s" % path)