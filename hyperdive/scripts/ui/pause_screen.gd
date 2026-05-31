extends CanvasLayer
class_name PauseScreen

func _ready() -> void:
	add_to_group("pause_screen")
	visible = false
	%ReprendreButton.pressed.connect(_on_reprendre_pressed)
	%ReglagesButton.pressed.connect(_on_reglages_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)
	UIAnimations.wire_buttons(self)

func open() -> void:
	visible = true
	get_tree().paused = true
	Audio.duck_music()
	UIAnimations.pop_in($PausePanel, $Background)

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
	Audio.stop_jetpack()
	get_tree().paused = false
	Transition.change_scene("res://scenes/ui/main_menu.tscn")

