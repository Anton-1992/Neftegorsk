extends Control

func _ready() -> void:
	var label = get_node("Label")
	# Check if DebugLogger autoload exists in root
	var root = get_tree().root
	var dl = root.get_node_or_null("DebugLogger")
	if dl != null:
		label.text = "DebugLogger FOUND! Overlay should be visible!"
		label.theme_override_colors/font_color = Color(0.2, 1.0, 0.2)
	else:
		label.text = "DebugLogger NOT found in root! (" + str(root.get_child_count()) + " children)"
		label.theme_override_colors/font_color = Color(1.0, 0.0, 0.0)
