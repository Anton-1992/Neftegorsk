## DebugLogger.gd
## Writes debug messages to a file AND shows them on screen
## Log file: user://debug_log.txt
## Uses CanvasLayer to show messages BEFORE any scene loads

extends Node

var log_file_path: String = "user://debug_log.txt"
var enabled: bool = true
var debug_label: Label = null
var debug_canvas: CanvasLayer = null
var last_message: String = "STARTING..."

func _ready() -> void:
	# Create log file with WRITE mode (creates new file)
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		var timestamp = Time.get_datetime_string_from_system()
		file.store_line("=== NEFTEGORSK DEBUG LOG ===")
		file.store_line("Started: %s" % timestamp)
		file.store_line("Godot version: %s" % Engine.get_version_info().get("string", "unknown"))
		file.store_line("OS: %s" % OS.get_name())
		var screen = DisplayServer.screen_get_size()
		file.store_line("Screen: %dx%d" % [screen.x, screen.y])
		file.store_line("User data dir: %s" % OS.get_user_data_dir())
		file.store_line("===")
		file.close()
	else:
		push_warning("DebugLogger: Cannot create log file at %s" % log_file_path)
	
	# Add visible debug overlay to ROOT viewport (renders on top of EVERYTHING)
	debug_canvas = CanvasLayer.new()
	debug_canvas.layer = 100  # Always on top
	debug_canvas.name = "DebugCanvas"
	
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.text = "NEFTEGORSK LOADING..."
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	debug_label.position = Vector2(20, 60)
	debug_label.size = Vector2(1060, 200)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.theme_override_font_sizes/font_size = 24
	debug_label.theme_override_colors/font_color = Color(1, 0.2, 0.2)
	debug_label.theme_override_colors/font_outline_color = Color(0, 0, 0)
	debug_label.theme_override_constants/outline_size = 2
	
	debug_canvas.add_child(debug_label)
	
	# Add to root viewport (not to self - ensures visibility before scene loads)
	get_tree().root.add_child.call_deferred(debug_canvas)
	
	log("DebugLogger._ready() OK - overlay added to root viewport")

func log(message: String) -> void:
	if not enabled:
		return
	last_message = message
	
	# Update visible label
	if debug_label:
		debug_label.text = message
	
	# Write to file
	_write_line(message)
	
	# Print to console (goes to logcat)
	print(message)

func log_node_ready(node_name: String, success: bool, detail: String = "") -> void:
	if success:
		log("OK %s: %s" % [node_name, detail])
	else:
		log("FAIL %s: %s" % [node_name, detail])

func log_error(message: String) -> void:
	log("ERROR: %s" % message)
	if debug_label:
		debug_label.theme_override_colors/font_color = Color(1, 0.0, 0.0)

func show_green(message: String) -> void:
	log(message)
	if debug_label:
		debug_label.theme_override_colors/font_color = Color(0.2, 1.0, 0.2)

func _write_line(line: String) -> void:
	var file = FileAccess.open(log_file_path, FileAccess.WRITE_READ)
	if file:
		file.seek_end()
		file.store_line(line)
		file.close()
	else:
		# File might not exist yet - create it with WRITE mode
		var file2 = FileAccess.open(log_file_path, FileAccess.WRITE)
		if file2:
			file2.store_line(line)
			file2.close()

func get_log_contents() -> String:
	var file = FileAccess.open(log_file_path, FileAccess.READ)
	if file:
		var contents = file.get_as_text()
		file.close()
		return contents
	return "(cannot read log file)"

func clear_log() -> void:
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		file.store_line("=== Log cleared at %s ===" % Time.get_datetime_string_from_system())
		file.close()
# Build trigger
# v2
