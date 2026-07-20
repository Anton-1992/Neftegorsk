## StationNode.gd
## Reusable station node with visual variants for player and opponents

extends Node2D
class_name StationNode

signal station_clicked(station_id: int, is_player: bool)
signal station_hovered(station_id: int, is_player: bool, entered: bool)

@export var station_id: int = 0
@export var is_player_station: bool = false
@export var station_type: String = "standard"  # standard, premium, ev, shark, miser, local, green, tycoon, opportunist
@export var owner_archetype: StringName = ""

@onready var sprite = %Sprite
@onready var collision = %CollisionShape2D
@onready var selection_ring = %SelectionRing
@onready var range_indicator = %RangeIndicator
@onready var name_label = %NameLabel
@onready var price_label = %PriceLabel
@onready var fuel_bar = %FuelBar
@onready var level_badge = %LevelBadge
@onready var owner_icon = %OwnerIcon
@onready var button = %Button

# Texture cache
var texture_cache: Dictionary = {}
var current_frame: int = 0

func _ready() -> void:
	_setup_textures()
	_apply_station_type(station_type)
	_connect_signals()
	
	# Scale sprite to fit collision
	sprite.scale = Vector2(0.8, 0.8)
	
	# Animation for idle (subtle breathing)
	var anim = Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_PINGPONG
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "Sprite:scale:x")
	anim.track_insert_key(track, 0.0, 0.8)
	anim.track_insert_key(track, 1.0, 0.82)
	anim.track_insert_key(track, 2.0, 0.8)
	track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, "Sprite:scale:y")
	anim.track_insert_key(track, 0.0, 0.8)
	anim.track_insert_key(track, 1.0, 0.82)
	anim.track_insert_key(track, 2.0, 0.8)
	
	var player = AnimationPlayer.new()
	player.add_animation("idle", anim)
	player.play("idle")
	add_child(player)

func _setup_textures() -> void:
	"""Load all station textures"""
	var paths = {
		"standard": "res://assets/ui/station_standard.png",
		"premium": "res://assets/ui/station_premium.png",
		"ev": "res://assets/ui/station_ev.png",
		"shark": "res://assets/ui/station_shark.png",
		"miser": "res://assets/ui/station_miser.png",
		"local": "res://assets/ui/station_local.png",
		"green": "res://assets/ui/station_green.png",
		"tycoon": "res://assets/ui/station_tycoon.png",
		"opportunist": "res://assets/ui/station_opportunist.svg",
	}
	
	for key, path in paths:
		var tex = ResourceLoader.load(path)
		if tex:
			texture_cache[key] = tex
		else:
			push_warning("Failed to load station texture: " + path)

func _apply_station_type(type_name: String) -> void:
	station_type = type_name
	
	var tex = texture_cache.get(type_name)
	if tex:
		sprite.texture = tex
	else:
		# Fallback to standard
		sprite.texture = texture_cache.get("standard")
	
	# Set name based on type
	var names = {
		"standard": "МОЯ ЗАПРАВКА" if is_player_station else "СТАНДАРТ",
		"premium": "ПРЕМИУМ",
		"ev": "ЭЛЕКТРОЗАРЯДКА",
		"shark": "АКУЛА",
		"miser": "ЭКОНОМ",
		"local": "МЕСТНАЯ",
		"green": "ЭКО",
		"tycoon": "ИМПЕРИЯ",
		"opportunist": "ОПОРТУНИСТ",
	}
	name_label.text = names.get(type_name, "ЗАПРАВКА")
	
	# Color code name label
	if is_player_station:
		name_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	elif owner_archetype != "":
		var colors = {
			"shark": Color(1, 0.4, 0.4),
			"miser": Color(1, 0.8, 0.3),
			"opportunist": Color(0.6, 0.6, 1),
			"tycoon": Color(1, 0.9, 0.3),
			"local": Color(0.4, 0.8, 1),
			"green": Color(0.4, 1, 0.5),
		}
		name_label.add_theme_color_override("font_color", colors.get(owner_archetype, Color(1, 1, 1)))

func _connect_signals() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)

func _on_button_pressed() -> void:
	station_clicked.emit(station_id, is_player_station)
	if is_player_station:
		AudioManager.sfx_button_click()
	else:
		AudioManager.sfx_button_click()

func _on_mouse_entered() -> void:
	selection_ring.visible = true
	station_hovered.emit(station_id, is_player_station, true)

func _on_mouse_exited() -> void:
	selection_ring.visible = false
	station_hovered.emit(station_id, is_player_station, false)

func update_display(price: float, fuel: int, capacity: int, level: int = 1) -> void:
	price_label.text = "%.2f ₽/л" % price
	fuel_bar.max_value = capacity
	fuel_bar.value = fuel
	level_badge.text = "Ур.%d" % level
	
	# Color fuel bar based on level
	var ratio = fuel / capacity if capacity > 0 else 0
	if ratio > 0.5:
		fuel_bar.add_theme_color_override("fill_color", Color(0.4, 1, 0.4))
	elif ratio > 0.2:
		fuel_bar.add_theme_color_override("fill_color", Color(1, 0.9, 0.2))
	else:
		fuel_bar.add_theme_color_override("fill_color", Color(1, 0.4, 0.4))

func set_selected(selected: bool) -> void:
	selection_ring.visible = selected
	if selected:
		# Pulse animation
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(selection_ring, "modulate:a", 0.5, 0.8)
		tween.tween_property(selection_ring, "modulate:a", 1.0, 0.8)
	else:
		# Stop any tween
		for child in get_children():
			if child is Tween:
				child.kill()

func show_range(show: bool) -> void:
	range_indicator.disabled = not show

func set_owner_archetype(archetype: StringName) -> void:
	owner_archetype = archetype
	_apply_station_type(station_type)

func play_fuel_animation() -> void:
	"""Play a quick 'fueling' animation"""
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 0.5, 1), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	AudioManager.sfx_fuel_pump()

func play_purchase_animation() -> void:
	"""Play station purchase animation"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)
	AudioManager.sfx_station_buy()

func play_upgrade_animation() -> void:
	"""Play upgrade animation"""
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 1, 0.5, 1), 0.15)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.15)
	AudioManager.sfx_upgrade()