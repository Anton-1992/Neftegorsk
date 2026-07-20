## TileMapSetup.gd
## Helper to create TileMap tile sets programmatically from SVG atlases

extends Resource
class_name TileMapSetup

@export_group("Atlas Paths")
@export_file("*.svg") var ground_atlas: String = "res://assets/maps/tileset_ground.svg"
@export_file("*.svg") var roads_atlas: String = "res://assets/maps/tileset_roads.svg"
@export_file("*.svg") var water_atlas: String = "res://assets/maps/tileset_water.svg"
@export_file("*.svg") var park_atlas: String = "res://assets/maps/tileset_park.svg"
@export_file("*.svg") var buildings_atlas: String = "res://assets/maps/tileset_buildings.svg"

@export_group("Tile Settings")
@export var tile_size: Vector2i = Vector2i(64, 64)
@export var atlas_grid: Vector2i = Vector2i(8, 8)  # 8x8 tiles per atlas

static func create_tile_set(atlas_path: String, tile_size: Vector2i = Vector2i(64, 64), grid: Vector2i = Vector2i(8, 8)) -> TileSet:
	"""Create a TileSet from an SVG atlas"""
	var tile_set = TileSet.new()
	
	# Load texture from SVG (Godot 4 can load SVG as Texture2D)
	var texture = ResourceLoader.load(atlas_path)
	if not texture:
		push_error("Failed to load atlas: " + atlas_path)
		return tile_set
	
	# Create a single tile source for the whole atlas
	var source_id = tile_set.create_tile_source(0, TileSet.SOURCE_TYPE_ATLAS)
	tile_set.set_source_id(0, source_id)
	tile_set.atlas_source_set_texture(source_id, texture)
	tile_set.atlas_source_set_texture_region_size(source_id, tile_size)
	tile_set.atlas_source_set_margins(source_id, Vector2i(0, 0))
	tile_set.atlas_source_set_separation(source_id, Vector2i(0, 0))
	
	# Add tiles for each cell in the grid
	var tile_id = 0
	for y in range(grid.y):
		for x in range(grid.x):
			var coords = Vector2i(x, y)
			tile_set.atlas_source_create_tile(source_id, tile_id, coords)
			tile_id += 1
	
	return tile_set

static func create_composite_tile_set() -> TileSet:
	"""Create a combined TileSet with multiple sources for different layers"""
	var tile_set = TileSet.new()
	var tile_id = 0
	
	# Source 0: Ground (grass, dirt, sand, paths)
	var ground_source = tile_set.create_tile_source(0, TileSet.SOURCE_TYPE_ATLAS)
	tile_set.atlas_source_set_texture(ground_source, ResourceLoader.load("res://assets/maps/tileset_ground.svg"))
	tile_set.atlas_source_set_texture_region_size(ground_source, Vector2i(64, 64))
	for y in range(8):
		for x in range(8):
			tile_set.atlas_source_create_tile(ground_source, tile_id, Vector2i(x, y))
			tile_id += 1
	
	# Source 1: Roads
	var road_source = tile_set.create_tile_source(1, TileSet.SOURCE_TYPE_ATLAS)
	tile_set.atlas_source_set_texture(road_source, ResourceLoader.load("res://assets/maps/tileset_roads.svg"))
	tile_set.atlas_source_set_texture_region_size(road_source, Vector2i(64, 64))
	for y in range(8):
		for x in range(8):
			tile_set.atlas_source_create_tile(road_source, tile_id, Vector2i(x, y))
			tile_id += 1
	
	# Source 2: Water
	var water_source = tile_set.create_tile_source(2, TileSet.SOURCE_TYPE_ATLAS)
	tile_set.atlas_source_set_texture(water_source, ResourceLoader.load("res://assets/maps/tileset_water.svg"))
	tile_set.atlas_source_set_texture_region_size(water_source, Vector2i(64, 64))
	for y in range(8):
		for x in range(8):
			tile_set.atlas_source_create_tile(water_source, tile_id, Vector2i(x, y))
			tile_id += 1
	
	# Source 3: Park/Green
	var park_source = tile_set.create_tile_source(3, TileSet.SOURCE_TYPE_ATLAS)
	tile_set.atlas_source_set_texture(park_source, ResourceLoader.load("res://assets/maps/tileset_park.svg"))
	tile_set.atlas_source_set_texture_region_size(park_source, Vector2i(64, 64))
	for y in range(8):
		for x in range(8):
			tile_set.atlas_source_create_tile(park_source, tile_id, Vector2i(x, y))
			tile_id += 1
	
	return tile_set

# Tile ID mappings for easy reference
const TILE_IDS = {
	# Ground layer (source 0, tiles 0-63)
	"GRASS": 0,
	"GRASS_PARK": 1,
	"GRASS_WILD": 2,
	"DIRT": 3,
	"SAND": 4,
	"PATH": 5,
	"PLAZA": 6,
	"PLAYGROUND": 7,
	"FOUNTAIN": 8,
	
	# Road layer (source 1, tiles 64-127)
	"ROAD_BASE": 64,
	"ROAD_LIGHT": 65,
	"HIGHWAY": 66,
	"DIRT_ROAD": 67,
	"COBBLESTONE": 68,
	"ROAD_H_DASHED": 72,
	"ROAD_H_SOLID": 73,
	"HIGHWAY_H": 74,
	"DIRT_ROAD_H": 75,
	"COBBLESTONE_H": 76,
	"ROAD_V_DASHED": 80,
	"ROAD_V_SOLID": 81,
	"HIGHWAY_V": 82,
	"DIRT_ROAD_V": 83,
	"COBBLESTONE_V": 84,
	"INTERSECTION_DASHED": 88,
	"INTERSECTION_SOLID": 89,
	"HIGHWAY_INTERSECTION": 90,
	"DIRT_INTERSECTION": 91,
	"COBBLESTONE_INTERSECTION": 92,
	"T_JUNCTION_DASHED": 96,
	"T_JUNCTION_SOLID": 97,
	"T_JUNCTION_HIGHWAY": 98,
	"T_JUNCTION_DIRT": 99,
	"CURVE_TR_DASHED": 104,
	"CURVE_TL_DASHED": 105,
	"CURVE_BR_DASHED": 106,
	"CURVE_BL_DASHED": 107,
	"CROSSWALK": 112,
	"PARKING": 113,
	"GRASS_PARK_ROAD": 114,
	"PARKING_LOT": 115,
	"EV_CHARGE": 116,
	
	# Water layer (source 2, tiles 128-191)
	"WATER_DEEP": 128,
	"WATER_SHALLOW": 129,
	"WATER_SHORE": 130,
	"RIVER": 131,
	"CANAL": 132,
	"PORT_WATER": 133,
	
	# Park layer (source 3, tiles 192-255)
	"PARK_GRASS": 192,
	"PARK_GRASS_PARK": 193,
	"PARK_GRASS_WILD": 194,
	"PARK_DIRT": 195,
	"PARK_SAND": 196,
	"PARK_PATH": 197,
	"PARK_PLAZA": 198,
	"PARK_PLAYGROUND": 199,
	"PARK_FOUNTAIN": 200,
}

# District-specific tile palettes
const DISTRICT_TILES = {
	"business_center": {
		"ground": ["PLAZA", "PARKING_LOT", "ROAD_BASE", "ROAD_H_SOLID", "ROAD_V_SOLID", "INTERSECTION_SOLID"],
		"water": ["CANAL", "PORT_WATER"],
		"park": ["PLAZA", "PARK_GRASS_PARK"],
	},
	"historic": {
		"ground": ["COBBLESTONE", "COBBLESTONE_H", "COBBLESTONE_V", "COBBLESTONE_INTERSECTION", "PATH", "PLAZA"],
		"water": ["CANAL", "WATER_SHORE"],
		"park": ["PARK_GRASS_PARK", "PARK_PLAZA", "PARK_FOUNTAIN"],
	},
	"residential": {
		"ground": ["GRASS", "GRASS_PARK", "PATH", "DIRT", "ROAD_BASE", "ROAD_H_DASHED", "ROAD_V_DASHED"],
		"water": ["WATER_SHALLOW", "WATER_SHORE"],
		"park": ["PARK_GRASS_PARK", "PARK_PLAYGROUND", "PARK_PATH"],
	},
	"industrial": {
		"ground": ["DIRT", "DIRT_ROAD", "DIRT_ROAD_H", "DIRT_ROAD_V", "DIRT_INTERSECTION", "PARKING_LOT", "ROAD_BASE"],
		"water": ["CANAL", "PORT_WATER", "RIVER"],
		"park": ["PARK_DIRT", "PARK_PATH"],
	},
	"waterfront": {
		"ground": ["SAND", "PLAZA", "ROAD_BASE", "ROAD_H_SOLID", "ROAD_V_SOLID", "CROSSWALK"],
		"water": ["WATER_SHALLOW", "WATER_SHORE", "WATER_DEEP", "RIVER", "PORT_WATER"],
		"park": ["PARK_SAND", "PARK_PLAZA", "PARK_FOUNTAIN", "PARK_PLAYGROUND"],
	},
	"suburban": {
		"ground": ["GRASS", "GRASS_WILD", "DIRT", "PATH", "ROAD_BASE", "ROAD_H_DASHED", "ROAD_V_DASHED", "DIRT_ROAD"],
		"water": ["WATER_SHALLOW", "WATER_SHORE", "RIVER"],
		"park": ["PARK_GRASS_WILD", "PARK_PLAYGROUND", "PARK_PATH", "PARK_FOUNTAIN"],
	},
}

func get_tile_id(name: String) -> int:
	return TILE_IDS.get(name, 0)

func get_district_tiles(district_id: StringName) -> Dictionary:
	return DISTRICT_TILES.get(district_id, DISTRICT_TILES["business_center"])