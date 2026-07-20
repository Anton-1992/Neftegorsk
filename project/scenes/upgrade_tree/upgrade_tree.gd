## UpgradeTree.gd
## Homescapes-style upgrade tree with categories, prerequisites, and visual connections

extends Control

@onready var scroll_container = %ScrollContainer
@onready var tree_container = %TreeContainer
@onready var connection_layer = %ConnectionLayer
@onready var upgrade_nodes_layer = %UpgradeNodesLayer
@onready var stars_display = %StarsDisplay
@onready var btn_close = %BtnCloseTree
@onready var category_tabs = %CategoryTabs
@onready var detail_panel = %UpgradeDetailPanel
@onready var detail_icon = %DetailIcon
@onready var detail_name = %DetailName
@onready var detail_desc = %DetailDesc
@onready var detail_star_cost = %DetailStarCost
@onready var detail_cash_cost = %DetailCashCost
@onready var detail_effects = %DetailEffects
@onready var btn_purchase = %BtnPurchase
@onready var btn_close_detail = %BtnCloseDetail
@onready var prereq_toast = %PrerequisiteToast

# Category constants (matching UpgradeData.UpgradeCategory)
const CATEGORIES = [
	{"id": 0, "name": "ЗАПРАВКА", "icon": "⛽"},
	{"id": 1, "name": "ЛОГИСТИКА", "icon": "🚛"},
	{"id": 2, "name": "МАРКЕТИНГ", "icon": "📢"},
	{"id": 3, "name": "ПЕРСОНАЛ", "icon": "👥"},
	{"id": 4, "name": "ТЕХНОЛОГИИ", "icon": "🔬"},
	{"id": 5, "name": "ОСОБОЕ", "icon": "⭐"}
]

var upgrade_nodes: Dictionary = {}  # upgrade_id -> Control (node UI)
var selected_upgrade: StringName = ""
var node_positions: Dictionary = {}  # upgrade_id -> Vector2
var current_category: int = 0

func _ready() -> void:
	_setup_ui()
	_build_tree()
	_connect_signals()
	_update_stars_display()

func _setup_ui() -> void:
	btn_close.pressed.connect(_on_close)
	btn_purchase.pressed.connect(_on_purchase)
	btn_close_detail.pressed.connect(_hide_detail)
	
	# Setup category tabs
	for i, cat in enumerate(CATEGORIES):
		category_tabs.set_tab_title(i, "%s %s" % [cat.icon, cat.name])
	category_tabs.tab_changed.connect(_on_category_changed)

func _connect_signals() -> void:
	GameManager.stars_changed.connect(_update_stars_display)
	GameManager.currency_changed.connect(_update_stars_display)
	GameManager.upgrade_purchased.connect(_on_upgrade_purchased)

func _build_tree() -> void:
	"""Build the visual upgrade tree"""
	# Clear existing
	for child in upgrade_nodes_layer.get_children():
		child.queue_free()
	for child in connection_layer.get_children():
		child.queue_free()
	upgrade_nodes.clear()
	node_positions.clear()
	
	# Get all upgrades organized by category
	var layout = UpgradeManager.get_upgrade_tree_layout()
	
	# Calculate positions for each category (vertical columns)
	var col_width = 320
	var row_height = 180
	var start_x = 100
	var start_y = 100
	
	for cat_idx, cat_info in enumerate(CATEGORIES):
		var cat_id = cat_info.id
		if not layout.has(cat_id):
			continue
		
		var cat_data = layout[cat_id]
		var cat_color = cat_data.color
		var cat_x = start_x + cat_idx * col_width
		
		# Category header
		var header = Label.new()
		header.text = "%s %s" % [cat_info.icon, cat_info.name]
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.position = Vector2(cat_x + col_width * 0.5 - 80, start_y - 60)
		header.custom_minimum_size = Vector2(160, 40)
		header.theme_override_font_sizes/font_size = 20
		header.theme_override_colors/font_color = cat_color
		header.theme_override_colors/font_outline_color = Color(0, 0, 0)
		header.theme_override_constants/outline_size = 2
		upgrade_nodes_layer.add_child(header)
		
		# Sort tiers
		var tiers = cat_data.tiers
		var sorted_tiers = tiers.keys()
		sorted_tiers.sort()
		
		for tier in sorted_tiers:
			var upgrades_in_tier = tiers[tier]
			var tier_y = start_y + (tier - 1) * row_height
			
			# Tier label
			var tier_label = Label.new()
			tier_label.text = "Уровень %d" % tier
			tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tier_label.position = Vector2(cat_x - 20, tier_y + 60)
			tier_label.custom_minimum_size = Vector2(40, 30)
			tier_label.theme_override_font_sizes/font_size = 14
			tier_label.theme_override_colors/font_color = Color(0.5, 0.6, 0.7)
			upgrade_nodes_layer.add_child(tier_label)
			
			# Position upgrades in this tier horizontally
			var count = upgrades_in_tier.size()
			var total_width = (count - 1) * 160 + 120
			var start_x_tier = cat_x + col_width * 0.5 - total_width * 0.5
			
			for i, upgrade in enumerate(upgrades_in_tier):
				var x = start_x_tier + i * 160
				var y = tier_y
				
				var node = _create_upgrade_node(upgrade, Vector2(x, y), cat_color)
				upgrade_nodes[upgrade.upgrade_id] = node
				node_positions[upgrade.upgrade_id] = Vector2(x, y)
				upgrade_nodes_layer.add_child(node)
		
		# Draw connections for this category
		_draw_category_connections(cat_data, cat_x, cat_color)
	
	# Update tree container size
	var max_x = 0
	var max_y = 0
	for pos in node_positions.values():
		max_x = max(max_x, pos.x)
		max_y = max(max_y, pos.y)
	tree_container.custom_minimum_size = Vector2(max_x + 300, max_y + 300)
	
	# Center view
	call_deferred("_center_view")

func _create_upgrade_node(upgrade: UpgradeData, position: Vector2, category_color: Color) -> Control:
	var container = Control.new()
	container.name = "UpgradeNode_%s" % upgrade.upgrade_id
	container.position = position
	container.custom_minimum_size = Vector2(120, 120)
	
	# Main button (hexagon-like shape using Panel)
	var btn = Button.new()
	btn.name = "Btn"
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.custom_minimum_size = Vector2(100, 100)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	
	# Custom drawing for hexagon
	btn.draw_callback = _draw_upgrade_node.bind(btn, upgrade, category_color)
	btn.pressed.connect(_on_node_pressed.bind(upgrade.upgrade_id))
	btn.mouse_entered.connect(_on_node_hover.bind(upgrade.upgrade_id, true))
	btn.mouse_exited.connect(_on_node_hover.bind(upgrade.upgrade_id, false))
	container.add_child(btn)
	
	# Name label
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	name_label.offset_top = 105
	name_label.offset_bottom = 0
	name_label.offset_left = -10
	name_label.offset_right = 10
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = upgrade.display_name
	name_label.theme_override_font_sizes/font_size = 12
	name_label.theme_override_colors/font_color = Color(1, 1, 1)
	name_label.theme_override_colors/font_outline_color = Color(0, 0, 0)
	name_label.theme_override_constants/outline_size = 1
	container.add_child(name_label)
	
	# Tier badge
	var tier_badge = Label.new()
	tier_badge.name = "TierBadge"
	tier_badge.anchors_preset = Control.PRESET_TOP_RIGHT
	tier_badge.offset_left = -30
	tier_badge.offset_top = -10
	tier_badge.custom_minimum_size = Vector2(24, 24)
	tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_badge.text = "T%d" % upgrade.tier
	tier_badge.theme_override_font_sizes/font_size = 10
	tier_badge.theme_override_colors/font_color = Color(1, 1, 1)
	tier_badge.add_theme_stylebox_override("normal", _create_tier_stylebox(upgrade.tier, category_color))
	container.add_child(tier_badge)
	
	# Star cost
	var star_label = Label.new()
	star_label.name = "StarCost"
	star_label.anchors_preset = Control.PRESET_BOTTOM_LEFT
	star_label.offset_left = -10
	star_label.offset_bottom = -5
	star_label.custom_minimum_size = Vector2(30, 20)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	star_label.text = "★%d" % upgrade.star_cost
	star_label.theme_override_font_sizes/font_size = 12
	star_label.theme_override_colors/font_color = Color(1, 0.9, 0.2)
	star_label.theme_override_colors/font_outline_color = Color(0, 0, 0)
	star_label.theme_override_constants/outline_size = 1
	container.add_child(star_label)
	
	return container

func _draw_upgrade_node(btn: Button, upgrade: UpgradeData, category_color: Color) -> void:
	var rect = Rect2(Vector2(0, 0), btn.custom_minimum_size)
	var center = rect.size * 0.5
	var radius = 45
	
	var owned = GameManager.has_upgrade(upgrade.upgrade_id)
	var can_buy = upgrade.can_purchase(GameManager.owned_upgrades, GameManager.player_level, GameManager.total_stars, GameManager.cash)
	var hovered = btn.get_meta("hovered", false)
	
	# Background
	var bg_color
	if owned:
		bg_color = Color(0.2, 0.6, 0.2)
	elif can_buy:
		bg_color = category_color * Color(1, 1, 1, 0.8)
	else:
		bg_color = Color(0.2, 0.2, 0.25)
	
	# Draw hexagon
	var points = []
	for i in range(6):
		var angle = PI / 3 * i - PI / 6
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	btn.draw_polygon(points, [bg_color])
	
	# Border
	var border_color = Color(1, 0.9, 0.3) if hovered else (Color(0.4, 1, 0.4) if owned else category_color)
	if not owned and not can_buy:
		border_color = Color(0.4, 0.4, 0.5)
	btn.draw_polygon(points, [], [border_color], false, 3)
	
	# Icon/text in center
	var font = btn.get_theme_font("font", "Label")
	var icon_text = _get_category_icon(upgrade.category)
	btn.draw_string(font, center + Vector2(-12, 6), icon_text, HORIZONTAL_ALIGNMENT.CENTER, -1, 36)
	
	# Lock icon if not available and not owned
	if not owned and not can_buy:
		btn.draw_string(font, center + Vector2(-10, 20), "🔒", HORIZONTAL_ALIGNMENT.CENTER, -1, 24)
	
	# Checkmark if owned
	if owned:
		btn.draw_string(font, center + Vector2(-8, 18), "✓", HORIZONTAL_ALIGNMENT.CENTER, -1, 28)

func _get_category_icon(category: int) -> String:
	match category:
		UpgradeData.UpgradeCategory.STATION: return "⛽"
		UpgradeData.UpgradeCategory.LOGISTICS: return "🚛"
		UpgradeData.UpgradeCategory.MARKETING: return "📢"
		UpgradeData.UpgradeCategory.PERSONNEL: return "👥"
		UpgradeData.UpgradeCategory.TECHNOLOGY: return "🔬"
		UpgradeData.UpgradeCategory.SPECIAL: return "⭐"
		_: return "⬆"

func _create_tier_stylebox(tier: int, color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = Color(1, 1, 1, 0.3)
	return sb

func _draw_category_connections(cat_data: Dictionary, cat_x: float, color: Color) -> void:
	"""Draw connection lines between upgrade nodes"""
	var tiers = cat_data.tiers
	var sorted_tiers = tiers.keys()
	sorted_tiers.sort()
	
	for tier in sorted_tiers:
		if tier == 1:
			continue  # No connections to roots
		
		var upgrades = tiers[tier]
		for upgrade in upgrades:
			for prereq_id in upgrade.prerequisite_ids:
				if node_positions.has(prereq_id) and node_positions.has(upgrade.upgrade_id):
					var from_pos = node_positions[prereq_id] + Vector2(60, 60)  # Center of hex
					var to_pos = node_positions[upgrade.upgrade_id] + Vector2(60, 60)
					
					# Draw curved line
					var line = Line2D.new()
					line.points = [from_pos, to_pos]
					line.default_color = color * Color(1, 1, 1, 0.5)
					line.width = 3
					line.texture_mode = Line2D.TEXTURE_MODE_TILE
					connection_layer.add_child(line)
					
					# Arrow head
					var arrow = Polygon2D.new()
					var dir = (to_pos - from_pos).normalized()
					var perp = Vector2(-dir.y, dir.x) * 8
					var tip = to_pos - dir * 15
					arrow.polygon = [tip, tip + dir * 10 + perp, tip + dir * 10 - perp]
					arrow.color = color * Color(1, 1, 1, 0.5)
					connection_layer.add_child(arrow)

func _on_node_pressed(upgrade_id: StringName) -> void:
	var upgrade = UpgradeManager.get_upgrade(upgrade_id)
	if not upgrade:
		return
	
	var owned = GameManager.has_upgrade(upgrade_id)
	var can_buy = upgrade.can_purchase(GameManager.owned_upgrades, GameManager.player_level, GameManager.total_stars, GameManager.cash)
	
	if owned:
		AudioManager.sfx_button_click()
		_show_detail(upgrade)
	elif can_buy:
		AudioManager.sfx_button_click()
		_show_detail(upgrade)
	else:
		AudioManager.sfx_error()
		_show_prerequisite_toast(upgrade)

func _on_node_hover(upgrade_id: StringName, entered: bool) -> void:
	var node = upgrade_nodes.get(upgrade_id)
	if node:
		var btn = node.get_node("Btn")
		if btn:
			btn.set_meta("hovered", entered)
			btn.queue_redraw()

func _show_detail(upgrade: UpgradeData) -> void:
	selected_upgrade = upgrade.upgrade_id
	
	detail_name.text = upgrade.display_name
	detail_desc.text = upgrade.description
	detail_star_cost.text = "★ %d" % upgrade.star_cost
	detail_cash_cost.text = "%s ₽" % _format_number(upgrade.cash_cost) if upgrade.cash_cost > 0 else "Бесплатно"
	
	# Effects
	var effects_text = "Эффекты:\n"
	for key, value in upgrade.effects:
		var desc = _get_effect_description(key, value)
		effects_text += "• %s\n" % desc
	detail_effects.text = effects_text
	
	# Purchase button
	var owned = GameManager.has_upgrade(upgrade.upgrade_id)
	var can_buy = upgrade.can_purchase(GameManager.owned_upgrades, GameManager.player_level, GameManager.total_stars, GameManager.cash)
	
	btn_purchase.disabled = owned or not can_buy
	if owned:
		btn_purchase.text = "КУПЛЕНО"
	elif can_buy:
		btn_purchase.text = "ПРИОБРЕСТИ (★%d)" % upgrade.star_cost
	else:
		btn_purchase.text = "НЕДОСТУПНО"
	
	detail_panel.visible = true
	detail_panel.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(detail_panel, "modulate:a", 1.0, 0.2)

func _hide_detail() -> void:
	var tween = create_tween()
	tween.tween_property(detail_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(detail_panel.hide.bind)

func _show_prerequisite_toast(upgrade: UpgradeData) -> void:
	var missing = []
	for prereq in upgrade.prerequisite_ids:
		if not GameManager.has_upgrade(prereq):
			var p_upg = UpgradeManager.get_upgrade(prereq)
			if p_upg:
				missing.append(p_upg.display_name)
	
	var msg = "Требуется: %s" % ", ".join(missing)
	prereq_toast.text = msg
	prereq_toast.visible = true
	prereq_toast.modulate = Color(1, 1, 1, 1)
	
	var tween = create_tween()
	tween.tween_property(prereq_toast, "modulate:a", 0.0, 2.0).set_delay(1.5)
	tween.tween_callback(prereq_toast.hide.bind)

func _on_purchase() -> void:
	if selected_upgrade == "":
		return
	
	if GameManager.purchase_upgrade(selected_upgrade):
		AudioManager.sfx_upgrade()
		_hide_detail()
		_refresh_tree()
	else:
		AudioManager.sfx_error()

func _on_upgrade_purchased(upgrade_id: StringName) -> void:
	_refresh_tree()

func _refresh_tree() -> void:
	"""Redraw all nodes to reflect new state"""
	for upgrade_id, node in upgrade_nodes:
		var btn = node.get_node("Btn")
		if btn:
			btn.queue_redraw()
	
	# Update detail if open
	if detail_panel.visible and selected_upgrade != "":
		var upgrade = UpgradeManager.get_upgrade(selected_upgrade)
		if upgrade:
			_show_detail(upgrade)

func _on_category_changed(tab_idx: int) -> void:
	current_category = tab_idx
	# Scroll to category
	var cat_x = 100 + tab_idx * 320
	scroll_container.scroll_horizontal = max(0, cat_x - scroll_container.size.x * 0.5)

func _center_view() -> void:
	scroll_container.scroll_horizontal = max(0, tree_container.custom_minimum_size.x * 0.5 - scroll_container.size.x * 0.5)

func _on_close() -> void:
	AudioManager.sfx_button_click()
	GameManager.go_to_main_menu()

func _update_stars_display() -> void:
	stars_display.text = "★ %d  |  %s ₽" % [GameManager.total_stars, _format_number(GameManager.cash)]

func _get_effect_description(key: String, value: Variant) -> String:
	var descriptions = {
		"storage_capacity": "Вместимость баков ×%.0f" % (value * 100),
		"refuel_speed": "Скорость заправки ×%.0f" % (value * 100),
		"customer_patience": "Терпение клиентов ×%.0f" % (value * 100),
		"price_change_cooldown": "Кулдаун смены цены ×%.0f" % (value * 100),
		"loyalty_loss_on_price_change": "Потеря лояльности ×%.0f" % (value * 100),
		"delivery_frequency": "Частота поставок ×%.0f" % (value * 100),
		"simultaneous_vehicles": "Одновременная заправка: %d авто" % value,
		"station_throughput": "Пропускная способность ×%.0f" % (value * 100),
		"vip_multiplier": "Прибыль от VIP ×%.0f" % (value * 100),
		"attract_vip_chance": "Шанс VIP клиентов: %.0f%%" % (value * 100),
		"ev_traffic_share": "Доля электромобилей: %.0f%%" % (value * 100),
		"ev_profit_margin": "Маржа ЭВ: ×%.0f" % (value * 100),
		"auto_order_threshold": "Автозаказ при < %.0f%%" % (value * 100),
		"stockout_penalty": "Штраф за дефицит: убран",
		"purchase_price_multiplier": "Закупочная цена ×%.0f" % (value * 100),
		"min_order_volume": "Мин. объём заказа ×%.0f" % (value * 100),
		"delivery_cost_multiplier": "Стоимость доставки ×%.0f" % (value * 100),
		"delivery_reliability": "Надёжность доставки: 100%%",
		"district_traffic_bonus": "Трафик в районе ×%.0f" % (value * 100),
		"brand_awareness": "Узнаваемость бренда ×%.0f" % (value * 100),
		"customer_retention": "Удержание клиентов ×%.0f" % (value * 100),
		"repeat_visit_chance": "Шанс возврата: %.0f%%" % (value * 100),
		"auto_price_optimization": "Авто-оптимизация цен: ВКЛ",
		"margin_boost": "Маржа ×%.0f" % (value * 100),
		"service_speed": "Скорость сервиса ×%.0f" % (value * 100),
		"tips_multiplier": "Чаевые ×%.0f" % (value * 100),
		"offline_earnings": "Оффлайн-доход: %.0f%%" % (value * 100),
		"auto_management": "Авто-управление: ВКЛ",
		"show_competitor_data": "Данные конкурентов: ВИДНЫ",
		"show_traffic_heatmap": "Теплокарта трафика: ВКЛ",
		"unlock_ev_research": "Исследование ЭВ: ОТКРЫТО",
		"tech_prestige": "Технологический престиж ×%.0f" % (value * 100),
		"buy_stations_with_stars": "Покупка станций за звёзды: ВКЛ",
		"franchise_fee_income": "Франчайзи: %.0f%% от выручки" % (value * 100),
		"block_competitor_expansion": "Блок экспансии конкурентов: ВКЛ",
		"district_control": "Контроль района: ВКЛ"
	}
	return descriptions.get(key, "%s: %s" % [key, value])

func _format_number(num: int) -> String:
	var str = str(num)
	var result = ""
	for i, ch in enumerate(str.reversed()):
		if i > 0 and i % 3 == 0:
			result = " " + result
		result = ch + result
	return result