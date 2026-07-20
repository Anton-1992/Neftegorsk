## UpgradeData.gd
## Defines upgrade tree nodes (Homescapes-style branching upgrades)

class_name UpgradeData
extends Resource

enum UpgradeCategory {
	STATION,      # Gas station improvements
	LOGISTICS,    # Supply chain, delivery, storage
	MARKETING,    # Advertising, loyalty, pricing power
	PERSONNEL,    # Staff, training, efficiency
	TECHNOLOGY,   # Automation, alt fuels, analytics
	SPECIAL       # Unique one-time unlocks
}

enum UpgradeTier {
	TIER_1 = 1,   # Basic, cheap
	TIER_2 = 2,   # Intermediate
	TIER_3 = 3,   # Advanced
	TIER_4 = 4,   # Expert
	TIER_5 = 5    # Master/Ultimate
}

@export_group("Identity")
@export var upgrade_id: StringName = ""
@export var display_name: String = "Улучшение"
@export var description: String = ""
@export var icon_path: String = ""
@export var category: int = 0  # UpgradeCategory
@export var tier: int = 1      # UpgradeTier

@export_group("Costs")
@export var star_cost: int = 1              # Stars required
@export var cash_cost: int = 0              # Additional cash cost (optional)
@export var requires_level: int = 1         # Minimum player level

@export_group("Prerequisites (Tree Structure)")
@export var prerequisite_ids: Array[StringName] = []  # Must have ALL of these
@export var alternative_prerequisites: Array[Array[StringName]] = []  # OR groups
@export var is_root: bool = false           # No prerequisites needed
@export var unlocks_ids: Array[StringName] = []  # What this unlocks (for UI arrows)

@export_group("Effects")
@export var effects: Dictionary = {}  # Key-value effects, e.g. {"storage_capacity": 1.2, "refuel_speed": 1.15}

@export_group("Visual")
@export var ui_position: Vector2 = Vector2(0, 0)  # Position in upgrade tree UI
@export var branch_color: Color = Color(0.4, 0.7, 0.4)

func can_purchase(owned_upgrades: Array[StringName], player_level: int, available_stars: int, available_cash: int) -> bool:
	if player_level < requires_level:
		return false
	if available_stars < star_cost:
		return false
	if available_cash < cash_cost:
		return false
	if upgrade_id in owned_upgrades:
		return false
	
	# Check ALL prerequisites
	for prereq in prerequisite_ids:
		if prereq not in owned_upgrades:
			return false
	
	# Check OR groups (at least one from each group)
	for alt_group in alternative_prerequisites:
		var has_any = false
		for alt in alt_group:
			if alt in owned_upgrades:
				has_any = true
				break
		if not has_any and alt_group.size() > 0:
			return false
	
	return true

func get_effect_value(effect_key: String, default: Variant = 0) -> Variant:
	return effects.get(effect_key, default)

func apply_effects(target: Object) -> void:
	"""Apply effects to a target object (station, player, etc.)"""
	for key, value in effects:
		if target.has_method("apply_upgrade_effect"):
			target.apply_upgrade_effect(key, value)
		elif target.has_property(key):
			var current = target.get(key)
			if current is float or current is int:
				target.set(key, current * value)
			elif current is String:
				# String effects: replace or append
				target.set(key, str(value))

static func create_upgrade_tree() -> Dictionary:
	"""Factory for the full upgrade tree (Homescapes-style)"""
	var upgrades = {}
	
	# ===== STATION UPGRADES =====
	
	# Tier 1
	var u = UpgradeData.new()
	u.upgrade_id = "station_capacity_1"
	u.display_name = "Большие резервуары I"
	u.description = "Увеличивает вместимость резервуаров заправки на 20%"
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_1
	u.star_cost = 1
	u.is_root = true
	u.unlocks_ids = ["station_capacity_2", "station_pump_speed_1"]
	u.effects = {"storage_capacity": 1.2}
	u.ui_position = Vector2(0, 0)
	upgrades["station_capacity_1"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "station_pump_speed_1"
	u.display_name = "Быстрые колонки I"
	u.description = "Ускоряет заправку на 15%, клиенты уходят быстрее"
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_1
	u.star_cost = 1
	u.is_root = true
	u.unlocks_ids = ["station_pump_speed_2", "station_multi_pump_1"]
	u.effects = {"refuel_speed": 1.15, "customer_patience": 1.1}
	u.ui_position = Vector2(200, 0)
	upgrades["station_pump_speed_1"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "station_price_flex_1"
	u.display_name = "Гибкое ценообразование I"
	u.description = "Позволяет менять цену чаще без потери лояльности"
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_1
	u.star_cost = 1
	u.is_root = true
	u.unlocks_ids = ["station_price_flex_2", "marketing_dynamic_pricing"]
	u.effects = {"price_change_cooldown": 0.7, "loyalty_loss_on_price_change": 0.5}
	u.ui_position = Vector2(400, 0)
	upgrades["station_price_flex_1"] = u
	
	# Tier 2
	u = UpgradeData.new()
	u.upgrade_id = "station_capacity_2"
	u.display_name = "Большие резервуары II"
	u.description = "Ещё +25% вместимости. Меньше поставок = меньше простоя."
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_2
	u.star_cost = 2
	u.prerequisite_ids = ["station_capacity_1"]
	u.unlocks_ids = ["station_capacity_3", "logistics_auto_order"]
	u.effects = {"storage_capacity": 1.25, "delivery_frequency": 0.9}
	u.ui_position = Vector2(0, 150)
	upgrades["station_capacity_2"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "station_pump_speed_2"
	u.display_name = "Быстрые колонки II"
	u.description = "Ещё +20% скорости. Очереди исчезают."
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_2
	u.star_cost = 2
	u.prerequisite_ids = ["station_pump_speed_1"]
	u.unlocks_ids = ["station_pump_speed_3", "station_premium_pumps"]
	u.effects = {"refuel_speed": 1.2, "max_queue_length": 1.5}
	u.ui_position = Vector2(200, 150)
	upgrades["station_pump_speed_2"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "station_multi_pump_1"
	u.display_name = "Мульти-колонки I"
	u.description = "Одна колонка обслуживает 2 машины одновременно"
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_2
	u.star_cost = 2
	u.prerequisite_ids = ["station_pump_speed_1"]
	u.unlocks_ids = ["station_multi_pump_2"]
	u.effects = {"simultaneous_vehicles": 2, "station_throughput": 1.4}
	u.ui_position = Vector2(400, 150)
	upgrades["station_multi_pump_1"] = u
	
	# Tier 3
	u = UpgradeData.new()
	u.upgrade_id = "station_premium_pumps"
	u.display_name = "Премиум колонки"
	u.description = "Обслуживает премиум-клиентов. +50% прибыль с VIP машин"
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_3
	u.star_cost = 3
	u.prerequisite_ids = ["station_pump_speed_2"]
	u.unlocks_ids = ["station_ev_chargers"]
	u.effects = {"vip_multiplier": 1.5, "attract_vip_chance": 0.15}
	u.ui_position = Vector2(200, 300)
	upgrades["station_premium_pumps"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "station_ev_chargers"
	u.display_name = "Зарядки для ЭВ"
	u.description = "Привлекает электромобили. Новый сегмент клиентов, выше чек."
	u.category = UpgradeCategory.STATION
	u.tier = UpgradeTier.TIER_4
	u.star_cost = 4
	u.prerequisite_ids = ["station_premium_pumps", "technology_battery_tech"]
	u.effects = {"ev_traffic_share": 0.2, "ev_profit_margin": 1.8}
	u.ui_position = Vector2(200, 450)
	upgrades["station_ev_chargers"] = u
	
	# ===== LOGISTICS UPGRADES =====
	
	u = UpgradeData.new()
	u.upgrade_id = "logistics_auto_order"
	u.display_name = "Автозаказ топлива"
	u.description = "Автоматически заказывает топливо при пороге 30%. Никаких простоев."
	u.category = UpgradeCategory.LOGISTICS
	u.tier = UpgradeTier.TIER_2
	u.star_cost = 2
	u.prerequisite_ids = ["station_capacity_2"]
	u.unlocks_ids = ["logistics_bulk_discount", "logistics_predictive"]
	u.effects = {"auto_order_threshold": 0.3, "stockout_penalty": 0.0}
	u.ui_position = Vector2(-200, 150)
	upgrades["logistics_auto_order"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "logistics_bulk_discount"
	u.display_name = "Оптовые скидки"
	u.description = "Закупка крупными партиями: -10% к закупочной цене"
	u.category = UpgradeCategory.LOGISTICS
	u.tier = UpgradeTier.TIER_3
	u.star_cost = 3
	u.prerequisite_ids = ["logistics_auto_order"]
	u.unlocks_ids = ["logistics_own_tankers"]
	u.effects = {"purchase_price_multiplier": 0.9, "min_order_volume": 1.5}
	u.ui_position = Vector2(-200, 300)
	upgrades["logistics_bulk_discount"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "logistics_own_tankers"
	u.display_name = "Свои цистерны"
	u.description = "Собственный автопарк доставки. -15% затрат, контроль сроков."
	u.category = UpgradeCategory.LOGISTICS
	u.tier = UpgradeTier.TIER_4
	u.star_cost = 4
	u.prerequisite_ids = ["logistics_bulk_discount"]
	u.effects = {"delivery_cost_multiplier": 0.85, "delivery_reliability": 1.0}
	u.ui_position = Vector2(-200, 450)
	upgrades["logistics_own_tankers"] = u
	
	# ===== MARKETING UPGRADES =====
	
	u = UpgradeData.new()
	u.upgrade_id = "marketing_local_ads"
	u.display_name = "Местная реклама"
	u.description = "Билборды, радио. +20% трафика на всех станциях в районе"
	u.category = UpgradeCategory.MARKETING
	u.tier = UpgradeTier.TIER_1
	u.star_cost = 1
	u.is_root = true
	u.unlocks_ids = ["marketing_loyalty_program", "marketing_dynamic_pricing"]
	u.effects = {"district_traffic_bonus": 1.2, "brand_awareness": 1.1}
	u.ui_position = Vector2(0, -150)
	upgrades["marketing_local_ads"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "marketing_loyalty_program"
	u.display_name = "Программа лояльности"
	u.description = "Карты постоянного клиента. Клиенты возвращаются чаще на 30%"
	u.category = UpgradeCategory.MARKETING
	u.tier = UpgradeTier.TIER_2
	u.star_cost = 2
	u.prerequisite_ids = ["marketing_local_ads"]
	u.unlocks_ids = ["marketing_vip_club", "marketing_app"]
	u.effects = {"customer_retention": 1.3, "repeat_visit_chance": 0.4}
	u.ui_position = Vector2(0, -300)
	upgrades["marketing_loyalty_program"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "marketing_dynamic_pricing"
	u.display_name = "Динамическое ценообразование"
	u.description = "ИИ подбирает оптимальную цену в реальном времени. +15% маржа"
	u.category = UpgradeCategory.MARKETING
	u.tier = UpgradeTier.TIER_3
	u.star_cost = 3
	u.prerequisite_ids = ["marketing_local_ads", "station_price_flex_2"]
	u.unlocks_ids = ["marketing_ai_pricing"]
	u.effects = {"auto_price_optimization": true, "margin_boost": 1.15}
	u.ui_position = Vector2(200, -300)
	upgrades["marketing_dynamic_pricing"] = u
	
	# ===== PERSONNEL UPGRADES =====
	
	u = UpgradeData.new()
	u.upgrade_id = "personnel_training_1"
	u.display_name = "Обучение персонала I"
	u.description = "Курсы сервиса. Скорость обслуживания +10%, чаевые +5%"
	u.category = UpgradeCategory.PERSONNEL
	u.tier = UpgradeTier.TIER_1
	u.star_cost = 1
	u.is_root = true
	u.unlocks_ids = ["personnel_training_2", "personnel_manager_hire"]
	u.effects = {"service_speed": 1.1, "tips_multiplier": 1.05}
	u.ui_position = Vector2(-400, 0)
	upgrades["personnel_training_1"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "personnel_manager_hire"
	u.display_name = "Найм менеджера"
	u.description = "Менеджер следит за станцией в ваше отсутствие. Авто-продажи 80% эффективности"
	u.category = UpgradeCategory.PERSONNEL
	u.tier = UpgradeTier.TIER_2
	u.star_cost = 2
	u.prerequisite_ids = ["personnel_training_1"]
	u.unlocks_ids = ["personnel_regional_manager"]
	u.effects = {"offline_earnings": 0.8, "auto_management": true}
	u.ui_position = Vector2(-400, 150)
	upgrades["personnel_manager_hire"] = u
	
	# ===== TECHNOLOGY UPGRADES =====
	
	u = UpgradeData.new()
	u.upgrade_id = "technology_analytics"
	u.display_name = "Бизнес-аналитика"
	u.description = "Детальные отчёты: трафик, пики, цены конкурентов. Видно скрытые параметры"
	u.category = UpgradeCategory.TECHNOLOGY
	u.tier = UpgradeTier.TIER_1
	u.star_cost = 1
	u.is_root = true
	u.unlocks_ids = ["technology_ai_forecast", "technology_battery_tech"]
	u.effects = {"show_competitor_data": true, "show_traffic_heatmap": true}
	u.ui_position = Vector2(0, -450)
	upgrades["technology_analytics"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "technology_battery_tech"
	u.display_name = "Батарейные технологии"
	u.description = "Исследование твердотельных батарей. Открывает доступ к ЭВ зарядкам"
	u.category = UpgradeCategory.TECHNOLOGY
	u.tier = UpgradeTier.TIER_3
	u.star_cost = 3
	u.prerequisite_ids = ["technology_analytics"]
	u.unlocks_ids = ["station_ev_chargers"]
	u.effects = {"unlock_ev_research": true, "tech_prestige": 1.2}
	u.ui_position = Vector2(200, -450)
	upgrades["technology_battery_tech"] = u
	
	# ===== SPECIAL UPGRADES (Unique, expensive) =====
	
	u = UpgradeData.new()
	u.upgrade_id = "special_franchise_model"
	u.display_name = "Франчайзинг"
	u.description = "Модель франчайзинга: покупайте станции за звёзды, а не за деньги"
	u.category = UpgradeCategory.SPECIAL
	u.tier = UpgradeTier.TIER_5
	u.star_cost = 10
	u.cash_cost = 500000
	u.requires_level = 15
	u.prerequisite_ids = ["logistics_own_tankers", "personnel_regional_manager"]
	u.effects = {"buy_stations_with_stars": true, "franchise_fee_income": 0.1}
	u.ui_position = Vector2(0, 600)
	u.branch_color = Color(1.0, 0.8, 0.2)
	upgrades["special_franchise_model"] = u
	
	u = UpgradeData.new()
	u.upgrade_id = "special_monopoly_license"
	u.display_name = "Лицензия монополиста"
	u.description = "Эксклюзивные права на район. Конкуренты не могут открыть новые станции"
	u.category = UpgradeCategory.SPECIAL
	u.tier = UpgradeTier.TIER_5
	u.star_cost = 12
	u.cash_cost = 1000000
	u.requires_level = 20
	u.prerequisite_ids = ["marketing_ai_pricing", "special_franchise_model"]
	u.effects = {"block_competitor_expansion": true, "district_control": true}
	u.ui_position = Vector2(200, 600)
	u.branch_color = Color(1.0, 0.8, 0.2)
	upgrades["special_monopoly_license"] = u
	
	return upgrades