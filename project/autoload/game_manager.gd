## GameManager.gd
## Central game state controller, scene transitions, global signals

extends Node

class_name GameManager

signal game_state_changed(state: String)
signal level_started(level_data: Resource)
signal level_completed(level_data: Resource, stars_earned: int, stats: Dictionary)
signal level_failed(level_data: Resource, reason: String)
signal district_unlocked(district_id: StringName)
signal stars_changed(total_stars: int)
signal currency_changed(cash: int)
signal upgrade_purchased(upgrade_id: StringName)

enum GameState {
	MAIN_MENU,
	DISTRICT_MAP,
	LEVEL_PLAYING,
	LEVEL_PAUSED,
	LEVEL_RESULT,
	UPGRADE_TREE,
	SETTINGS
}

@export var initial_cash: int = 50000
@export var initial_stars: int = 0

var current_state: GameState = GameState.MAIN_MENU
var current_district_id: StringName = ""
var current_level_data: Resource = null
var total_stars: int = 0
var cash: int = 0
var player_level: int = 1
var experience: int = 0
var owned_upgrades: Array[StringName] = []
var completed_levels: Dictionary = {}  # level_id -> {stars, best_time, best_cash}
var unlocked_districts: Array[StringName] = []
var game_stats: Dictionary = {
	"total_playtime": 0,
	"stations_bought": 0,
	"stations_built": 0,
	"opponents_defeated": 0,
	"total_revenue": 0,
	"price_wars_won": 0
}

# References to other managers
var level_manager: LevelManager
var upgrade_manager: UpgradeManager
var economy_manager: EconomyManager
var save_manager: SaveManager
var audio_manager: AudioManager

func _ready() -> void:
	# Get references to other autoloads
	level_manager = LevelManager
	upgrade_manager = UpgradeManager
	economy_manager = EconomyManager
	save_manager = SaveManager
	audio_manager = AudioManager
	
	# Load saved game
	save_manager.load_game()
	
	# Initialize currency
	cash = initial_cash
	total_stars = initial_stars
	
	# Unlock first district by default
	if unlocked_districts.is_empty():
		unlocked_districts.append("business_center")
	
	_game_state_changed(GameState.MAIN_MENU)

func _game_state_changed(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

func go_to_main_menu() -> void:
	_game_state_changed(GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func go_to_district_map(district_id: StringName = "") -> void:
	if district_id != "":
		current_district_id = district_id
	_game_state_changed(GameState.DISTRICT_MAP)
	get_tree().change_scene_to_file("res://scenes/district_map/district_map.tscn")

func start_level(level_data: Resource) -> void:
	current_level_data = level_data
	_game_state_changed(GameState.LEVEL_PLAYING)
	get_tree().change_scene_to_file("res://scenes/level/level.tscn")
	level_started.emit(level_data)

func pause_level() -> void:
	if current_state == GameState.LEVEL_PLAYING:
		_game_state_changed(GameState.LEVEL_PAUSED)
		get_tree().paused = true

func resume_level() -> void:
	if current_state == GameState.LEVEL_PAUSED:
		_game_state_changed(GameState.LEVEL_PLAYING)
		get_tree().paused = false

func complete_level(stars_earned: int, stats: Dictionary) -> void:
	if not current_level_data:
		return
	
	var level_id = current_level_data.level_id
	var prev_best = completed_levels.get(level_id, {"stars": 0})
	
	# Update best stars
	var new_stars = max(prev_best.stars, stars_earned)
	var stars_gained = new_stars - prev_best.stars
	
	completed_levels[level_id] = {
		"stars": new_stars,
		"best_time": min(prev_best.get("best_time", INF), stats.get("completion_time", INF)),
		"best_cash": max(prev_best.get("best_cash", 0), stats.get("final_cash", 0)),
		"completions": prev_best.get("completions", 0) + 1
	}
	
	total_stars += stars_gained
	stars_changed.emit(total_stars)
	
	# Update game stats
	game_stats.stations_bought += stats.get("stations_bought", 0)
	game_stats.opponents_defeated += stats.get("opponents_defeated", 0)
	game_stats.total_revenue += stats.get("revenue", 0)
	game_stats.price_wars_won += stats.get("price_wars_won", 0)
	
	# Check district completion
	_check_district_completion(current_level_data.district_id)
	
	# Check next level unlock
	var next_level = level_manager.get_next_level(current_level_data.district_id, current_level_data.level_number)
	if next_level and current_level_data.unlock_next_level:
		level_manager.unlock_level(next_level.level_id)
	
	_game_state_changed(GameState.LEVEL_RESULT)
	level_completed.emit(current_level_data, stars_earned, stats)
	
	# Auto-save
	save_manager.save_game()

func fail_level(reason: String) -> void:
	if not current_level_data:
		return
	_game_state_changed(GameState.LEVEL_RESULT)
	level_failed.emit(current_level_data, reason)
	save_manager.save_game()

func add_cash(amount: int) -> void:
	cash += amount
	currency_changed.emit(cash)

def spend_cash(amount: int) -> bool:
	if cash >= amount:
		cash -= amount
		currency_changed.emit(cash)
		return true
	return false

def add_stars(amount: int) -> void:
	total_stars += amount
	stars_changed.emit(total_stars)
	save_manager.save_game()

def purchase_upgrade(upgrade_id: StringName) -> bool:
	var upgrade = upgrade_manager.get_upgrade(upgrade_id)
	if not upgrade:
		return false
	
	if not upgrade.can_purchase(owned_upgrades, player_level, total_stars, cash):
		return false
	
	if not spend_cash(upgrade.cash_cost):
		return false
	
	total_stars -= upgrade.star_cost
	owned_upgrades.append(upgrade_id)
	
	# Apply effects immediately
	upgrade.apply_effects(self)
	
	upgrade_purchased.emit(upgrade_id)
	stars_changed.emit(total_stars)
	currency_changed.emit(cash)
	save_manager.save_game()
	return true

func has_upgrade(upgrade_id: StringName) -> bool:
	return upgrade_id in owned_upgrades

func get_upgrade_effect(effect_key: String, default: Variant = 0) -> Variant:
	var total = default
	var is_multiplier = default is float or (default is int and default == 1)
	
	for uid in owned_upgrades:
		var upgrade = upgrade_manager.get_upgrade(uid)
		if upgrade and upgrade.effects.has(effect_key):
			var val = upgrade.effects[effect_key]
			if is_multiplier:
				total *= val
			else:
				total += val
	return total

func is_district_unlocked(district_id: StringName) -> bool:
	return district_id in unlocked_districts

func unlock_district(district_id: StringName) -> void:
	if district_id not in unlocked_districts:
		unlocked_districts.append(district_id)
		district_unlocked.emit(district_id)
		save_manager.save_game()

func _check_district_completion(district_id: StringName) -> void:
	var district = level_manager.get_district(district_id)
	if not district:
		return
	
	var all_completed = true
	for i in range(1, district.levels_per_district + 1):
		var lid = LevelData.create_level_id(district_id, i)
		if not completed_levels.has(lid) or completed_levels[lid].stars == 0:
			all_completed = false
			break
	
	if all_completed:
		# Unlock next district
		var next_district = level_manager.get_next_district(district_id)
		if next_district:
			unlock_district(next_district.district_id)

func get_level_progress(district_id: StringName) -> Dictionary:
	var district = level_manager.get_district(district_id)
	if not district:
		return {"completed": 0, "total": 0, "stars": 0, "max_stars": 0}
	
	var completed = 0
	var total_stars_earned = 0
	var max_possible = 0
	
	for i in range(1, district.levels_per_district + 1):
		var lid = LevelData.create_level_id(district_id, i)
		var data = completed_levels.get(lid, {"stars": 0})
		if data.stars > 0:
			completed += 1
		total_stars_earned += data.stars
		max_possible += district.get_level_max_stars(i)  # Need to implement
	
	return {
		"completed": completed,
		"total": district.levels_per_district,
		"stars": total_stars_earned,
		"max_stars": max_possible
	}

func get_total_stars_earned() -> int:
	var total = 0
	for data in completed_levels.values():
		total += data.stars
	return total

func reset_game() -> void:
	cash = initial_cash
	total_stars = initial_stars
	player_level = 1
	experience = 0
	owned_upgrades.clear()
	completed_levels.clear()
	unlocked_districts.clear()
	unlocked_districts.append("business_center")
	game_stats = {
		"total_playtime": 0,
		"stations_bought": 0,
		"stations_built": 0,
		"opponents_defeated": 0,
		"total_revenue": 0,
		"price_wars_won": 0
	}
	save_manager.save_game()
	go_to_main_menu()

# Persistence interface for SaveManager
func get_save_data() -> Dictionary:
	return {
		"cash": cash,
		"total_stars": total_stars,
		"player_level": player_level,
		"experience": experience,
		"owned_upgrades": owned_upgrades,
		"completed_levels": completed_levels,
		"unlocked_districts": unlocked_districts,
		"game_stats": game_stats,
		"current_district": current_district_id
	}

func load_save_data(data: Dictionary) -> void:
	cash = data.get("cash", initial_cash)
	total_stars = data.get("total_stars", initial_stars)
	player_level = data.get("player_level", 1)
	experience = data.get("experience", 0)
	owned_upgrades = data.get("owned_upgrades", [])
	completed_levels = data.get("completed_levels", {})
	unlocked_districts = data.get("unlocked_districts", ["business_center"])
	game_stats = data.get("game_stats", game_stats)
	current_district_id = data.get("current_district", "")
	
	currency_changed.emit(cash)
	stars_changed.emit(total_stars)