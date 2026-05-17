extends CanvasLayer
class_name GameOverScreen

func _ready() -> void:
	add_to_group("game_over_screen")
	$GameOverPanel/Layout/ButtonsContainer/RejouerButton.pressed.connect(_on_rejouer_pressed)
	$GameOverPanel/Layout/ButtonsContainer/ShopButton.pressed.connect(_on_shop_pressed)
	$GameOverPanel/Layout/ButtonsContainer/QuitterButton.pressed.connect(_on_quitter_pressed)

func show_game_over(distance: int) -> void:
	update_stats(distance)
	visible = true
	get_tree().paused = true

func update_stats(distance: int) -> void:
	%DistanceLabel.text = "Distance: " + str(distance) + " m"
	%CoinsRunLabel.text = "Pièces ce run: " + str(Settings.coins_this_run)
	%BestLabel.text = "Meilleure distance: " + str(Settings.best_distance) + " m"

func _on_rejouer_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_shop_pressed() -> void:
	var shop := get_tree().get_first_node_in_group("shop_screen")
	if shop:
		shop.open()

func _on_quitter_pressed() -> void:
	get_tree().quit()
