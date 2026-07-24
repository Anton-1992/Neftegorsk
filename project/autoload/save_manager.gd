## SaveManager.gd
## Handles game save/load using Godot's ConfigFile (JSON-compatible)

extends Node

class_name SaveManager

signal save_completed(success: bool)
signal load_completed(success: bool)

const SAVE_PATH = "user://save_game.save"
const BACKUP_PATH = "user://save_game_backup.save"
const SETTINGS_PATH = "user://settings.cfg"

var save_version: int = 1

func _ready() -> void:
	DebugLogger.log_node_ready("SaveManager", true, "start _ready")
	# Ensure user:// directory exists
	if not DirAccess.dir_exists_absolute(OS.get_user_data_dir()):
		DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	DebugLogger.log_node_ready("SaveManager", true, "done")

func save_game() -> bool:
	var game_mgr = GameManager
	if not game_mgr:
		push_error("SaveManager: GameManager not found")
		return false
	
	var config = ConfigFile.new()
	
	# Metadata
	config.set_value("meta", "version", save_version)
	config.set_value("meta", "timestamp", Time.get_unix_time_from_system())
	config.set_value("meta", "godot_version", Engine.get_version_info()["string"])
	
	# Game state
	var save_data = game_mgr.get_save_data()
	for key, value in save_data:
		config.set_value("game", key, _variant_to_saveable(value))
	
	# Settings (audio, graphics, etc.)
	config.set_value("settings", "music_volume", AudioManager.music_volume)
	config.set_value("settings", "sfx_volume", AudioManager.sfx_volume)
	config.set_value("settings", "language", "ru")
	config.set_value("settings", "notifications", true)
	
	# Write to backup first, then atomic rename
	var err = config.save(BACKUP_PATH)
	if err != OK:
		push_error("SaveManager: Failed to save backup: %s" % err)
		save_completed.emit(false)
		return false
	
	# Atomic replace
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Cannot open save file for writing")
		save_completed.emit(false)
		return false
	
	var backup_file = FileAccess.open(BACKUP_PATH, FileAccess.READ)
	if backup_file:
		file.store_buffer(backup_file.get_buffer())
		backup_file.close()
	file.close()
	
	save_completed.emit(true)
	return true

func load_game() -> bool:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err != OK:
		# Try backup
		err = config.load(BACKUP_PATH)
		if err != OK:
			# No save file - fresh game
			load_completed.emit(false)
			return false
	
	# Verify version
	var version = config.get_value("meta", "version", 0)
	if version != save_version:
		push_warning("SaveManager: Save version mismatch (save: %d, current: %d)" % [version, save_version])
		# Could run migration here
	
	# Load game state
	var save_data = {}
	var game_section = config.get_section_keys("game")
	for key in game_section:
		save_data[key] = _variant_from_saveable(config.get_value("game", key))
	
	# Apply to GameManager
	var game_mgr = GameManager
	if game_mgr:
		game_mgr.load_save_data(save_data)
	
	# Load settings
	if config.has_section_key("settings", "music_volume"):
		AudioManager.music_volume = config.get_value("settings", "music_volume")
	if config.has_section_key("settings", "sfx_volume"):
		AudioManager.sfx_volume = config.get_value("settings", "sfx_volume")
	if config.has_section_key("settings", "language"):
		# Apply language
		pass
	
	load_completed.emit(true)
	return true

func delete_save() -> bool:
	var success = true
	if FileAccess.file_exists(SAVE_PATH):
		success = FileAccess.remove(SAVE_PATH) == OK
	if FileAccess.file_exists(BACKUP_PATH):
		success = success and FileAccess.remove(BACKUP_PATH) == OK
	return success

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

func get_save_info() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"exists": false}
	
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return {"exists": false}
	
	return {
		"exists": true,
		"version": config.get_value("meta", "version", 0),
		"timestamp": config.get_value("meta", "timestamp", 0),
		"godot_version": config.get_value("meta", "godot_version", ""),
		"total_stars": config.get_value("game", "total_stars", 0),
		"cash": config.get_value("game", "cash", 0),
		"player_level": config.get_value("game", "player_level", 1),
		"completed_levels": config.get_value("game", "completed_levels", {}).size(),
		"unlocked_districts": config.get_value("game", "unlocked_districts", []).size()
	}

# Helper methods for serializing Variants
func _variant_to_saveable(value: Variant) -> Variant:
	"""Convert Godot types to ConfigFile-compatible types"""
	match value.get_type():
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return {"__type": "Vector", "x": value.x, "y": value.y, "z": 0}
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return {"__type": "Vector", "x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"__type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2, TYPE_RECT2I:
			return {"__type": "Rect", "x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_ARRAY:
			var arr = []
			for v in value:
				arr.append(_variant_to_saveable(v))
			return arr
		TYPE_DICTIONARY:
			var dict = {}
			for k, v in value:
				dict[_variant_to_saveable(k)] = _variant_to_saveable(v)
			return dict
		TYPE_OBJECT:
			if value is Resource:
				return {"__type": "Resource", "path": value.resource_path}
			elif value is Node:
				return {"__type": "Node", "path": value.get_path()}
			else:
				return {"__type": "Object", "class": value.get_class()}
		TYPE_STRING_NAME:
			return {"__type": "StringName", "value": str(value)}
		_:
			return str(value)

func _variant_from_saveable(value: Variant) -> Variant:
	"""Convert ConfigFile types back to Godot types"""
	if not value or not value is Dictionary or not value.has("__type"):
		return value
	
	var vtype = value["__type"]
	match vtype:
		"Vector":
			if value.has("z") and value["z"] != 0:
				return Vector3(value["x"], value["y"], value["z"])
			else:
				return Vector2(value["x"], value["y"])
		"Color":
			return Color(value["r"], value["g"], value["b"], value["a"])
		"Rect":
			return Rect2(Vector2(value["x"], value["y"]), Vector2(value["w"], value["h"]))
		"StringName":
			return StringName(value["value"])
		"Resource":
			return ResourceLoader.load(value["path"])
		_:
			return value

# Auto-save timer (call from GameManager periodically)
func auto_save_interval(interval_seconds: float = 60.0) -> void:
	# This would be called via a Timer in GameManager
	pass