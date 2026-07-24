## EconomyManager.gd
## Handles fuel pricing, supply/demand, competitor AI economy, market simulation

extends Node

class_name EconomyManager

signal price_changed(new_price: float)
signal supply_delivered(amount: int, cost: int)
signal station_sold(station_id: int, price: int)
signal market_share_changed(player_share: float)

# Market constants
const BASE_FUEL_PRICE = 50.0        # Base price per liter
const MIN_FUEL_PRICE = 35.0         # Floor price
const MAX_FUEL_PRICE = 85.0         # Ceiling price
const WHOLESALE_MARGIN = 0.15       # Wholesale is 15% below retail
const DAILY_OPERATING_COST_BASE = 500  # Base daily cost per station

# Market state
var current_market_price: float = BASE_FUEL_PRICE
var wholesale_price: float = BASE_FUEL_PRICE * (1.0 - WHOLESALE_MARGIN)
var global_demand: float = 1.0
var price_history: Array[float] = []
var max_history_length: int = 168  # 7 days * 24 hours

# Competitor tracking
var competitor_prices: Dictionary = {}  # competitor_id -> price
var competitor_stations: Dictionary = {}  # competitor_id -> station count
var competitor_cash: Dictionary = {}  # competitor_id -> cash

# Player stations
var player_stations: Array = []  # Each: {id, level, price, storage, pumps, upgrades}
var player_cash: int = 50000
var player_reputation: float = 1.0  # 0.5 to 2.0

func _ready() -> void:
	DebugLogger.log_node_ready("EconomyManager", true, "start _ready")
	_reset_market()
	DebugLogger.log_node_ready("EconomyManager", true, "done")

func _reset_market() -> void:
	current_market_price = BASE_FUEL_PRICE
	wholesale_price = BASE_FUEL_PRICE * (1.0 - WHOLESALE_MARGIN)
	global_demand = 1.0
	price_history.clear()
	price_history.append(current_market_price)
	competitor_prices.clear()
	competitor_stations.clear()
	competitor_cash.clear()

func initialize_level(level_data: Resource, map_data: Dictionary) -> void:
	"""Set up economy for a new level"""
	_reset_market()
	
	current_market_price = level_data.market_base_price
	wholesale_price = current_market_price * (1.0 - WHOLESALE_MARGIN)
	
	# Initialize player station from map
	player_stations.clear()
	var player_pos = map_data.player_start
	player_stations.append({
		"id": 0,
		"pos": player_pos,
		"level": 1,
		"price": current_market_price,
		"storage_capacity": 5000,
		"current_fuel": 5000,
		"pump_count": 2,
		"pump_speed": 1.0,
		"daily_cost": DAILY_OPERATING_COST_BASE,
		"reputation": 1.0,
		"upgrades": []
	})
	
	# Initialize competitors from map
	for i in range(map_data.opponent_stations.size()):
		var opp_station = map_data.opponent_stations[i]
		var archetype_id = opp_station.archetype
		var archetype = _get_archetype_data(archetype_id)
		
		var comp_id = i + 1
		competitor_stations[comp_id] = opp_station.owner_index + 1  # Station count for this opponent
		competitor_cash[comp_id] = 30000  # Will be overridden by level data
		
		# Set initial price based on archetype
		var base_price = current_market_price * archetype.base_price_modifier
		competitor_prices[comp_id] = clamp(base_price, MIN_FUEL_PRICE, MAX_FUEL_PRICE)
	
	player_cash = 50000  # Will be overridden by level data

func _get_archetype_data(archetype_id: StringName) -> Resource:
	# This would normally come from OpponentArchetype resource
	# For now return defaults
	var defaults = {
		"base_price_modifier": 1.0,
		"price_change_frequency": 0.5,
		"min_profit_margin": 0.15,
		"reinvestment_rate": 0.3,
		"aggression": 1.0,
		"expansion_drive": 1.0
	}
	# In real implementation, load from OpponentArchetype resource
	return defaults

func simulate_hour(delta_hours: float = 1.0) -> Dictionary:
	"""Simulate one hour of market activity. Returns summary."""
	var summary = {
		"player_revenue": 0,
		"player_fuel_sold": 0,
		"competitor_actions": [],
		"market_events": [],
		"price_change": 0.0
	}
	
	# Update global demand (daily cycle + random)
	var hour_of_day = (Engine.get_time() * 24) % 24  # Simplified
	global_demand = _calculate_demand_curve(hour_of_day) * (0.9 + randf() * 0.2)
	
	# Player station sales
	for station in player_stations:
		var sold = _simulate_station_sales(station, global_demand, delta_hours)
		station.current_fuel -= sold
		summary.player_fuel_sold += sold
		summary.player_revenue += sold * station.price
	
	# Competitor AI decisions
	_simulate_competitors(delta_hours, summary)
	
	# Market price drift
	var old_price = current_market_price
	current_market_price = _calculate_market_price(summary)
	wholesale_price = current_market_price * (1.0 - WHOLESALE_MARGIN)
	summary.price_change = current_market_price - old_price
	
	# Record history
	price_history.append(current_market_price)
	if price_history.size() > max_history_length:
		price_history.pop_front()
	
	# Daily costs (every 24 hours)
	if fmod(Engine.get_time(), 24.0) < delta_hours:
		_apply_daily_costs(summary)
	
	# Auto-resupply if needed
	_check_auto_resupply()
	
	price_changed.emit(current_market_price)
	return summary

func _calculate_demand_curve(hour: float) -> float:
	"""Typical daily demand curve: peaks at 8am, 1pm, 6pm"""
	var peaks = [8.0, 13.0, 18.0]
	var base = 0.5
	for peak in peaks:
		var dist = abs(hour - peak)
		if dist > 12:
			dist = 24 - dist
		base += 0.5 * exp(-dist * 0.8)
	return clamp(base, 0.3, 1.5)

func _simulate_station_sales(station: Dictionary, demand: float, hours: float) -> int:
	"""Simulate fuel sales for a station"""
	# Base traffic depends on location (would come from map traffic nodes)
	var base_traffic = 50 * hours  # vehicles per hour
	
	# Price attractiveness: lower price = more customers
	var price_factor = 1.0
	var avg_competitor_price = _get_average_competitor_price()
	if avg_competitor_price > 0:
		price_factor = avg_competitor_price / station.price
		price_factor = clamp(price_factor, 0.3, 2.0)
	
	# Reputation factor
	var rep_factor = station.reputation
	
	# Pump throughput limit
	var max_throughput = station.pump_count * station.pump_speed * 20 * hours  # 20 vehicles/pump/hour
	
	var potential_sales = int(base_traffic * demand * price_factor * rep_factor)
	var actual_sales = min(potential_sales, max_throughput, station.current_fuel)
	
	return max(0, actual_sales)

func _get_average_competitor_price() -> float:
	if competitor_prices.is_empty():
		return current_market_price
	var sum = 0.0
	for price in competitor_prices.values():
		sum += price
	return sum / competitor_prices.size()

func _simulate_competitors(delta_hours: float, summary: Dictionary) -> void:
	"""AI competitors adjust prices, expand, upgrade"""
	for comp_id in competitor_prices.keys():
		var archetype = _get_archetype_data("opportunist")  # Simplified
		var current_price = competitor_prices[comp_id]
		var avg_price = _get_average_competitor_price()
		
		# Price adjustment logic
		var should_change = randf() < archetype.price_change_frequency * delta_hours / 24.0
		if should_change:
			var new_price = current_price
			
			# React to player
			var player_price = player_stations[0].price if player_stations else current_market_price
			var price_diff = player_price - current_price
			
			if price_diff > 2.0:  # Player is more expensive
				# Opportunity to raise price
				new_price += randf() * 2.0 * archetype.aggression
			elif price_diff < -2.0:  # Player is cheaper
				# Must match or beat
				new_price = max(current_price + price_diff * 0.5, wholesale_price * (1.0 + archetype.min_profit_margin))
				new_price *= (1.0 - archetype.price_sensitivity * 0.1)
			else:
				# Random walk towards market price
				new_price += (avg_price - current_price) * 0.1 + (randf() - 0.5) * 1.0
			
			new_price = clamp(new_price, wholesale_price * (1.0 + archetype.min_profit_margin), MAX_FUEL_PRICE)
			competitor_prices[comp_id] = new_price
			summary.competitor_actions.append({"id": comp_id, "action": "price_change", "new_price": new_price})
		
		# Expansion logic (simplified - would buy stations on map)
		if randf() < archetype.expansion_drive * 0.01 * delta_hours:
			var cash = competitor_cash.get(comp_id, 0)
			var station_cost = 50000 * 1.5  # Approximate
			if cash > station_cost * 2:
				# Would expand - in full sim, place on map
				summary.competitor_actions.append({"id": comp_id, "action": "expand_attempt"})

func _calculate_market_price(summary: Dictionary) -> float:
	"""Calculate new market equilibrium price"""
	# Supply/demand balance
	var total_supply = 0
	for station in player_stations:
		total_supply += station.current_fuel
	
	# Competitor supply (estimated)
	total_supply += competitor_prices.size() * 3000
	
	var demand_pressure = global_demand * 10000  # Arbitrary scale
	var supply_pressure = total_supply / 1000.0
	
	var price_pressure = (demand_pressure - supply_pressure) / 10000.0
	var new_price = current_market_price * (1.0 + price_pressure * 0.05)
	
	return clamp(new_price, MIN_FUEL_PRICE, MAX_FUEL_PRICE)

func _apply_daily_costs(summary: Dictionary) -> void:
	"""Apply daily operating costs to all stations"""
	for station in player_stations:
		var cost = station.daily_cost
		player_cash -= cost
		summary.market_events.append({"type": "daily_cost", "station": station.id, "amount": cost})
	
	# Competitor costs
	for comp_id in competitor_cash.keys():
		var station_count = competitor_stations.get(comp_id, 1)
		var cost = station_count * DAILY_OPERATING_COST_BASE * 1.2
		competitor_cash[comp_id] -= cost

func _check_auto_resupply() -> void:
	"""Auto-order fuel when low (if upgrade owned)"""
	for station in player_stations:
		if station.current_fuel < station.storage_capacity * 0.3:
			# Check if player has auto-order upgrade
		var has_auto = GameManager.has_upgrade("logistics_auto_order")
		if has_auto:
			var order_amount = station.storage_capacity - station.current_fuel
			var cost = int(order_amount * wholesale_price)
			if GameManager.spend_cash(cost):
					station.current_fuel = station.storage_capacity
					supply_delivered.emit(order_amount, cost)

# Player actions
func set_player_price(new_price: float) -> bool:
	if player_stations.is_empty():
		return false
	var clamped = clamp(new_price, MIN_FUEL_PRICE, MAX_FUEL_PRICE)
	player_stations[0].price = clamped
	price_changed.emit(clamped)
	return true

func buy_fuel(amount: int) -> bool:
	var cost = int(amount * wholesale_price)
	if player_cash >= cost:
		player_cash -= cost
		player_stations[0].current_fuel = min(player_stations[0].current_fuel + amount, player_stations[0].storage_capacity)
		supply_delivered.emit(amount, cost)
		return true
	return false

func upgrade_station(station_id: int, upgrade_type: String, cost: int) -> bool:
	if player_cash >= cost:
		player_cash -= cost
		# Apply upgrade to station
		var station = player_stations[station_id]
		match upgrade_type:
			"storage":
				station.storage_capacity = int(station.storage_capacity * 1.5)
			"pumps":
				station.pump_count += 1
			"speed":
				station.pump_speed *= 1.2
			"reputation":
				station.reputation = min(2.0, station.reputation + 0.1)
		return true
	return false

func buy_opponent_station(comp_id: int, station_index: int) -> bool:
	"""Buy out an opponent's station"""
	if not competitor_stations.has(comp_id):
		return false
	
	var station_count = competitor_stations[comp_id]
	if station_count <= 0:
		return false
	
	# Calculate buyout price based on opponent loyalty, player reputation
	var archetype = _get_archetype_data("local")  # Simplified
	var loyalty = archetype.loyalty if archetype != null else 1.0
	var base_price = 50000 * station_count
	var multiplier = loyalty * (2.0 - player_reputation)
	var price = int(base_price * multiplier)
	
	if player_cash >= price:
		player_cash -= price
		competitor_stations[comp_id] -= 1
		competitor_cash[comp_id] = competitor_cash.get(comp_id, 0) + price
		
		# Add station to player
		player_stations.append({
			"id": player_stations.size(),
			"price": current_market_price,
			"storage_capacity": 5000,
			"current_fuel": 2000,
			"pump_count": 2,
			"pump_speed": 1.0,
			"daily_cost": DAILY_OPERATING_COST_BASE,
			"reputation": 1.0,
			"upgrades": []
		})
		
		station_sold.emit(comp_id, price)
		return true
	return false

func get_market_summary() -> Dictionary:
	return {
		"market_price": current_market_price,
		"wholesale_price": wholesale_price,
		"global_demand": global_demand,
		"player_stations": player_stations.size(),
		"player_cash": player_cash,
		"competitor_count": competitor_prices.size(),
		"price_history": price_history[-24:] if price_history.size() > 24 else price_history
	}

func get_competitor_data(comp_id: int) -> Dictionary:
	return {
		"stations": competitor_stations.get(comp_id, 0),
		"price": competitor_prices.get(comp_id, current_market_price),
		"cash": competitor_cash.get(comp_id, 0)
	}

# Effect application from upgrades
func apply_upgrade_effect(effect_key: String, value: Variant) -> void:
	match effect_key:
		"purchase_price_multiplier":
			# Modify wholesale price globally
			wholesale_price *= value
		"delivery_cost_multiplier":
			# Would affect delivery costs
			pass
		"delivery_reliability":
			pass
		"margin_boost":
			# Player can charge more
			pass
		"auto_price_optimization":
			pass
		"offline_earnings":
			pass
		"franchise_fee_income":
			pass
		_:
			pass