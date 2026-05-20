extends CanvasLayer
class_name PauseScreen

func _ready() -> void:
	add_to_group("pause_screen")
	visible = false
	%ReprendreButton.pressed.connect(_on_reprendre_pressed)
	%ReglagesButton.pressed.connect(_on_reglages_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)
	_style_buttons()

func open() -> void:
	visible = true
	get_tree().paused = true
	Audio.duck_music()

func close() -> void:
	visible = false
	get_tree().paused = false
	Audio.unduck_music()

func _on_reprendre_pressed() -> void:
	Audio.play_ui_click()
	close()

func _on_reglages_pressed() -> void:
	Audio.play_ui_click()
	var s := get_tree().get_first_node_in_group("settings_screen")
	if s:
		s.open()

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	Audio.unduck_music()
	Audio.stop_whoosh()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _style_buttons() -> void:
	for btn: Button in [%ReprendreButton, %ReglagesButton, %MenuButton]:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.235, 0.682, 0.639)
		normal.set_corner_radius_all(8)
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 12
		normal.content_margin_bottom = 12
		btn.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.32, 0.78, 0.73)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed_style := normal.duplicate() as StyleBoxFlat
		pressed_style.bg_color = Color(0.18, 0.55, 0.51)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("focus", normal.duplicate())
		btn.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.82, 0.72))
