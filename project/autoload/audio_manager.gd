## AudioManager.gd
## Centralized audio management for music, SFX, and voice

extends Node

class_name AudioManager

# Volume settings (0.0 - 1.0)
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var master_volume: float = 1.0

# Audio players
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_channels: int = 8
var current_sfx_index: int = 0

# Music tracks
var music_tracks: Dictionary = {}
var current_music: String = ""
var music_fade_time: float = 2.0

# SFX library
var sfx_library: Dictionary = {}

func _ready() -> void:
	_setup_players()
	_load_audio_resources()

func _setup_players() -> void:
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	# Ambient player (looping background)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	# SFX pool
	for i in range(max_sfx_channels):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

func _load_audio_resources() -> void:
	# Define music tracks (paths to .ogg/.mp3 files)
	music_tracks = {
		"main_menu": "res://assets/audio/music/main_menu.ogg",
		"district_map": "res://assets/audio/music/district_map.ogg",
		"business_center": "res://assets/audio/music/business_center.ogg",
		"historic": "res://assets/audio/music/historic.ogg",
		"residential": "res://assets/audio/music/residential.ogg",
		"industrial": "res://assets/audio/music/industrial.ogg",
		"waterfront": "res://assets/audio/music/waterfront.ogg",
		"suburban": "res://assets/audio/music/suburban.ogg",
		"victory": "res://assets/audio/music/victory.ogg",
		"defeat": "res://assets/audio/music/defeat.ogg",
		"upgrade_tree": "res://assets/audio/music/upgrade_tree.ogg"
	}
	
	# Define SFX
	sfx_library = {
		"button_click": "res://assets/audio/sfx/button_click.ogg",
		"button_hover": "res://assets/audio/sfx/button_hover.ogg",
		"cash_register": "res://assets/audio/sfx/cash_register.ogg",
		"fuel_pump": "res://assets/audio/sfx/fuel_pump.ogg",
		"level_up": "res://assets/audio/sfx/level_up.ogg",
		"star_collect": "res://assets/audio/sfx/star_collect.ogg",
		"upgrade_buy": "res://assets/audio/sfx/upgrade_buy.ogg",
		"station_buy": "res://assets/audio/sfx/station_buy.ogg",
		"price_change": "res://assets/audio/sfx/price_change.ogg",
		"notification": "res://assets/audio/sfx/notification.ogg",
		"error": "res://assets/audio/sfx/error.ogg",
		"ambient_city": "res://assets/audio/ambient/city.ogg",
		"ambient_industrial": "res://assets/audio/ambient/industrial.ogg",
		"ambient_waterfront": "res://assets/audio/ambient/waterfront.ogg",
		"ambient_suburban": "res://assets/audio/sfx/ambient_suburban.ogg"
	}

# Music control
func play_music(track_key: String, fade: bool = true) -> void:
	if not music_tracks.has(track_key):
		push_warning("AudioManager: Music track not found: %s" % track_key)
		return
	
	var path = music_tracks[track_key]
	var stream = ResourceLoader.load(path)
	if not stream:
		push_warning("AudioManager: Failed to load music: %s" % path)
		return
	
	if fade and music_player.playing and current_music != "":
		# Crossfade
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, music_fade_time / 2.0)
		tween.tween_callback(_switch_music.bind(stream, track_key))
		tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), music_fade_time / 2.0)
	else:
		_switch_music(stream, track_key)

func _switch_music(stream: AudioStream, track_key: String) -> void:
	music_player.stream = stream
	music_player.play()
	current_music = track_key
	music_player.volume_db = linear_to_db(music_volume)

func stop_music(fade: bool = true) -> void:
	if fade:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, music_fade_time)
		tween.tween_callback(music_player.stop.bind())
	else:
		music_player.stop()
	current_music = ""

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)

# Ambient control
func play_ambient(ambient_key: String, fade: bool = true) -> void:
	if not sfx_library.has(ambient_key):
		return
	
	var path = sfx_library[ambient_key]
	var stream = ResourceLoader.load(path)
	if not stream:
		return
	
	if fade and ambient_player.playing:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(_switch_ambient.bind(stream))
		tween.tween_property(ambient_player, "volume_db", linear_to_db(sfx_volume * 0.5), 1.0)
	else:
		_switch_ambient(stream)

func _switch_ambient(stream: AudioStream) -> void:
	ambient_player.stream = stream
	ambient_player.play()
	ambient_player.volume_db = linear_to_db(sfx_volume * 0.5)

func stop_ambient(fade: bool = true) -> void:
	if fade:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -80.0, 1.0)
		tween.tween_callback(ambient_player.stop.bind())
	else:
		ambient_player.stop()

# SFX control
func play_sfx(sfx_key: String, pitch_variance: float = 0.0, volume_mult: float = 1.0) -> void:
	if not sfx_library.has(sfx_key):
		return
	
	var path = sfx_library[sfx_key]
	var stream = ResourceLoader.load(path)
	if not stream:
		return
	
	var player = sfx_players[current_sfx_index]
	current_sfx_index = (current_sfx_index + 1) % max_sfx_channels
	
	player.stream = stream
	player.pitch_scale = 1.0 + (randf() - 0.5) * pitch_variance
	player.volume_db = linear_to_db(sfx_volume * master_volume * volume_mult)
	player.play()

func play_sfx_at_position(sfx_key: String, position: Vector2, pitch_variance: float = 0.0) -> void:
	# For 2D positional audio, would use AudioStreamPlayer2D
	# Simplified: just play with volume based on distance to camera
	play_sfx(sfx_key, pitch_variance)

func stop_all_sfx() -> void:
	for player in sfx_players:
		player.stop()

# Volume control
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	set_music_volume(music_volume)
	# SFX volumes updated on next play

func get_volume_linear(bus: String) -> float:
	var db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	return db_to_linear(db)

func set_volume_linear(bus: String, volume: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(volume))

# Utility
static func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log10(linear)

static func db_to_linear(db: float) -> float:
	return pow(10.0, db / 20.0)

# District-specific ambient
func play_district_ambient(district_id: StringName) -> void:
	match district_id:
		"business_center", "industrial", "port":
			play_ambient("ambient_industrial")
		"waterfront", "tourist":
			play_ambient("ambient_waterfront")
		"suburban", "residential", "university":
			play_ambient("ambient_suburban")
		"historic", "airport":
			play_ambient("ambient_city")
		_:
			play_ambient("ambient_city")

# Gameplay SFX shortcuts
func sfx_button_click() -> void: play_sfx("button_click")
func sfx_button_hover() -> void: play_sfx("button_hover", 0.1, 0.5)
func sfx_cash() -> void: play_sfx("cash_register", 0.1)
func sfx_fuel_pump() -> void: play_sfx("fuel_pump", 0.2, 0.7)
func sfx_level_up() -> void: play_sfx("level_up")
func sfx_star() -> void: play_sfx("star_collect")
func sfx_upgrade() -> void: play_sfx("upgrade_buy")
func sfx_station_buy() -> void: play_sfx("station_buy")
func sfx_price_change() -> void: play_sfx("price_change")
func sfx_notification() -> void: play_sfx("notification")
func sfx_error() -> void: play_sfx("error")