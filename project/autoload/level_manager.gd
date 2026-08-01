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
		districts[d.id] = d

func get_district(d_id: String) -> Dictionary:
	return districts.get(d_id, {})
