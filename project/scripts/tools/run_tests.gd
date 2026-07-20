## run_tests.gd
## Simple test runner for CI - validates core systems load without errors

@tool
extends EditorScript

func _run() -> void:
	print("=== Neftegorsk CI Tests ===")
	
	var passed = 0
	var failed = 0
	
	func assert(condition: bool, message: String) -> void:
		nonlocal passed, failed
		if condition:
			print("✓ PASS: " + message)
			passed += 1
		else:
			printerr("✗ FAIL: " + message)
			failed += 1
	
	# Test 1: Resource classes load
	var district_data = load("res://scripts/resources/district_data.gd").new()
	assert(district_data != null, "DistrictData loads")
	
	var archetype = load("res://scripts/resources/opponent_archetype.gd").new()
	assert(archetype != null, "OpponentArchetype loads")
	
	var level_data = load("res://scripts/resources/level_data.gd").new()
	assert(level_data != null, "LevelData loads")
	
	var upgrade_data = load("res://scripts/resources/upgrade_data.gd").new()
	assert(upgrade_data != null, "UpgradeData loads")
	
	# Test 2: Autoload scripts load
	var gm = load("res://autoload/game_manager.gd").new()
	assert(gm != null, "GameManager loads")
	
	var lm = load("res://autoload/level_manager.gd").new()
	assert(lm != null, "LevelManager loads")
	
	var um = load("res://autoload/upgrade_manager.gd").new()
	assert(um != null, "UpgradeManager loads")
	
	var em = load("res://autoload/economy_manager.gd").new()
	assert(em != null, "EconomyManager loads")
	
	var sm = load("res://autoload/save_manager.gd").new()
	assert(sm != null, "SaveManager loads")
	
	var am = load("res://autoload/audio_manager.gd").new()
	assert(am != null, "AudioManager loads")
	
	# Test 3: Scenes load
	var main_menu = load("res://scenes/main_menu/main_menu.tscn")
	assert(main_menu != null, "MainMenu scene loads")
	
	var district_map = load("res://scenes/district_map/district_map.tscn")
	assert(district_map != null, "DistrictMap scene loads")
	
	var level_scene = load("res://scenes/level/level.tscn")
	assert(level_scene != null, "Level scene loads")
	
	var upgrade_tree = load("res://scenes/upgrade_tree/upgrade_tree.tscn")
	assert(upgrade_tree != null, "UpgradeTree scene loads")
	
	var station_node = load("res://scenes/level/station_node.tscn")
	assert(station_node != null, "StationNode scene loads")
	
	# Test 4: TileMapSetup
	var tilemap_setup = load("res://scripts/resources/tilemap_setup.gd").new()
	assert(tilemap_setup != null, "TileMapSetup loads")
	var tile_set = TileMapSetup.create_composite_tile_set()
	assert(tile_set != null, "Composite TileSet created")
	assert(tile_set.get_source_count() == 4, "TileSet has 4 sources")
	
	# Test 5: LevelManager district initialization
	lm._initialize_districts()
	assert(lm.districts.size() >= 6, "LevelManager has 6+ districts")
	assert(lm.districts.has("business_center"), "Business center district exists")
	assert(lm.districts.has("historic"), "Historic district exists")
	assert(lm.districts.has("residential"), "Residential district exists")
	assert(lm.districts.has("industrial"), "Industrial district exists")
	assert(lm.districts.has("waterfront"), "Waterfront district exists")
	assert(lm.districts.has("suburban"), "Suburban district exists")
	
	# Test 6: UpgradeManager tree
	um._initialize_upgrades()
	assert(um.upgrades.size() >= 20, "UpgradeManager has 20+ upgrades")
	var layout = um.get_upgrade_tree_layout()
	assert(layout.size() >= 6, "Upgrade tree has 6 categories")
	
	# Test 7: Opponent archetypes
	var archetypes = OpponentArchetype.create_archetypes()
	assert(archetypes.size() == 6, "6 opponent archetypes created")
	assert(archetypes.has("shark"), "Shark archetype exists")
	assert(archetypes.has("miser"), "Miser archetype exists")
	assert(archetypes.has("opportunist"), "Opportunist archetype exists")
	assert(archetypes.has("tycoon"), "Tycoon archetype exists")
	assert(archetypes.has("local"), "Local archetype exists")
	assert(archetypes.has("green"), "Green archetype exists")
	
	# Test 8: Level generation
	var test_level = LevelData.new()
	test_level.level_id = "test_01"
	test_level.district_id = "business_center"
	test_level.level_number = 1
	test_level.display_name = "Test Level"
	
	var map_data = lm.generate_level_map(test_level)
	assert(map_data != null, "Level map generated")
	assert(map_data.has("grid_size"), "Map has grid_size")
	assert(map_data.has("tiles"), "Map has tiles array")
	assert(map_data.has("roads"), "Map has roads")
	assert(map_data.has("buildings"), "Map has buildings")
	assert(map_data.has("player_start"), "Map has player_start")
	assert(map_data.has("opponent_stations"), "Map has opponent_stations")
	assert(map_data.has("traffic_nodes"), "Map has traffic_nodes")
	
	# Test 9: Economy manager
	em.initialize_level(test_level, map_data)
	assert(em.current_market_price > 0, "Market price initialized")
	assert(em.wholesale_price > 0, "Wholesale price initialized")
	assert(em.player_stations.size() == 1, "Player has 1 station")
	
	# Test 10: Save/Load manager
	var save_data = {
		"cash": 50000,
		"total_stars": 10,
		"player_level": 1,
		"experience": 0,
		"owned_upgrades": [],
		"completed_levels": {},
		"unlocked_districts": ["business_center"],
		"game_stats": {},
		"current_district": ""
	}
	sm._variant_to_saveable(save_data)
	var loaded = sm._variant_from_saveable(save_data)
	assert(loaded["cash"] == 50000, "SaveManager serialization works")
	
	print("\n=== Results: %d passed, %d failed ===" % [passed, failed])
	
	if failed > 0:
		printerr("TESTS FAILED")
		OS.exit(1)
	else:
		print("ALL TESTS PASSED")
		OS.exit(0)