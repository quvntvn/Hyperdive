extends CanvasLayer
class_name PostProcess

# Pilote les effets plein écran (layer 0) : flash de ramassage coloré + effet RALENTI
# (vignette froide + désaturation via le shader halftone). Trouvé par les autres scripts
# via le groupe "post_process". Tout en uniforms/ColorRect → quasi gratuit en perf mobile.

var _shader_mat: ShaderMaterial
var _flash: ColorRect
var _slowmo_tween: Tween
var _slowmo_amount: float = 0.0
var _speed_mat: ShaderMaterial
var _speed_tween: Tween
var _speed_amount: float = 0.0

func _ready() -> void:
	add_to_group("post_process")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen := $ScreenEffect as ColorRect
	_shader_mat = screen.material as ShaderMaterial
	_flash = $Flash as ColorRect
	if _flash != null:
		_flash.color.a = 0.0
	var speed := $SpeedLines as ColorRect
	if speed != null:
		_speed_mat = speed.material as ShaderMaterial
	_apply_slowmo(0.0)
	_apply_speed_lines(0.0)

# Flash bref plein écran (ramassage de power-up) : monte vite puis redescend. Additif,
# léger (strength ~0.3), ne masque pas le jeu.
func flash(color: Color, strength: float = 0.32, dur: float = 0.18) -> void:
	if _flash == null:
		return
	_flash.color = Color(color.r, color.g, color.b, 0.0)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", strength, 0.04)
	tw.tween_property(_flash, "color:a", 0.0, dur)

# Ralenti : transition DOUCE (0.4 s) de la vignette/teinte/désaturation, en entrée comme
# en sortie (pas de claquage). active=true monte l'effet, false le retire.
func set_slowmo(active: bool) -> void:
	var target: float = 1.0 if active else 0.0
	if _slowmo_tween != null and _slowmo_tween.is_valid():
		_slowmo_tween.kill()
	_slowmo_tween = create_tween()
	_slowmo_tween.tween_method(_apply_slowmo, _slowmo_amount, target, 0.4)

func _apply_slowmo(x: float) -> void:
	_slowmo_amount = x
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("vignette_strength", x * 0.55)
	_shader_mat.set_shader_parameter("desaturation", x * 0.35)
	# Teinte froide (bleutée) dosée par l'alpha → slow-motion "cinéma" sans masquer le centre.
	_shader_mat.set_shader_parameter("tint_color", Color(0.7, 0.8, 1.0, x * 0.25))

# Boost : lignes de vitesse radiales sur les bords. Transition douce en entrée/sortie.
func set_speed_lines(active: bool) -> void:
	var target: float = 1.0 if active else 0.0
	if _speed_tween != null and _speed_tween.is_valid():
		_speed_tween.kill()
	_speed_tween = create_tween()
	_speed_tween.tween_method(_apply_speed_lines, _speed_amount, target, 0.25)

func _apply_speed_lines(x: float) -> void:
	_speed_amount = x
	if _speed_mat != null:
		_speed_mat.set_shader_parameter("strength", x * 0.7)
