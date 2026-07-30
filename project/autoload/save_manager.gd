## SaveManager.gd — v25: safe autoload access, no class_name
extends Node

signal save_completed(success: bool)
signal load_completed(success: bool)

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(OS.get_user_data_dir()):
		DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())

func save_game() -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return false
	gs.save_game()
	save_completed.emit(true)
	return true

func load_game() -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("_load_save"):
		gs._load_save()
	load_completed.emit(true)
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists("user://neftegorsk_save.json")
