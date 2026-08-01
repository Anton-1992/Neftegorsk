## EconomyManager.gd — v0.1.43: SAFE autoload, NO class_name references
## Original version referenced OpponentArchetype resource — removed.
## Now completely self-contained with basic market simulation.
extends Node

signal price_changed(new_price: float)
signal supply_delivered(amount: int, cost: int)

const BASE_FUEL_PRICE = 50.0
const MIN_FUEL_PRICE = 35.0
const MAX_FUEL_PRICE = 85.0
const WHOLESALE_MARGIN = 0.15

var current_market_price: float = BASE_FUEL_PRICE
var wholesale_price: float = BASE_FUEL_PRICE * (1.0 - WHOLESALE_MARGIN)
var global_demand: float = 1.0

func _ready() -> void:
	_reset_market()

func _reset_market() -> void:
	current_market_price = BASE_FUEL_PRICE
	wholesale_price = BASE_FUEL_PRICE * (1.0 - WHOLESALE_MARGIN)
	global_demand = 1.0

func get_market_summary() -> Dictionary:
	return {
		"market_price": current_market_price,
		"wholesale_price": wholesale_price,
		"global_demand": global_demand,
	}
