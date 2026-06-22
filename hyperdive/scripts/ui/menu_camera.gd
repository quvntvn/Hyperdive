extends Camera3D
class_name MenuCamera

const DESCENT_SPEED: float = 3.0
# Période verticale du motif des murs : line_spacing == win_cell.y dans wall_pattern.gdshader.
const PATTERN_PERIOD: float = 1.35
# Nombre de cellules par boucle. DOIT correspondre au loop_cells du CorridorWalls du menu,
# sinon l'identité des fenêtres ne retombe pas sur elle-même au recyclage.
const LOOP_CELLS: int = 15
# Multiple EXACT de la période → géométrie + identité des fenêtres alignées à la boucle.
const LOOP_DISTANCE: float = PATTERN_PERIOD * float(LOOP_CELLS)  # 20.25

var _start_y: float

func _ready() -> void:
	_start_y = global_position.y

func _process(delta: float) -> void:
	global_position.y -= DESCENT_SPEED * delta
	if _start_y - global_position.y >= LOOP_DISTANCE:
		global_position.y += LOOP_DISTANCE
