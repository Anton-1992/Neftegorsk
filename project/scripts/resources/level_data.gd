## LevelData.gd
## Defines a specific level within a district

class_name LevelData
extends Resource

@export_group("Identity")
@export var level_id: StringName = ""
@export var district_id: StringName = ""
@export var level_number: int = 1           # 1-based within district
@export var display_name: String = "Уровень"

@export_group("Map Generation Overrides")
@export var seed: int = 0                   # 0 = random per play
@export var forced_grid_size: int = 0       # 0 = use district default
@export var forced_opponent_count: int = -1 # -1 = use district range
@export var forced_opponent_types: Array[StringName] = []  # Specific archetypes

@export_group("Objectives")
@export var objective_type: int = 0         # 0 = buy all, 1 = reach market share, 2 = survive time
@export var target_market_share: float = 1.0  # For type 1
@export var time_limit_seconds: float = 0   # 0 = no limit, for type 2

@export_group("Economy Setup")
@export var player_starting_cash: int = 50000
@export var opponent_starting_cash: int = 30000
@export var market_base_price: float = 50.0  # Base fuel price per liter
@export var daily_costs_multiplier: float = 1.0

@export_group("Win/Lose Conditions")
@export var win_condition: int = 0          # 0 = buy all opponent stations
@export var lose_condition: int = 0         # 0 = bankruptcy, 1 = time out, 2 = market share lost
@export var bankruptcy_threshold: int = -10000

@export_group("Rewards")
@export var base_stars: int = 3             # Stars for completion
@export var bonus_star_conditions: Array = []  # Extra stars: {"type": "time", "threshold": 300}, {"type": "cash", "threshold": 100000}
@export var unlock_next_level: bool = true

@export_group("Narrative")
@export var intro_dialogue: String = ""
@export var outro_dialogue_victory: String = ""
@export var outro_dialogue_defeat: String = ""

func get_total_possible_stars() -> int:
	var total = base_stars
	for condition in bonus_star_conditions:
		total += 1
	return total

func is_bonus_condition_met(condition: Dictionary, game_stats: Dictionary) -> bool:
	var ctype = condition.get("type", "")
	var threshold = condition.get("threshold", 0)
	
	match ctype:
		"time": return game_stats.get("completion_time", 9999) <= threshold
		"cash": return game_stats.get("final_cash", 0) >= threshold
		"stations_owned": return game_stats.get("stations_owned", 0) >= threshold
		"no_bankruptcy": return game_stats.get("went_bankrupt", false) == false
		"price_war_won": return game_stats.get("price_wars_won", 0) >= threshold
		_: return false

static func create_level_id(district_id: StringName, level_num: int) -> StringName:
	return StringName("%s_%02d".format([district_id, level_num]))