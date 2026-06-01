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
