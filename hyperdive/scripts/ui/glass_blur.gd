class_name GlassBlur
extends ColorRect
# Backdrop-blur réutilisable, posé derrière un Control (bouton/panneau).
# Le shader floute le décor déjà dessiné et masque le résultat en rect arrondi.
# UN SEUL ShaderMaterial partagé entre toutes les instances (taille déduite via
# fwidth dans le shader) → mutualisé, pas dupliqué.

const SHADER_PATH := "res://assets/shaders/glass_blur.gdshader"

static var _shared_mat: ShaderMaterial = null

static func _get_material() -> ShaderMaterial:
	if _shared_mat == null:
		_shared_mat = ShaderMaterial.new()
		_shared_mat.shader = load(SHADER_PATH)
	return _shared_mat

func _init() -> void:
	# Le shader réécrit COLOR entièrement ; la géométrie du rect doit juste exister.
	color = Color(1.0, 1.0, 1.0, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dessiné AVANT le parent → capture le décor derrière (pas le bouton lui-même).
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = _get_material()

# Respecte le toggle perf même pour les GlassBlur posés directement dans une scène (backdrops
# plein écran du shop/défis/game over/fin de niveau, hors autoload) : si le flou est désactivé,
# on se masque → coût nul, et le voile (Tint) translucide derrière sert de repli.
func _ready() -> void:
	if not Glass.USE_REAL_BLUR:
		visible = false

# Pose un backdrop-blur DERRIÈRE n'importe quel Control (panneau, voile, carte) — pas
# seulement les boutons (eux sont pris en charge automatiquement par l'autoload Glass).
# Respecte le toggle perf Glass.USE_REAL_BLUR : si désactivé, ne pose rien (repli zéro coût).
static func add_behind(control: Control) -> void:
	if not Glass.USE_REAL_BLUR:
		return
	if control.has_node("GlassBlur"):
		return
	var g := GlassBlur.new()
	g.name = "GlassBlur"
	control.add_child(g)
	control.move_child(g, 0)
