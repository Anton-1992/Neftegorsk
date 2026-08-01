## GameManager.gd — v25: safe autoload access, no class_name
extends Node

signal game_state_changed(state: String)
signal currency_changed(cash: int)
signal stars_changed(total_stars: int)

var current_state: int = 0
var current_district_id: StringName = ""
var total_stars: int = 0
var cash: int = 50000
var player_level: int = 1
var owned_upgrades: Array = []
var completed_levels: Dictionary = {}
var unlocked_districts: Array = []

func _ready() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.load_game()
	if unlocked_districts.is_empty():
		unlocked_districts.append(StringName("business_center"))
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		cash = gs.cash
		total_stars = gs.total_stars

func add_cash(amount: int) -> void:
	cash += amount
	currency_changed.emit(cash)

func spend_cash(amount: int) -> bool:
	if cash >= amount:
		cash -= amount
		currency_changed.emit(cash)
		return true
	return false

func is_district_unlocked(district_id: StringName) -> bool:
	return district_id in unlocked_districts

func get_save_data() -> Dictionary:
	return {
		"cash": cash,
		"total_stars": total_stars,
		"player_level": player_level,
		"owned_upgrades": owned_upgrades,
		"completed_levels": completed_levels,
		"unlocked_districts": unlocked_districts,
	}

func load_save_data(data: Dictionary) -> void:
	cash = data.get("cash", 50000)
	total_stars = data.get("total_stars", 0)
	player_level = data.get("player_level", 1)
	owned_upgrades = data.get("owned_upgrades", [])
	completed_levels = data.get("completed_levels", {})
	unlocked_districts = data.get("unlocked_districts", [StringName("business_center")])

# Get progress for a district (for main menu display)
func get_level_progress(district_id: String) -> Dictionary:
	var levels_count = 4  # Default
	var lm = get_node_or_null("/root/LevelManager")
	if lm != null:
		var d = lm.get_district(district_id)
		levels_count = d.get("levels", 4)
	
	var completed = 0
	var total_stars = 0
	for i in range(1, levels_count + 1):
		var level_id = district_id + "_" + str(i)
		var stars = completed_levels.get(level_id, 0)
		if stars > 0:
			completed += 1
			total_stars += stars
	
	return {
		"completed": completed,
		"total": levels_count,
		"stars": total_stars,
		"max_stars": levels_count * 3
	}

# Start a level - parse level_id and launch gameplay
func start_level(level_data: Dictionary) -> void:
	if level_data.is_empty():
		push_error("GameManager: Cannot start level - invalid level data")
		return
	
	var level_id = level_data.get("level_id", "")
	var parts = level_id.split("_")
	if parts.size() < 2:
		push_error("GameManager: Invalid level_id format: " + level_id)
		return
	
	var district_id = parts[0]
	var level_num = parts[1].to_int()
	
	# Store current level info
	current_district_id = StringName(district_id)
	current_state = 1  # In level
	
	# Get the boot_loader node to render gameplay
	var boot = get_node_or_null("/root/BootLoader")
	if boot != null:
		# Use UIRenderer to show gameplay via boot
		var ui = get_node_or_null("/root/UIRenderer")
		if ui != null and ui.has_method("show_gameplay"):
			# Set up simulation first
			var sim = get_node_or_null("/root/Simulation")
			if sim != null and sim.has_method("start_level"):
				sim.start_level(district_id, level_num, boot)
	else:
		# Fallback: change scene directly
		get_tree().change_scene_to_file("res://scenes/level/level.tscn")

# Navigate to district map
func go_to_district_map(district_id: String = "business_center") -> void:
	var boot = get_node_or_null("/root/BootLoader")
	if boot != null:
		var ui = get_node_or_null("/root/UIRenderer")
		if ui != null and ui.has_method("_show_district_select"):
			ui._show_district_select()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

# Reset game state for new game
func reset_game() -> void:
	cash = 50000
	total_stars = 0
	player_level = 1
	completed_levels = {}
	owned_upgrades = []
	unlocked_districts = [StringName("business_center")]
	apply_upgrades()
