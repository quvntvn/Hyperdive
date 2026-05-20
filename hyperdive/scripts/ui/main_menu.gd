extends Control
class_name MainMenu

func _ready() -> void:
	%JouerButton.pressed.connect(_on_jouer_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%QuitterButton.pressed.connect(_on_quitter_pressed)

	update_stats()
	Settings.coin_collected.connect(func(_n: int) -> void: update_stats())

	Audio.stop_whoosh()
	Audio.unduck_music()
	Audio.play_music()

func update_stats() -> void:
	%BestLabel.text = "Meilleure distance: " + str(Settings.best_distance) + " m"
	%CoinsLabel.text = "Pièces totales: " + str(Settings.coins_total)

func _on_jouer_pressed() -> void:
	Audio.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/game/main_game.tscn")

func _on_shop_pressed() -> void:
	Audio.play_ui_click()
	var shop := get_tree().get_first_node_in_group("shop_screen")
	if shop:
		shop.open()

func _on_quitter_pressed() -> void:
	Audio.play_ui_click()
	get_tree().quit()
