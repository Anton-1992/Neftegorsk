## GameState.gd — v0.1.44: holds all game state, save/load
## NO class_name, NO @onready, NO gui_input — Android safe
## v0.1.44: ALL dict access uses bracket notation — data["key"] NOT data.key
## CRITICAL: dot notation on Dictionary can conflict with built-in properties
## on Android runtime (e.g., data.name conflicts with Node.name)
extends Node

var cash: int = 50000
var total_stars: int = 0
var player_level: int = 1
var unlocked_districts: Array = [StringName("business_center")]
var completed_levels: Dictionary = {}
var owned_upgrades: Array = []

var district_names: Dictionary = {}
var district_levels_count: Dictionary = {}
var district_req_stars: Dictionary = {}
var district_traffic: Dictionary = {}
var district_grid_sizes: Dictionary = {}
var district_colors: Dictionary = {}

var upgrade_defs: Array = []

var player_pumps: int = 2
var player_fuel_capacity: int = 5000
var negotiation_factor: float = 1.0
var marketing_factor: float = 1.0
var speed_factor: float = 1.0
var capacity_multiplier: float = 1.0
var auto_order_active: bool = false

var boot_ref: Control = null

func init_state(boot: Control) -> void:
	boot_ref = boot
	_init_district_data()
	_init_upgrade_defs()
	_load_save()

func _init_district_data() -> void:
	var d = {}
	d["business_center"] = {"name": "Деловой центр", "levels": 4, "stars_req": 0, "traffic": 80, "grid": 8, "color": Color(0.25, 0.25, 0.35)}
	d["historic"] = {"name": "Исторический центр", "levels": 4, "stars_req": 6, "traffic": 60, "grid": 7, "color": Color(0.35, 0.3, 0.25)}
	d["residential"] = {"name": "Спальный район", "levels": 4, "stars_req": 12, "traffic": 50, "grid": 9, "color": Color(0.3, 0.35, 0.3)}
	d["industrial"] = {"name": "Промзона", "levels": 4, "stars_req": 20, "traffic": 70, "grid": 10, "color": Color(0.25, 0.25, 0.3)}
	d["waterfront"] = {"name": "Прибрежный район", "levels": 3, "stars_req": 28, "traffic": 55, "grid": 8, "color": Color(0.2, 0.35, 0.45)}
	d["suburban"] = {"name": "Пригород", "levels": 3, "stars_req": 34, "traffic": 40, "grid": 10, "color": Color(0.35, 0.4, 0.3)}
	d["port"] = {"name": "Портовый район", "levels": 3, "stars_req": 40, "traffic": 85, "grid": 9, "color": Color(0.2, 0.3, 0.35)}
	d["airport"] = {"name": "Аэропорт", "levels": 2, "stars_req": 46, "traffic": 65, "grid": 8, "color": Color(0.3, 0.3, 0.4)}
	d["university"] = {"name": "Университетский городок", "levels": 3, "stars_req": 50, "traffic": 45, "grid": 7, "color": Color(0.3, 0.4, 0.35)}
	d["tourist"] = {"name": "Туристический район", "levels": 2, "stars_req": 54, "traffic": 50, "grid": 8, "color": Color(0.4, 0.35, 0.3)}
	
	district_names = {}
	district_levels_count = {}
	district_req_stars = {}
	district_traffic = {}
	district_grid_sizes = {}
	district_colors = {}
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	for d_id in order:
		if not d.has(d_id):
			continue
		var data = d[d_id]
		# CRITICAL: Use bracket notation ONLY — dot notation on Dictionary
		# conflicts with built-in properties (name, color) on Android runtime
		district_names[d_id] = data["name"]
		district_levels_count[d_id] = data["levels"]
		district_req_stars[d_id] = data["stars_req"]
		district_traffic[d_id] = data["traffic"]
		district_grid_sizes[d_id] = data["grid"]
		district_colors[d_id] = data["color"]

func _init_upgrade_defs() -> void:
	upgrade_defs = [
		{"id": "big_tanks", "name": "Большие резервуары", "desc": "Вместимость x1.5", "stars": 1, "cash": 10000, "cat": "station"},
		{"id": "extra_pump", "name": "Дополнительная колонка", "desc": "+1 колонка (3 вместо 2)", "stars": 1, "cash": 15000, "cat": "station"},
		{"id": "auto_order", "name": "Автозаказ топлива", "desc": "Автозаказ при <30% топлива", "stars": 2, "cash": 20000, "cat": "logistics"},
		{"id": "negotiation", "name": "Навык переговоров", "desc": "Выкуп дешевле x0.8", "stars": 2, "cash": 15000, "cat": "marketing"},
		{"id": "marketing", "name": "Местная реклама", "desc": "Трафик x1.2", "stars": 1, "cash": 10000, "cat": "marketing"},
		{"id": "fast_pumps", "name": "Быстрые колонки", "desc": "Скорость заправки x1.25", "stars": 2, "cash": 20000, "cat": "station"},
	]

func apply_upgrades() -> void:
	player_pumps = 2
	player_fuel_capacity = 5000
	capacity_multiplier = 1.0
	negotiation_factor = 1.0
	marketing_factor = 1.0
	speed_factor = 1.0
	auto_order_active = false
	
	if "big_tanks" in owned_upgrades:
		capacity_multiplier = 1.5
		player_fuel_capacity = int(5000 * capacity_multiplier)
	if "extra_pump" in owned_upgrades:
		player_pumps = 3
	if "auto_order" in owned_upgrades:
		auto_order_active = true
	if "negotiation" in owned_upgrades:
		negotiation_factor = 0.8
	if "marketing" in owned_upgrades:
		marketing_factor = 1.2
	if "fast_pumps" in owned_upgrades:
		speed_factor = 1.25

func is_district_unlocked(d_id: String) -> bool:
	return unlocked_districts.has(StringName(d_id))

func is_level_unlocked(d_id: String, num: int) -> bool:
	if not is_district_unlocked(d_id):
		return false
	if num == 1:
		return true
	var prev_key = d_id + "_" + str(num - 1)
	return completed_levels.has(prev_key) and completed_levels[prev_key] > 0

func save_game() -> void:
	var save_data = {
		"cash": cash,
		"total_stars": total_stars,
		"player_level": player_level,
		"completed_levels": completed_levels,
		"unlocked_districts": unlocked_districts,
		"owned_upgrades": owned_upgrades,
	}
	var json_str = JSON.stringify(save_data)
	var file = FileAccess.open("user://neftegorsk_save.json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()

func _load_save() -> void:
	if not FileAccess.file_exists("user://neftegorsk_save.json"):
		return
	var file = FileAccess.open("user://neftegorsk_save.json", FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return
	var data = json.data
	if data == null:
		return
	# CRITICAL: Use bracket notation ONLY for dict access on Android
	if data.has("cash"):
		cash = int(data["cash"])
	if data.has("total_stars"):
		total_stars = int(data["total_stars"])
	if data.has("player_level"):
		player_level = int(data["player_level"])
	if data.has("completed_levels"):
		completed_levels = {}
		var cl = data["completed_levels"]
		for key in cl:
			completed_levels[key] = int(cl[key])
	if data.has("unlocked_districts"):
		unlocked_districts = []
		var ud = data["unlocked_districts"]
		for d in ud:
			unlocked_districts.append(StringName(str(d)))
	if data.has("owned_upgrades"):
		owned_upgrades = []
		var ou = data["owned_upgrades"]
		for u in ou:
			owned_upgrades.append(str(u))
