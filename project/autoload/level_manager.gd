## LevelManager.gd — v0.1.43: SAFE autoload, NO class_name references
## Original version used DistrictData.new() — this caused crash if DistrictData
## class wasn't registered yet. Now completely self-contained.
extends Node

signal level_unlocked(level_id: StringName)
signal district_unlocked(district_id: StringName)

var districts: Dictionary = {}
var levels: Dictionary = {}

func _ready() -> void:
	_initialize_districts()

func _initialize_districts() -> void:
	# Self-contained district data — no class_name references
	districts = {}
	var data = [
		{"id": "business_center", "name": "Деловой центр", "levels": 4, "stars_req": 0, "traffic": 80, "grid": 8},
		{"id": "historic", "name": "Исторический центр", "levels": 4, "stars_req": 6, "traffic": 60, "grid": 7},
		{"id": "residential", "name": "Спальный район", "levels": 4, "stars_req": 12, "traffic": 50, "grid": 9},
		{"id": "industrial", "name": "Промзона", "levels": 4, "stars_req": 20, "traffic": 70, "grid": 10},
		{"id": "waterfront", "name": "Прибрежный район", "levels": 3, "stars_req": 28, "traffic": 55, "grid": 8},
		{"id": "suburban", "name": "Пригород", "levels": 3, "stars_req": 34, "traffic": 40, "grid": 10},
		{"id": "port", "name": "Портовый район", "levels": 3, "stars_req": 40, "traffic": 85, "grid": 9},
		{"id": "airport", "name": "Аэропорт", "levels": 2, "stars_req": 46, "traffic": 65, "grid": 8},
		{"id": "university", "name": "Университетский городок", "levels": 3, "stars_req": 50, "traffic": 45, "grid": 7},
		{"id": "tourist", "name": "Туристический район", "levels": 2, "stars_req": 54, "traffic": 50, "grid": 8},
	]
	for d in data:
		districts[d["id"]] = d

func get_district(d_id: String) -> Dictionary:
	return districts.get(d_id, {})

func get_districts_in_order() -> Array:
	# Returns districts in unlock order as dictionaries
	var order = ["business_center", "historic", "residential", "industrial", "waterfront", "suburban", "port", "airport", "university", "tourist"]
	var result = []
	for d_id in order:
		var d = districts.get(d_id, {})
		if d.size() > 0:
			result.append(d)
	return result

func get_level(d_id: String, level_num: int) -> Dictionary:
	# Returns level data as dictionary
	var district = districts.get(d_id, {})
	if district.size() == 0:
		return {}
	return {
		"level_id": d_id + "_" + str(level_num),
		"district_id": d_id,
		"level_number": level_num,
		"display_name": district.get("name", d_id) + " " + str(level_num)
	}

func is_level_unlocked(level_id: String) -> bool:
	# Parse level_id like "business_center_1"
	var parts = level_id.split("_")
	if parts.size() < 2:
		return false
	var d_id = parts[0]
	var level_num = parts[1].to_int()
	if level_num == 1:
		return true  # First level always unlocked
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		var prev_key = d_id + "_" + str(level_num - 1)
		return gs.completed_levels.has(prev_key) and gs.completed_levels[prev_key] > 0
	return false
