## UpgradeManager.gd
## Manages upgrade tree, purchases, and effect application

extends Node

class_name UpgradeManager

signal upgrade_purchased(upgrade_id: StringName)
signal upgrade_refunded(upgrade_id: StringName)
signal tree_updated()

var upgrades: Dictionary = {}  # upgrade_id -> UpgradeData
var category_order: Array[int] = [
	UpgradeData.UpgradeCategory.STATION,
	UpgradeData.UpgradeCategory.LOGISTICS,
	UpgradeData.UpgradeCategory.MARKETING,
	UpgradeData.UpgradeCategory.PERSONNEL,
	UpgradeData.UpgradeCategory.TECHNOLOGY,
	UpgradeData.UpgradeCategory.SPECIAL
]

func _ready() -> void:
	DebugLogger.log_node_ready("UpgradeManager", true, "start _ready")
	_initialize_upgrades()
	DebugLogger.log_node_ready("UpgradeManager", true, "done")

func _initialize_upgrades() -> void:
	upgrades = UpgradeData.create_upgrade_tree()

func get_upgrade(upgrade_id: StringName) -> UpgradeData:
	return upgrades.get(upgrade_id)

func get_all_upgrades() -> Array[UpgradeData]:
	return upgrades.values()

func get_upgrades_by_category(category: int) -> Array[UpgradeData]:
	var result = []
	for upgrade in upgrades.values():
		if upgrade.category == category:
			result.append(upgrade)
	# Sort by tier then position
	result.sort_custom(self, "_compare_upgrade_sort")
	return result

func _compare_upgrade_sort(a: UpgradeData, b: UpgradeData) -> int:
	if a.tier != b.tier:
		return a.tier - b.tier
	return a.ui_position.x - b.ui_position.x

func get_available_upgrades(owned: Array[StringName], player_level: int, stars: int, cash: int) -> Array[UpgradeData]:
	var result = []
	for upgrade in upgrades.values():
		if upgrade.can_purchase(owned, player_level, stars, cash):
			result.append(upgrade)
	return result

func get_purchased_upgrades(owned: Array[StringName]) -> Array[UpgradeData]:
	var result = []
	for uid in owned:
		if upgrades.has(uid):
			result.append(upgrades[uid])
	return result

func get_upgrade_tree_layout() -> Dictionary:
	"""Returns structured data for UI tree rendering"""
	var layout = {}
	for cat in category_order:
		var cat_upgrades = get_upgrades_by_category(cat)
		if cat_upgrades.is_empty():
			continue
		
		# Group by tier
		var tiers = {}
		for upg in cat_upgrades:
			if not tiers.has(upg.tier):
				tiers[upg.tier] = []
			tiers[upg.tier].append(upg)
		
		layout[cat] = {
			"name": _category_name(cat),
			"tiers": tiers,
			"color": _category_color(cat)
		}
	return layout

func _category_name(cat: int) -> String:
	match cat:
		UpgradeData.UpgradeCategory.STATION: return "Заправка"
		UpgradeData.UpgradeCategory.LOGISTICS: return "Логистика"
		UpgradeData.UpgradeCategory.MARKETING: return "Маркетинг"
		UpgradeData.UpgradeCategory.PERSONNEL: return "Персонал"
		UpgradeData.UpgradeCategory.TECHNOLOGY: return "Технологии"
		UpgradeData.UpgradeCategory.SPECIAL: return "Особое"
		_: return "Unknown"

func _category_color(cat: int) -> Color:
	match cat:
		UpgradeData.UpgradeCategory.STATION: return Color(0.4, 0.7, 0.4)
		UpgradeData.UpgradeCategory.LOGISTICS: return Color(0.4, 0.5, 0.8)
		UpgradeData.UpgradeCategory.MARKETING: return Color(0.9, 0.6, 0.3)
		UpgradeData.UpgradeCategory.PERSONNEL: return Color(0.8, 0.4, 0.7)
		UpgradeData.UpgradeCategory.TECHNOLOGY: return Color(0.5, 0.8, 0.8)
		UpgradeData.UpgradeCategory.SPECIAL: return Color(1.0, 0.8, 0.2)
		_: return Color(0.5, 0.5, 0.5)

func get_prerequisite_chain(upgrade_id: StringName) -> Array[StringName]:
	"""Get all transitive prerequisites for an upgrade"""
	var result = []
	var visited = []
	_collect_prereqs(upgrade_id, result, visited)
	return result

func _collect_prereqs(uid: StringName, result: Array, visited: Array) -> void:
	if uid in visited:
		return
	visited.append(uid)
	
	var upgrade = upgrades.get(uid)
	if not upgrade:
		return
	
	for prereq in upgrade.prerequisite_ids:
		if prereq not in result:
			result.append(prereq)
		_collect_prereqs(prereq, result, visited)
	
	for alt_group in upgrade.alternative_prerequisites:
		for alt in alt_group:
			if alt not in result:
				result.append(alt)
			_collect_prereqs(alt, result, visited)

func get_unlocks(upgrade_id: StringName) -> Array[StringName]:
	var upgrade = upgrades.get(upgrade_id)
	return upgrade.unlocks_ids if upgrade else []

func calculate_total_star_cost(upgrade_ids: Array[StringName]) -> int:
	var total = 0
	for uid in upgrade_ids:
		var upg = upgrades.get(uid)
		if upg:
			total += upg.star_cost
	return total

func calculate_total_cash_cost(upgrade_ids: Array[StringName]) -> int:
	var total = 0
	for uid in upgrade_ids:
		var upg = upgrades.get(uid)
		if upg:
			total += upg.cash_cost
	return total

func get_combined_effects(owned_upgrades: Array[StringName]) -> Dictionary:
	"""Combine all effects from owned upgrades"""
	var combined = {}
	for uid in owned_upgrades:
		var upg = upgrades.get(uid)
		if upg:
			for key, value in upg.effects:
				if combined.has(key):
					var existing = combined[key]
					if existing is float or existing is int:
						# Multiplicative for numeric effects
						if key.begins_with("multiplier") or key.ends_with("_multiplier") or key.begins_with("bonus_"):
							combined[key] = existing * value
						else:
							combined[key] = existing + value
					else:
						combined[key] = value
				else:
					combined[key] = value
	return combined

func apply_upgrades_to_station(station: Node, owned_upgrades: Array[StringName]) -> void:
	"""Apply all relevant upgrade effects to a station node"""
	for uid in owned_upgrades:
		var upg = upgrades.get(uid)
		if upg and (upg.category == UpgradeData.UpgradeCategory.STATION or upg.category == UpgradeData.UpgradeCategory.SPECIAL):
			upg.apply_effects(station)

func apply_upgrades_to_player(player: Node, owned_upgrades: Array[StringName]) -> void:
	"""Apply player-wide upgrades (marketing, personnel, tech)"""
	for uid in owned_upgrades:
		var upg = upgrades.get(uid)
		if upg and upg.category != UpgradeData.UpgradeCategory.STATION:
			upg.apply_effects(player)

func get_next_upgrades_in_path(owned: Array[StringName]) -> Array[UpgradeData]:
	"""Get upgrades that are one step away from current owned set"""
	var result = []
	var owned_set = owned.duplicate()
	
	for upgrade in upgrades.values():
		if upgrade.upgrade_id in owned_set:
			continue
		# Check if all prereqs are met (or alternative)
		var can_unlock = true
		for prereq in upgrade.prerequisite_ids:
			if prereq not in owned_set:
				can_unlock = false
				break
		if not can_unlock:
			continue
		
		# Check alternative groups
		for alt_group in upgrade.alternative_prerequisites:
			var has_any = false
			for alt in alt_group:
				if alt in owned_set:
					has_any = true
					break
			if not has_any and alt_group.size() > 0:
				can_unlock = false
				break
		
		if can_unlock:
			result.append(upgrade)
	
	return result

func reset_upgrade(upgrade_id: StringName, owned_upgrades: Array[StringName]) -> bool:
	"""Refund an upgrade (for testing or respect system)"""
	if upgrade_id not in owned_upgrades:
		return false
	
	owned_upgrades.erase(upgrade_id)
	upgrade_refunded.emit(upgrade_id)
	tree_updated.emit()
	return true