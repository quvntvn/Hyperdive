extends Node3D
class_name MainMenu

func _ready() -> void:
	%CampagneButton.pressed.connect(_on_campagne_pressed)
	%JouerButton.pressed.connect(_on_jouer_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%DefisButton.pressed.connect(_on_defis_pressed)
	%ReglagesButton.pressed.connect(_on_reglages_pressed)

	_update_infinite_button()
	update_stats()
	Settings.coin_collected.connect(func(_n: int) -> void: update_stats())

	Audio.stop_whoosh()
	Audio.unduck_music()
	Audio.play_music()

	_style_button(%CampagneButton)
	_style_button(%JouerButton)
	_style_button(%ShopButton)
	_style_button(%DefisButton)
	_style_button(%ReglagesButton)
	_animate_title()

func _update_infinite_button() -> void:
	if Settings.is_infinite_unlocked():
		%JouerButton.disabled = false
		%JouerButton.text = "JOUER"
		%InfiniLockedLabel.visible = false
	else:
		%JouerButton.disabled = true
		%JouerButton.text = "INFINI — Niv. 5"
		%InfiniLockedLabel.visible = true

func update_stats() -> void:
	%BestLabel.text = "Record : " + str(Settings.best_distance) + " m"
	%CoinsLabel.text = "Pièces : " + str(Settings.coins_total)

func _on_campagne_pressed() -> void:
	Audio.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/ui/level_screen.tscn")

func _on_jouer_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "infinite"
	get_tree().change_scene_to_file("res://scenes/game/main_game.tscn")

func _on_shop_pressed() -> void:
	Audio.play_ui_click()
	var shop := get_tree().get_first_node_in_group("shop_screen")
	if shop:
		shop.open()

func _on_defis_pressed() -> void:
	Audio.play_ui_click()
	var missions := get_tree().get_first_node_in_group("missions_screen")
	if missions:
		missions.open()

func _on_reglages_pressed() -> void:
	Audio.play_ui_click()
	var s := get_tree().get_first_node_in_group("settings_screen")
	if s:
		s.open()

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
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.55, 0.51)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal.duplicate())
	btn.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.82, 0.72))

func _animate_title() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(%TitleLabel, "modulate", Color(1.15, 1.15, 1.15, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%TitleLabel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
