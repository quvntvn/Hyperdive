class_name GlassBlur
extends ColorRect
# Backdrop-blur réutilisable, posé derrière un Control (bouton/panneau).
# Le shader floute le décor déjà dessiné et masque le résultat en rect arrondi.
#
# Le masque arrondi doit coïncider PILE avec l'arrondi du StyleBox de l'élément, sinon on voit
# deux arrondis légèrement décalés (« coins doublés ») — surtout sur mobile où le canvas est mis
# à l'échelle. Plutôt que de convertir le rayon GUI→écran via le transform canvas (fragile :
# timing de layout, CanvasLayer…), on exprime le rayon en FRACTION du petit côté de l'élément
# (calculée en px GUI) et le shader la multiplie par la taille RÉELLE (rect_px = 1/fwidth(UV)).
# Résultat : le masque suit exactement l'arrondi quelle que soit l'échelle, sans dépendre d'un
# facteur externe. Le ColorRect épouse exactement l'élément (PRESET_FULL_RECT) → un seul contour.

const SHADER_PATH := "res://assets/shaders/glass_blur.gdshader"
# Rayon d'arrondi UNIQUE pour tout le verre du jeu (boutons, engrenage, cartes, panneaux).
# Source de vérité centrale ; le thème global (main_theme.tres) garde la MÊME valeur.
const DEFAULT_RADIUS := 20.0

var _mat: ShaderMaterial   # un matériau par instance (la fraction dépend de la taille de l'élément)

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
		_refresh()

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
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	material = _mat
	# La fraction = rayon GUI / petit côté de l'élément. Recalculée au resize (la taille du
	# ColorRect = celle de l'élément, FULL_RECT) ; deferred pour capter le 1er layout valide.
	resized.connect(_refresh)
	_refresh()
	_refresh.call_deferred()

func _refresh() -> void:
	if _mat == null:
		return
	var m: float = minf(size.x, size.y)
	var ratio: float = (gui_corner_radius / m) if m > 0.0 else 0.0
	_mat.set_shader_parameter("corner_ratio", ratio)

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
