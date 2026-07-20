## DistrictData.gd
## Resource defining a city district type with generation parameters
## Used for procedural level map generation

class_name DistrictData
extends Resource

@export_group("Identity")
@export var district_id: StringName = ""
@export var display_name: String = "Район"
@export var description: String = ""
@export var icon_path: String = ""  # UI icon for map menu

@export_group("Visual Style")
@export var background_color: Color = Color(0.3, 0.3, 0.35)
@export var road_color: Color = Color(0.2, 0.2, 0.25)
@export var building_colors: Array[Color] = [
	Color(0.4, 0.35, 0.3),
	Color(0.35, 0.4, 0.35),
	Color(0.3, 0.35, 0.4)
]
@export var landmark_texture: String = ""  # Optional unique landmark

@export_group("Generation Parameters")
@export_range(0.0, 1.0) var density: float = 0.5          # Building density
@export_range(0.0, 1.0) var road_complexity: float = 0.5  # Road network complexity
@export_range(1, 10) var grid_size: int = 6               # Base grid for level (6x6 to 10x10)
@export_range(0, 5) var water_bodies: int = 0             # Number of water features
@export_range(0, 3) var park_areas: int = 0               # Number of parks/green zones
@export_range(0, 100) var traffic_base: int = 50          # Base traffic flow (affects demand)

@export_group("Economy Modifiers")
@export var fuel_demand_multiplier: float = 1.0      # How much fuel is needed
@export var land_price_multiplier: float = 1.0       # Cost to buy stations
@export var opponent_aggression: float = 1.0         # How aggressive AI is
@export var starting_capital_bonus: int = 0          # Extra starting money
@export var upgrade_cost_multiplier: float = 1.0     # Upgrade costs in this district

@export_group("Opponent Pool")
@export var allowed_opponent_types: Array[StringName] = []  # Which AI archetypes can appear
@export var min_opponents: int = 1
@export var max_opponents: int = 3
@export var opponent_station_count_range: Vector2i = Vector2i(1, 2)  # Stations per opponent

@export_group("Unlock Requirements")
@export var required_stars_total: int = 0       # Total stars needed to unlock
@export var required_previous_district: StringName = ""  # Must complete this district first

@export_group("Level Count")
@export var levels_per_district: int = 4  # How many levels in this district

func _validate_property(property_name: String) -> bool:
	"""Validate district data integrity"""
	if district_id == "":
		push_error("DistrictData: district_id cannot be empty")
		return false
	if grid_size < 4 or grid_size > 12:
		push_error("DistrictData: grid_size should be 4-12")
		return false
	if min_opponents > max_opponents:
		push_error("DistrictData: min_opponents > max_opponents")
		return false
	return true

func get_level_count() -> int:
	return levels_per_district

func get_difficulty_rating() -> float:
	"""Composite difficulty for progression balancing"""
	return (density * 0.3 + road_complexity * 0.2 +
	        opponent_aggression * 0.3 +
	        (max_opponents / 5.0) * 0.2)