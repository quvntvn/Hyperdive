class_name GlassBlur
extends ColorRect
# Backdrop-blur réutilisable, posé derrière un Control (bouton/panneau).
# Le shader floute le décor déjà dessiné et masque le résultat en rect arrondi.
#
# Le masque arrondi du shader travaille en PIXELS ÉCRAN (rect_px = 1/fwidth(UV)), alors que
# le corner_radius d'un StyleBox est en PIXELS GUI. En stretch "canvas_items" (project.godot,
# viewport 540x960) le canvas est mis à l'échelle sur l'écran réel (×2+ sur téléphone) → si on
# laissait un rayon fixe, le masque flou serait MOINS arrondi que le bouton et ses coins quasi
# carrés dépasseraient de l'arrondi = liseré clair anguleux aux coins. On convertit donc le rayon
# GUI en pixels écran via l'échelle réelle du transform canvas, et chaque verre suit le rayon de
# SON élément (bouton 18, engrenage 16, panneau 20…) pour que toutes les couches coïncident.
#
# Mutualisation : le facteur d'échelle du canvas est GLOBAL → un matériau par rayon ÉCRAN
# (arrondi à l'entier) suffit pour tous les boutons d'un même rayon GUI.

const SHADER_PATH := "res://assets/shaders/glass_blur.gdshader"
# Rayon d'arrondi UNIQUE pour tout le verre du jeu (boutons, engrenage, cartes, panneaux).
# Source de vérité centrale : l'engrenage et les cartes le lisent ; le thème global
# (main_theme.tres) doit garder la MÊME valeur sur ses StyleBox de bouton/panneau.
const DEFAULT_RADIUS := 20.0

static var _mats: Dictionary = {}  # int(rayon écran px) -> ShaderMaterial

static func _material_for(screen_radius: float) -> ShaderMaterial:
	var key := int(round(max(screen_radius, 0.0)))
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(SHADER_PATH)
		m.set_shader_parameter("corner_radius", float(key))
		_mats[key] = m
	return _mats[key]

# Lit le corner_radius (px GUI) du StyleBoxFlat d'un Control (stylebox "normal" pour les boutons,
# "panel" pour les Panel/PanelContainer). Sert à aligner le masque du verre sur l'arrondi réel.
static func corner_radius_of(c: Control, fallback := DEFAULT_RADIUS) -> float:
	for sname in ["normal", "panel"]:
		if c.has_theme_stylebox(sname):
			var sb := c.get_theme_stylebox(sname)
			if sb is StyleBoxFlat:
				return float((sb as StyleBoxFlat).corner_radius_top_left)
	return fallback

# Rayon d'arrondi en pixels GUI ; exporté pour que les instances posées en .tscn (backdrops
# plein écran) puissent le régler (0 = pas d'arrondi, p.ex. un fond plein écran).
@export var gui_corner_radius: float = DEFAULT_RADIUS:
	set(v):
		gui_corner_radius = v
		_refresh_material()

func _init(radius: float = DEFAULT_RADIUS) -> void:
	gui_corner_radius = radius
	# Le shader réécrit COLOR entièrement ; la géométrie du rect doit juste exister.
	color = Color(1.0, 1.0, 1.0, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dessiné AVANT le parent → capture le décor derrière (pas le bouton lui-même).
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Respecte le toggle perf même pour les GlassBlur posés directement dans une scène (backdrops
# plein écran du shop/défis/game over/fin de niveau, hors autoload) : si le flou est désactivé,
# on se masque → coût nul, et le voile (Tint) translucide derrière sert de repli.
func _ready() -> void:
	if not Glass.USE_REAL_BLUR:
		visible = false
		return
	# Le rayon écran dépend de l'échelle du canvas → recalculer au layout et au resize/rotation.
	resized.connect(_refresh_material)
	get_viewport().size_changed.connect(_refresh_material)
	_refresh_material()

func _refresh_material() -> void:
	var cscale := 1.0
	if is_inside_tree():
		# Échelle réelle GUI→écran du canvas (uniforme, identique pour tous les éléments).
		var s := get_global_transform_with_canvas().get_scale()
		cscale = max(s.x, 0.001)
	material = _material_for(gui_corner_radius * cscale)

# Pose un backdrop-blur DERRIÈRE n'importe quel Control (panneau, voile, carte) — pas
# seulement les boutons (eux sont pris en charge automatiquement par l'autoload Glass).
# Aligne le rayon du verre sur l'arrondi du StyleBox du Control. Respecte le toggle perf.
static func add_behind(control: Control) -> void:
	if not Glass.USE_REAL_BLUR:
		return
	if control.has_node("GlassBlur"):
		return
	var g := GlassBlur.new(corner_radius_of(control))
	g.name = "GlassBlur"
	control.add_child(g)
	control.move_child(g, 0)
