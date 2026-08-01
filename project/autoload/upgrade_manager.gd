## UpgradeManager.gd — v0.1.44: SAFE autoload, NO class_name references
## v0.1.44: ALL dict access uses bracket notation
extends Node

signal upgrade_purchased(upgrade_id: StringName)
signal upgrade_refunded(upgrade_id: StringName)
signal tree_updated()

var upgrades: Dictionary = {}

func _ready() -> void:
	_initialize_upgrades()

func _initialize_upgrades() -> void:
	# Self-contained upgrade definitions — no class_name references
	upgrades = {}
	var data = [
		{"id": "big_tanks", "name": "Большие резервуары", "desc": "Вместимость x1.5", "stars": 1, "cat": "station"},
		{"id": "extra_pump", "name": "Дополнительная колонка", "desc": "+1 колонка", "stars": 1, "cat": "station"},
		{"id": "fast_pumps", "name": "Быстрые колонки", "desc": "Скорость заправки x1.25", "stars": 2, "cat": "station"},
		{"id": "auto_order", "name": "Автозаказ топлива", "desc": "Автозаказ при <30% топлива", "stars": 2, "cat": "logistics"},
		{"id": "negotiation", "name": "Навык переговоров", "desc": "Выкуп дешевле x0.8", "stars": 2, "cat": "marketing"},
		{"id": "marketing", "name": "Местная реклама", "desc": "Трафик x1.2", "stars": 1, "cat": "marketing"},
	]
	for d in data:
		upgrades[d["id"]] = d

func get_upgrade(upgrade_id: StringName):
	return upgrades.get(str(upgrade_id))

func get_all_upgrades() -> Array:
	return upgrades.values()

func get_available_upgrades(owned: Array, stars: int) -> Array:
	var result = []
	for uid in upgrades:
		var upg = upgrades[uid]
		if uid in owned:
			continue
		if stars >= upg["stars"]:
			result.append(upg)
	return result

func get_combined_effects(owned_upgrades: Array) -> Dictionary:
	var combined = {}
	for uid in owned_upgrades:
		var upg = upgrades.get(uid)
		if upg:
			for key in upg:
				if key != "id" and key != "name" and key != "desc" and key != "stars" and key != "cat":
					combined[key] = upg[key]
	return combined
