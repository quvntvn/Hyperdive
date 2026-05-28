extends Camera3D
class_name MenuCamera

const DESCENT_SPEED: float = 3.0
const LOOP_DISTANCE: float = 20.25  # 15 × win_cell.y (1.35) → boucle alignée sur la période de la grille

var _start_y: float

func _ready() -> void:
	_start_y = global_position.y

func _process(delta: float) -> void:
	global_position.y -= DESCENT_SPEED * delta
	if _start_y - global_position.y >= LOOP_DISTANCE:
		global_position.y += LOOP_DISTANCE
