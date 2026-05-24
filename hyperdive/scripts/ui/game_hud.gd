extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _coin_label: Label
var _campaign_mode: bool = false

func _ready() -> void:
	var node := get_node_or_null(player_path)
	if node is PlayerController:
		_player = node as PlayerController
		_player.game_over.connect(_on_game_over)
	_distance_label = $VBoxContainer/DistanceLabel
	_coin_label = $CoinCounter/CoinLabel
	_coin_label.text = str(Settings.coins_total)
	Settings.coin_collected.connect(_on_coin_collected)
	%PauseButton.pressed.connect(_on_pause_pressed)

func set_campaign_mode(enabled: bool) -> void:
	_campaign_mode = enabled
	$CoinCounter.visible = not enabled

func update_campaign_time(seconds: float) -> void:
	_distance_label.text = "Temps : " + str(ceili(seconds)) + "s"

func _process(_delta: float) -> void:
	if _player == null or _campaign_mode:
		return
	_distance_label.text = str(int(abs(_player.global_position.y))) + " m"

func _on_game_over() -> void:
	print("GAME OVER")

func _on_coin_collected(new_total: int) -> void:
	_coin_label.text = str(new_total)

func _on_pause_pressed() -> void:
	Audio.play_ui_click()
	var pause := get_tree().get_first_node_in_group("pause_screen")
	if pause:
		pause.open()

