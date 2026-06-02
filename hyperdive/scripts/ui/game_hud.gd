extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _coin_label: Label
var _shield_label: Label
var _timed_label: Label
var _campaign_mode: bool = false

func _ready() -> void:
	var node := get_node_or_null(player_path)
	if node is PlayerController:
		_player = node as PlayerController
		_player.game_over.connect(_on_game_over)
	_distance_label = $VBoxContainer/DistanceLabel
	_coin_label = $CoinCounter/CoinLabel
	_shield_label = $PowerupIndicator/ShieldLabel
	_timed_label = $PowerupIndicator/TimedLabel
	_coin_label.text = str(Settings.coins_total)
	Settings.coin_collected.connect(_on_coin_collected)
	%PauseButton.pressed.connect(_on_pause_pressed)
	# Descend les éléments hauts du HUD sous la safe area (encoche/caméra frontale).
	UIAnimations.apply_top_safe_area($VBoxContainer, 12.0)
	UIAnimations.apply_top_safe_area($CoinCounter, 12.0)
	UIAnimations.apply_top_safe_area(%PauseButton, 12.0)

func set_campaign_mode(enabled: bool) -> void:
	_campaign_mode = enabled
	$CoinCounter.visible = not enabled

func update_campaign_time(seconds: float) -> void:
	_distance_label.text = str(ceili(seconds)) + "s"

func _process(_delta: float) -> void:
	if _player == null:
		return
	if not _campaign_mode:
		_distance_label.text = str(int(abs(_player.global_position.y))) + " m"
	_update_powerup_indicator()

func _update_powerup_indicator() -> void:
	_shield_label.visible = _player.has_shield
	if _player.boost_timer > 0.0:
		_timed_label.visible = true
		_timed_label.text = "BOOST " + str(ceili(_player.boost_timer)) + "s"
		_timed_label.add_theme_color_override("font_color", Color(0.914, 0.310, 0.216, 1.0))
	elif _player.slowmo_timer > 0.0:
		_timed_label.visible = true
		_timed_label.text = "RALENTI " + str(ceili(_player.slowmo_timer)) + "s"
		_timed_label.add_theme_color_override("font_color", Color(0.612, 0.796, 0.906, 1.0))
	elif _player.magnet_timer > 0.0:
		_timed_label.visible = true
		_timed_label.text = "AIMANT " + str(ceili(_player.magnet_timer)) + "s"
		_timed_label.add_theme_color_override("font_color", Color(0.949, 0.757, 0.306, 1.0))
	else:
		_timed_label.visible = false

func _on_game_over() -> void:
	print("GAME OVER")

func _on_coin_collected(new_total: int) -> void:
	_coin_label.text = str(new_total)

func _on_pause_pressed() -> void:
	Audio.play_ui_click()
	var pause := get_tree().get_first_node_in_group("pause_screen")
	if pause:
		pause.open()
