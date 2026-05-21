extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _life_rects: Array[ColorRect]
var _coin_label: Label
var _campaign_mode: bool = false

func _ready() -> void:
	var node := get_node_or_null(player_path)
	if node is PlayerController:
		_player = node as PlayerController
		_player.life_lost.connect(_on_life_lost)
		_player.game_over.connect(_on_game_over)
	_distance_label = $VBoxContainer/DistanceLabel
	_life_rects = [
		$LivesContainer/Life0 as ColorRect,
		$LivesContainer/Life1 as ColorRect,
		$LivesContainer/Life2 as ColorRect,
	]
	_coin_label = $CoinCounter/CoinLabel
	_coin_label.text = str(Settings.coins_total)
	Settings.coin_collected.connect(_on_coin_collected)
	%PauseButton.pressed.connect(_on_pause_pressed)
	_style_pause_button()

func set_campaign_mode(enabled: bool) -> void:
	_campaign_mode = enabled
	$CoinCounter.visible = not enabled

func update_campaign_time(seconds: float) -> void:
	_distance_label.text = "Temps : " + str(ceili(seconds)) + "s"

func _process(_delta: float) -> void:
	if _player == null or _campaign_mode:
		return
	_distance_label.text = str(int(abs(_player.global_position.y))) + " m"

func _on_life_lost(remaining_lives: int) -> void:
	for i in range(_life_rects.size()):
		_life_rects[i].visible = i < remaining_lives

func _on_game_over() -> void:
	print("GAME OVER")

func _on_coin_collected(new_total: int) -> void:
	_coin_label.text = str(new_total)

func _on_pause_pressed() -> void:
	Audio.play_ui_click()
	var pause := get_tree().get_first_node_in_group("pause_screen")
	if pause:
		pause.open()

func _style_pause_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.235, 0.682, 0.639, 0.85)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	%PauseButton.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.78, 0.73, 0.95)
	%PauseButton.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.18, 0.55, 0.51, 1.0)
	%PauseButton.add_theme_stylebox_override("pressed", pressed_style)
	%PauseButton.add_theme_stylebox_override("focus", normal.duplicate())
	%PauseButton.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
	%PauseButton.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	%PauseButton.add_theme_color_override("font_pressed_color", Color(0.85, 0.82, 0.72))
