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
