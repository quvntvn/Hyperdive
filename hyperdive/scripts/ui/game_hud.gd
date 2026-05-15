extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _life_rects: Array[ColorRect]

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

func _process(_delta: float) -> void:
	if _player == null:
		return
	_distance_label.text = str(int(abs(_player.global_position.y))) + " m"

func _on_life_lost(remaining_lives: int) -> void:
	for i in range(_life_rects.size()):
		_life_rects[i].visible = i < remaining_lives

func _on_game_over() -> void:
	print("GAME OVER")
