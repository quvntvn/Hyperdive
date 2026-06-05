extends CanvasLayer
class_name LevelCompleteScreen
# Pop-up de fin de niveau (victoire campagne), affiché EN OVERLAY sur le jeu (pas un
# changement de scène) → le décor du jeu reste derrière et peut être flouté (backdrop-blur).
# C'est ICI (et nulle part avant) que s'affichent les pièces gagnées.

func _ready() -> void:
	add_to_group("level_complete_screen")
	$Content/Layout/ButtonsContainer/NextButton.pressed.connect(_on_next_pressed)
	$Content/Layout/ButtonsContainer/MenuButton.pressed.connect(_on_menu_pressed)
	UIAnimations.wire_buttons(self)
	# Panneau en verre translucide (plus de fond bleu opaque) → laisse voir le jeu flouté derrière.
	UIAnimations.make_glass_panel($Content)

# completed_level / reward sont capturés AVANT complete_current_level() (qui incrémente
# campaign_level et crédite les pièces) pour afficher le niveau réussi et le gain exact.
func show_level_complete(completed_level: int, reward: int) -> void:
	%TitleLabel.text = "NIVEAU " + UIAnimations.format_number(completed_level) + " RÉUSSI"
	%RewardLabel.text = "+ " + UIAnimations.format_number(reward) + " pièces"
	%NextInfoLabel.text = "Prochain : niveau " + UIAnimations.format_number(Settings.campaign_level)
	Audio.duck_music()
	visible = true
	get_tree().paused = true
	UIAnimations.pop_in($Content, $Tint)

func _on_next_pressed() -> void:
	Audio.play_ui_click()
	Audio.unduck_music()
	Audio.stop_whoosh()
	get_tree().paused = false
	Settings.active_mode = "campaign"
	Settings.active_level = Settings.campaign_level
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	Audio.unduck_music()
	Audio.stop_whoosh()
	get_tree().paused = false
	Settings.active_mode = "infinite"
	Transition.change_scene("res://scenes/ui/main_menu.tscn")
