extends Node3D
class_name MainMenu

func _ready() -> void:
	%CampagneButton.pressed.connect(_on_campagne_pressed)
	%JouerButton.pressed.connect(_on_jouer_pressed)
	%EnvolButton.pressed.connect(_on_envol_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%DefisButton.pressed.connect(_on_defis_pressed)
	%SettingsGearButton.pressed.connect(_on_reglages_pressed)
	UIAnimations.wire_buttons(self)

	# Ville lointaine ancrée à la caméra du menu (même logique qu'en jeu, thème appliqué).
	CitySkyline.attach_to($PreviewCamera)

	_update_infinite_button()
	update_stats()
	Settings.coin_collected.connect(func(_n: int) -> void: update_stats())

	Audio.stop_whoosh()
	Audio.unduck_music()
	Audio.play_music()

	_animate_title()

func _update_infinite_button() -> void:
	if Settings.is_infinite_unlocked():
		%JouerButton.disabled = false
		%JouerButton.text = "JOUER"
		%InfiniLockedLabel.visible = false
	else:
		%JouerButton.disabled = true
		%JouerButton.text = "INFINI — Niv. 2"
		%InfiniLockedLabel.visible = true
	# Mode envol : visible/activé seulement après le niveau 5.
	%EnvolButton.visible = Settings.is_envol_unlocked()

func update_stats() -> void:
	%BestLabel.text = "Record : " + str(Settings.best_distance) + " m"
	%CoinsLabel.text = "Pièces : " + str(Settings.coins_total)

func _on_campagne_pressed() -> void:
	Audio.play_ui_click()
	Transition.change_scene("res://scenes/ui/level_screen.tscn")

func _on_jouer_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "infinite"
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_envol_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "envol"
	Transition.change_scene("res://scenes/game/main_game.tscn")

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

func _animate_title() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(%TitleLabel, "modulate", Color(1.15, 1.15, 1.15, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%TitleLabel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
