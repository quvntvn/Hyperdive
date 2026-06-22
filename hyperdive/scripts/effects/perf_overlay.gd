extends CanvasLayer
class_name PerfOverlay

# ============================================================================================
# OVERLAY DEBUG TEMPORAIRE — À RETIRER AVANT RELEASE.
# Mesure FPS / draw calls / primitives / VRAM / nodes sur device pour valider les optimisations
# et juger les tradeoffs. Coin haut-droit, petit Label semi-transparent, par-dessus tout le jeu.
#
# >>> POUR LE COUPER D'UN MOT : passer DEBUG_PERF_OVERLAY à false ci-dessous. <<<
# (l'overlay se retire alors tout seul ; l'instanciation dans main_game.gd devient un no-op).
# ============================================================================================
const DEBUG_PERF_OVERLAY: bool = true

const REFRESH_HZ: float = 4.0   # rafraîchissement ~4×/s (lisible sans bruit visuel)
const _PERIOD: float = 1.0 / REFRESH_HZ

var _label: Label
var _accum: float = 0.0

func _ready() -> void:
	if not DEBUG_PERF_OVERLAY:
		queue_free()
		return
	# Au-dessus du HUD (1) et de la pause (5), sous la Transition (~100). Tourne même en pause.
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	_label = Label.new()
	_label.name = "PerfLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Ancré en haut-droit, largeur fixe qui grandit vers la gauche.
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = -210.0
	_label.offset_right = -10.0
	_label.offset_top = 8.0
	_label.offset_bottom = 130.0
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 0.85))   # vert pâle lisible
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	# Décale sous l'encoche/barre de statut (même convention que le reste de l'UI).
	UIAnimations.apply_top_safe_area(_label, 8.0)
	_refresh()

func _process(delta: float) -> void:
	_accum += delta
	if _accum < _PERIOD:
		return
	_accum = 0.0
	_refresh()

func _refresh() -> void:
	var fps: int = int(Engine.get_frames_per_second())
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vram_mo: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_label.text = "FPS %d\nDraws %d\nPrims %s\nVRAM %.1f Mo\nNodes %d" % [
		fps, draws, UIAnimations.format_number(prims), vram_mo, nodes
	]
