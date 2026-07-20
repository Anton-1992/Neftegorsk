## OpponentArchetype.gd
## Defines AI opponent personalities and behaviors

class_name OpponentArchetype
extends Resource

@export_group("Identity")
@export var archetype_id: StringName = ""
@export var display_name: String = "Противник"
@export var description: String = ""
@export var portrait_path: String = ""  # UI portrait

@export_group("Personality Traits (0.0 - 2.0)")
@export_range(0.0, 2.0) var aggression: float = 1.0        # How often attacks/undercuts
@export_range(0.0, 2.0) var expansion_drive: float = 1.0   # How fast buys new stations
@export_range(0.0, 2.0) var price_sensitivity: float = 1.0 # How much reacts to player prices
@export_range(0.0, 2.0) var risk_tolerance: float = 1.0    # Willingness to invest in upgrades
@export_range(0.0, 2.0) var loyalty: float = 1.0           # Harder to buy out their stations

@export_group("Economic Behavior")
@export var base_price_modifier: float = 1.0       # Their default fuel price vs market
@export var price_change_frequency: float = 0.5     # How often they change prices (per game hour)
@export var min_profit_margin: float = 0.15         # Won't sell below this margin
@export var reinvestment_rate: float = 0.3          # Profit % reinvested in upgrades

@export_group("Strategic Preferences")
@export var prefers_high_traffic: bool = true       # Targets busy intersections
@export var prefers_clustering: bool = false        # Groups stations together
@export var defensive_upgrades: bool = true         # Upgrades owned stations vs expanding
@export var sabotages_player: bool = false          # Can use "dirty tricks" (higher levels)

@export_group("Dialogue & Presentation")
@export var taunt_lines: Array[String] = []         # Lines when beating player
@export var defeat_lines: Array[String] = []        # Lines when bought out
@export var negotiation_style: int = 0              # 0=stubborn, 1=fair, 2=desperate

@export_group("Unlock")
@export var unlock_district: StringName = ""        # First appears in this district
@export var min_level: int = 1                      # Minimum level to appear

func get_behavior_weights() -> Dictionary:
	"""Returns weights for AI decision making"""
	return {
		"buy_station": expansion_drive * 10,
		"upgrade_station": risk_tolerance * 5 * (1.0 if defensive_upgrades else 0.5),
		"lower_price": aggression * 8 * price_sensitivity,
		"raise_price": (2.0 - aggression) * 5,
		"sabotage": 3.0 if sabotages_player else 0.0
	}

func calculate_buyout_multiplier(player_reputation: float) -> float:
	"""How much extra they demand to sell. Loyalty + reputation factor."""
	var base = 1.0 + (loyalty - 1.0) * 0.5
	var rep_factor = 1.0 - player_reputation * 0.2  # Better reputation = easier buyout
	return base * rep_factor

static func create_archetypes() -> Dictionary:
	"""Factory method for default archetypes"""
	var archetypes = {}
	
	# The Shark - aggressive expansionist
	var shark = OpponentArchetype.new()
	shark.archetype_id = "shark"
	shark.display_name = "Акула"
	shark.description = "Агрессивный экспансионист. Быстро захватывает выгодные места, демпингует цены."
	shark.aggression = 1.8
	shark.expansion_drive = 1.6
	shark.price_sensitivity = 1.4
	shark.risk_tolerance = 1.5
	shark.loyalty = 0.7
	shark.base_price_modifier = 0.9
	shark.price_change_frequency = 0.8
	shark.min_profit_margin = 0.10
	shark.reinvestment_rate = 0.4
	shark.prefers_high_traffic = true
	shark.prefers_clustering = false
	shark.sabotages_player = true
	shark.taunt_lines = ["Твой бизнес горит!", "Я съем твою долю на завтрак!"]
	shark.defeat_lines = ["Невозможно...", "Это не конец!"]
	shark.negotiation_style = 0
	shark.unlock_district = "business_center"
	shark.min_level = 3
	archetypes["shark"] = shark
	
	# The Miser - economical, defensive
	var miser = OpponentArchetype.new()
	miser.archetype_id = "miser"
	miser.display_name = "Скупой"
	miser.description = "Экономный защитник. Держится за свои станции, редко расширяется, но продаёт дорого."
	miser.aggression = 0.4
	miser.expansion_drive = 0.5
	miser.price_sensitivity = 0.6
	miser.risk_tolerance = 0.3
	miser.loyalty = 1.8
	miser.base_price_modifier = 1.15
	miser.price_change_frequency = 0.2
	miser.min_profit_margin = 0.25
	miser.reinvestment_rate = 0.2
	miser.prefers_high_traffic = false
	miser.prefers_clustering = true
	miser.defensive_upgrades = true
	miser.taunt_lines = ["Каждая копейка на счету.", "Ты тратишь впустую."]
	miser.defeat_lines = ["Нечестно...", "Мой расчёт был точным."]
	miser.negotiation_style = 0
	miser.unlock_district = "residential"
	miser.min_level = 1
	archetypes["miser"] = miser
	
	# The Opportunist - adaptive, reactive
	var opportunist = OpponentArchetype.new()
	opportunist.archetype_id = "opportunist"
	opportunist.display_name = "Опортунист"
	opportunist.description = "Адаптивный игрок. Реагирует на ваши действия, копирует успешные стратегии."
	opportunist.aggression = 1.0
	opportunist.expansion_drive = 1.0
	opportunist.price_sensitivity = 1.8
	opportunist.risk_tolerance = 1.0
	opportunist.loyalty = 1.0
	opportunist.base_price_modifier = 1.0
	opportunist.price_change_frequency = 1.0
	opportunist.min_profit_margin = 0.15
	opportunist.reinvestment_rate = 0.35
	opportunist.prefers_high_traffic = true
	opportunist.prefers_clustering = false
	opportunist.sabotages_player = false
	opportunist.taunt_lines = ["Хороший ход. Повторю.", "Ты научил меня."]
	opportunist.defeat_lines = ["Честная игра.", "Вернусь за реваншем."]
	opportunist.negotiation_style = 1
	opportunist.unlock_district = "historic"
	opportunist.min_level = 2
	archetypes["opportunist"] = opportunist
	
	# The Tycoon - late game, wealthy, buys everything
	var tycoon = OpponentArchetype.new()
	tycoon.archetype_id = "tycoon"
	tycoon.display_name = "Магнат"
	tycoon.description = "Богатый магнат. Огромный капитал, покупает лучшие локации, не боится риска."
	tycoon.aggression = 1.2
	tycoon.expansion_drive = 1.8
	tycoon.price_sensitivity = 0.8
	tycoon.risk_tolerance = 1.8
	tycoon.loyalty = 1.5
	tycoon.base_price_modifier = 0.95
	tycoon.price_change_frequency = 0.4
	tycoon.min_profit_margin = 0.12
	tycoon.reinvestment_rate = 0.5
	tycoon.prefers_high_traffic = true
	tycoon.prefers_clustering = false
	tycoon.defensive_upgrades = true
	tycoon.sabotages_player = true
	tycoon.taunt_lines = ["Деньги решают всё.", "Твой бизнес — моё хобби."]
	tycoon.defeat_lines = ["Интересный опыт.", "До встречи на вершине."]
	tycoon.negotiation_style = 2
	tycoon.unlock_district = "industrial"
	tycoon.min_level = 8
	archetypes["tycoon"] = tycoon
	
	# The Local - loyal to district, defensive
	var local = OpponentArchetype.new()
	local.archetype_id = "local"
	local.display_name = "Местный"
	local.description = "Местный البارон. Хорошо знает район, лоялен клиентам, яростно защищает свою территорию."
	local.aggression = 0.8
	local.expansion_drive = 0.7
	local.price_sensitivity = 1.0
	local.risk_tolerance = 0.6
	local.loyalty = 2.0
	local.base_price_modifier = 1.05
	local.price_change_frequency = 0.3
	local.min_profit_margin = 0.18
	local.reinvestment_rate = 0.25
	local.prefers_high_traffic = false
	local.prefers_clustering = true
	local.defensive_upgrades = true
	local.sabotages_player = false
	local.taunt_lines = ["Здесь я хозяин.", "Мои клиенты не уйдут."]
	local.defeat_lines = ["Район потерял отца.", "Хорошо играл, парень."]
	local.negotiation_style = 1
	local.unlock_district = "suburban"
	local.min_level = 4
	archetypes["local"] = local
	
	# The Green - eco-focused, premium pricing
	var green = OpponentArchetype.new()
	green.archetype_id = "green"
	green.display_name = "Эколог"
	green.description = "Эко-энтузиаст. Продаёт премиальное 'зелёное' топливо дороже, но у него лояльная аудитория."
	green.aggression = 0.6
	green.expansion_drive = 0.8
	green.price_sensitivity = 0.5
	green.risk_tolerance = 1.2
	green.loyalty = 1.3
	green.base_price_modifier = 1.25
	green.price_change_frequency = 0.25
	green.min_profit_margin = 0.30
	green.reinvestment_rate = 0.4
	green.prefers_high_traffic = false
	green.prefers_clustering = false
	green.defensive_upgrades = true
	green.sabotages_player = false
	green.taunt_lines = ["Будущее за чистой энергией.", "Твоё топливо отравляет город."]
	green.defeat_lines = ["Надеюсь, ты тоже станешь зеленее.", "Победа природы."]
	green.negotiation_style = 1
	green.unlock_district = "waterfront"
	green.min_level = 6
	archetypes["green"] = green
	
	return archetypes