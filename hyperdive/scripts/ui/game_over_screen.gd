extends CanvasLayer
class_name GameOverScreen

var shop_screen: CanvasLayer

func _ready() -> void:
	add_to_group("game_over_screen")
	$GameOverPanel/Layout/ButtonsContainer/RejouerButton.pressed.connect(_on_rejouer_pressed)
	$GameOverPanel/Layout/ButtonsContainer/ShopButton.pressed.connect(_on_shop_pressed)
	$GameOverPanel/Layout/ButtonsContainer/MenuButton.pressed.connect(_on_menu_pressed)
	UIAnimations.wire_buttons(self)
	# Panneau en verre translucide (plus de fond bleu opaque) → laisse voir le jeu flouté derrière.
	UIAnimations.make_glass_panel($GameOverPanel)
	var screens := get_tree().get_nodes_in_group("shop_screen")
	if screens.size() > 0:
		shop_screen = screens[0]
	else:
		push_warning("GameOverScreen: aucun node dans le groupe 'shop_screen' trouvé")

func show_game_over(distance: int) -> void:
	update_stats(distance)
	if shop_screen == null:
		var screens := get_tree().get_nodes_in_group("shop_screen")
		if screens.size() > 0:
			shop_screen = screens[0]
	if shop_screen and shop_screen.visible:
		shop_screen.close()
	Audio.duck_music()
	visible = true
	get_tree().paused = true
	UIAnimations.pop_in($GameOverPanel, $Background)

func update_stats(distance: int) -> void:
	%DistanceLabel.text = tr("GAMEOVER_DISTANCE_FMT") % UIAnimations.format_number(distance)
	%CoinsRunLabel.text = tr("GAMEOVER_COINS_RUN_FMT") % UIAnimations.format_number(Settings.coins_this_run)
	%BestLabel.text = tr("GAMEOVER_BEST_FMT") % UIAnimations.format_number(Settings.best_distance)

func _on_rejouer_pressed() -> void:
	Audio.play_ui_click()
	Audio.unduck_music()
	get_tree().paused = false
	Transition.reload_scene()

func _on_shop_pressed() -> void:
	Audio.play_ui_click()
	if shop_screen == null:
		var screens := get_tree().get_nodes_in_group("shop_screen")
		if screens.size() > 0:
			shop_screen = screens[0]
	if shop_screen:
		shop_screen.open()

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	Audio.unduck_music()
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	get_tree().paused = false
	Settings.active_mode = "infinite"
	Transition.change_scene("res://scenes/ui/main_menu.tscn")
