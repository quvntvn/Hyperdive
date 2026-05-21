extends Control
class_name LevelScreen

func _ready() -> void:
	var lvl: int = Settings.campaign_level
	%TitleLabel.text = "NIVEAU " + str(lvl)
	%DurationLabel.text = "Tiens " + str(int(Settings.get_level_duration(lvl))) + "s"
	%RewardLabel.text = "Récompense : " + str(Settings.get_level_reward(lvl)) + " pièces"
	%CommencerButton.pressed.connect(_on_commencer_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)
	_style_button(%CommencerButton)

func _on_commencer_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "campaign"
	Settings.active_level = Settings.campaign_level
	get_tree().change_scene_to_file("res://scenes/game/main_game.tscn")

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "infinite"
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _style_button(btn: Button) -> void:
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
