## MainMenuCode.gd — MINIMAL TEST VERSION
## Just shows a bright label to prove _ready() executes
## If you see red "MENU LOADED!" text → _ready() works, add more UI later
## If grey screen → _ready() is NOT executing at all

extends Control

func _ready() -> void:
	# STEP 1: Absolute minimum — one bright label at top
	# No layout, no anchors, no managers, no textures — just raw text
	var test_label = Label.new()
	test_label.name = "TestLabel"
	test_label.text = "MENU LOADED! _ready() OK!"
	test_label.position = Vector2(50, 200)
	test_label.size = Vector2(980, 100)
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	test_label.theme_override_font_sizes/font_size = 48
	test_label.theme_override_colors/font_color = Color(1, 0.0, 0.0, 1)  # BRIGHT RED
	test_label.theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
	test_label.theme_override_constants/outline_size = 4
	add_child(test_label)
	
	# Background so we know this Control exists
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.1, 0.15, 0.2, 1)  # Dark blue-grey
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1080, 1920)
	# Move BG behind the label
	move_child(bg, 0)
	
	# STEP 2: If step1 worked, try adding title + cash
	var title = Label.new()
	title.name = "Title"
	title.text = "НЕФТЕГОРСК"
	title.position = Vector2(340, 50)
	title.size = Vector2(400, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_override_font_sizes/font_size = 48
	title.theme_override_colors/font_color = Color(1, 0.9, 0.3, 1)
	add_child(title)
	
	# STEP 3: Cash display (safe — check GameManager first)
	if GameManager.instance != null:
		var cash = Label.new()
		cash.name = "Cash"
		cash.text = "%d ₽" % GameManager.instance.cash
		cash.position = Vector2(800, 50)
		cash.size = Vector2(260, 40)
		cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cash.theme_override_font_sizes/font_size = 28
		cash.theme_override_colors/font_color = Color(0.4, 1, 0.4, 1)
		add_child(cash)
		
		var stars = Label.new()
		stars.name = "Stars"
		stars.text = "★ %d" % GameManager.instance.total_stars
		stars.position = Vector2(800, 90)
		stars.size = Vector2(260, 40)
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stars.theme_override_font_sizes/font_size = 28
		stars.theme_override_colors/font_color = Color(1, 0.9, 0.2, 1)
		add_child(stars)
	
	# STEP 4: One district button (business_center — always unlocked)
	var btn = Button.new()
	btn.name = "BtnBC"
	btn.text = "Деловой центр ★"
	btn.position = Vector2(400, 500)
	btn.size = Vector2(200, 80)
	btn.theme_override_font_sizes/font_size = 20
	add_child(btn)
	if btn.pressed:
		btn.pressed.connect(_on_bc_pressed)
	
	# STEP 5: Continue button
	var btn_cont = Button.new()
	btn_cont.name = "BtnContinue"
	btn_cont.text = "ПРОДОЛЖИТЬ"
	btn_cont.position = Vector2(600, 1800)
	btn_cont.size = Vector2(460, 80)
	btn_cont.theme_override_font_sizes/font_size = 24
	add_child(btn_cont)
	
	# Write debug log
	if DebugLogger.instance != null:
		DebugLogger.instance.log("MainMenuCode MINIMAL: _ready() completed!")
	else:
		push_warning("MainMenuCode: DebugLogger.instance is null")

func _on_bc_pressed() -> void:
	if AudioManager.instance != null:
		AudioManager.instance.sfx_button_click()
	if GameManager.instance != null:
		GameManager.instance.go_to_district_map("business_center")
