extends Control

func _ready() -> void:
	var results: String = ""
	var all_ok: bool = true
	
	# Check each autoload
	var autoloads: Dictionary = {
		"DebugLogger": DebugLogger,
		"GameManager": GameManager,
		"LevelManager": LevelManager,
		"UpgradeManager": UpgradeManager,
		"EconomyManager": EconomyManager,
		"SaveManager": SaveManager,
		"AudioManager": AudioManager,
	}
	
	for name in autoloads:
		var node = autoloads[name]
		if node != null:
			results += name + ": OK\n"
		else:
			results += name + ": NULL!\n"
			all_ok = false
	
	# Also check if DebugLogger overlay exists
	var overlay = get_tree().root.get_node_or_null("DebugCanvas")
	if overlay != null:
		results += "DebugCanvas: OK\n"
	else:
		results += "DebugCanvas: NOT FOUND\n"
	
	if all_ok:
		results = "ALL AUTOLOADS OK!\n" + results
		$StatusLabel.theme_override_colors/font_color = Color(0.2, 1.0, 0.2)
	else:
		results = "SOME AUTOLOADS FAILED!\n" + results
		$StatusLabel.theme_override_colors/font_color = Color(1.0, 0.0, 0.0)
	
	$StatusLabel.text = results
	print(results)
