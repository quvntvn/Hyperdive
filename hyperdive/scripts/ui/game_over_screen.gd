extends CanvasLayer
class_name GameOverScreen

@export var shop_screen: CanvasLayer

func _ready() -> void:
	add_to_group("game_over_screen")
	$GameOverPanel/Layout/ButtonsContainer/RejouerButton.pressed.connect(_on_rejouer_pressed)
	$GameOverPanel/Layout/ButtonsContainer/ShopButton.pressed.connect(_on_shop_pressed)
	$GameOverPanel/Layout/ButtonsContainer/QuitterButton.pressed.connect(_on_quitter_pressed)

func show_game_over(distance: int) -> void:
	update_stats(distance)
	if shop_screen and shop_screen.visible:
		shop_screen.close()
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
	print("[Shop button] pressed. shop_screen = ", shop_screen)
	if shop_screen:
		print("[Shop button] calling open()")
		shop_screen.open()
	else:
		print("[Shop button] ERROR: shop_screen is null")

func _on_quitter_pressed() -> void:
	get_tree().quit()
