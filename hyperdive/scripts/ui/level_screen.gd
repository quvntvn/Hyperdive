extends Control
class_name LevelScreen

func _ready() -> void:
	var lvl: int = Settings.campaign_level
	%TitleLabel.text = "NIVEAU " + str(lvl)
	%DurationLabel.text = "Tiens " + str(int(Settings.get_level_duration(lvl))) + "s"
	%RewardLabel.text = "Récompense : " + str(Settings.get_level_reward(lvl)) + " pièces"
	%CommencerButton.pressed.connect(_on_commencer_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)

func _on_commencer_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "campaign"
	Settings.active_level = Settings.campaign_level
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "infinite"
	Transition.change_scene("res://scenes/ui/main_menu.tscn")

