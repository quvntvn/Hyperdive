extends CanvasLayer
class_name CampaignScreen
# Carte de campagne : un CHEMIN vertical en zig-zag entre les deux tours de Vertex, avec les
# 40 chapitres en nœuds le long du parcours. Scroll haut→bas (ch.1 en haut → ch.40 en bas) ;
# un nœud "pivot" au ch.20 marque l'inversion narrative (chute → jetpack). Ouverture centrée
# sur le chapitre courant. Même facture verre que les autres écrans pleins (backdrop-blur + tint).
#
# Tout le contenu de la carte est construit en code (40 nœuds + tours + chemin) → reconstruit à
# chaque ouverture et après chaque complétion (la progression peut avoir avancé).

const TOWER_SHADER: String = "res://assets/shaders/tower_windows.gdshader"
const LOCK_ICON: String = "res://assets/ui/lock_icon.svg"

const VSTEP: float = 150.0          # espacement vertical entre deux nœuds
const TOP_PAD: float = 110.0
const BOT_PAD: float = 140.0
const NORMAL_D: float = 60.0        # diamètre d'un nœud
const CURRENT_D: float = 80.0       # diamètre du nœud courant (mis en avant)
const SIDE_MARGIN: float = 16.0     # = offset_left/right du Scroll dans la scène

const TURQUOISE: Color = Color(0.235, 0.682, 0.639)   # chute
const JAUNE: Color = Color(0.949, 0.757, 0.306)       # jetpack
const CREME: Color = Color(0.957, 0.914, 0.804)       # narration
const GREY: Color = Color(0.55, 0.55, 0.58)           # verrouillé
const PATH_DONE: Color = Color(0.957, 0.914, 0.804, 0.8)
const PATH_TODO: Color = Color(0.72, 0.74, 0.80, 0.26)

var _centers: Array[Vector2] = []
var _reader_connected: bool = false

@onready var _map: Control = $Content/Scroll/Map
@onready var _scroll: ScrollContainer = $Content/Scroll
@onready var _towers: Array[ColorRect] = [$Content/LeftTower, $Content/RightTower]

func _ready() -> void:
	add_to_group("campaign_screen")
	$Content/GalleryButton.pressed.connect(_on_gallery)
	$Content/RetourButton.pressed.connect(_on_retour)
	UIAnimations.wire_buttons(self)
	# En-tête empilé (Lire au-dessus, HISTOIRE dessous) + Scroll : tout décalé du même inset de
	# safe area (encoche), pour garder l'empilage propre sans chevauchement sur tous les écrans.
	var inset: float = maxf(UIAnimations.top_safe_inset(get_viewport()), 24.0)
	for ctrl: Control in [$Content/GalleryButton, $Content/TitleLabel]:
		ctrl.offset_top += inset
		ctrl.offset_bottom += inset
	_scroll.offset_top += inset
	_setup_towers()

# Les tours sont un CALQUE DE FOND fixe (pleine emprise écran, collées aux bords) : seul le motif
# de fenêtres défile (via scroll_offset dans le shader). Matériau par tour, teinté par le thème.
func _setup_towers() -> void:
	for col in _towers:
		var mat := ShaderMaterial.new()
		mat.shader = load(TOWER_SHADER)
		col.material = mat
	_apply_tower_theme()
	Settings.equipped_theme_changed.connect(func(_id: String) -> void: _apply_tower_theme())

func _apply_tower_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	var wall: Color = (theme["wall_color"] as Color) * 0.8   # assombri (comme les murs du jeu)
	wall.a = 1.0
	for col in _towers:
		var m := col.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("wall_color", wall)
			m.set_shader_parameter("line_color", theme["line_color"])

# Met à jour la taille réelle des tours (pour les cellules de fenêtres) et fait défiler le motif
# selon le scroll de la carte. Léger (2 set_shader_parameter), gaté sur la visibilité.
func _process(_delta: float) -> void:
	if not visible:
		return
	var off: float = float(_scroll.scroll_vertical)
	for col in _towers:
		var m := col.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("rect_size", col.size)
			m.set_shader_parameter("scroll_offset", off)

func open() -> void:
	visible = true
	_connect_reader()
	_build()
	UIAnimations.pop_in($Content, $Tint)
	# Centrage du scroll sur le chapitre courant après calcul du layout (2 frames de marge).
	await get_tree().process_frame
	await get_tree().process_frame
	_center_on_current()

# La carte écoute la fermeture du lecteur pour se reconstruire (progression avancée) et
# rafraîchir le menu (déblocages de mode). Le lecteur est un nœud frère instancié en parallèle.
func _connect_reader() -> void:
	if _reader_connected:
		return
	var r := get_tree().get_first_node_in_group("chapter_reader")
	if r != null and not r.chapter_closed.is_connected(_on_chapter_closed):
		r.chapter_closed.connect(_on_chapter_closed)
		_reader_connected = true

func _on_chapter_closed(_n: int) -> void:
	_build()
	await get_tree().process_frame
	_center_on_current()
	# Un chapitre complété peut avoir débloqué Classique (ch.1) ou Jetpack (ch.20) → rafraîchir
	# les boutons du menu (qui reste chargé derrière) et les stats.
	var menu := get_parent()
	if menu != null and menu.has_method("refresh_after_story"):
		menu.refresh_after_story()

# === Construction de la carte ==============================================================

func _build() -> void:
	for c in _map.get_children():
		c.queue_free()
	_centers.clear()

	var n_count: int = Story.chapter_count()
	var mw: float = get_viewport().get_visible_rect().size.x - 2.0 * SIDE_MARGIN
	var map_h: float = TOP_PAD + float(n_count - 1) * VSTEP + BOT_PAD
	_map.custom_minimum_size = Vector2(mw, map_h)

	# Chemin (sous les nœuds) — Control dessiné via le signal `draw`. Les tours sont un calque
	# de fond séparé (pleine emprise écran), pas dans la carte scrollée.
	var path := Control.new()
	path.name = "Path"
	path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path.position = Vector2.ZERO
	path.custom_minimum_size = Vector2(mw, map_h)
	path.size = Vector2(mw, map_h)
	_map.add_child(path)
	path.draw.connect(_draw_path.bind(path))

	# Positions des nœuds : zig-zag autour de l'axe central, alternance gauche/droite.
	var center_x: float = mw * 0.5
	var amp: float = mw * 0.18
	for i in n_count:
		var y: float = TOP_PAD + float(i) * VSTEP
		var x: float = center_x + (amp if i % 2 == 1 else -amp)
		_centers.append(Vector2(x, y))

	path.queue_redraw()   # le chemin a besoin des centres

	for i in n_count:
		_add_node(i)

func _draw_path(path: Control) -> void:
	if _centers.size() < 2:
		return
	var ci: int = clampi(Settings.story_chapter - 1, 0, _centers.size() - 1)
	# Segment parcouru (jusqu'au courant) : crème vif. Segment à venir : pâle.
	var done := PackedVector2Array()
	for i in range(0, ci + 1):
		done.append(_centers[i])
	if done.size() >= 2:
		path.draw_polyline(done, PATH_DONE, 5.0, true)
	var todo := PackedVector2Array()
	for i in range(ci, _centers.size()):
		todo.append(_centers[i])
	if todo.size() >= 2:
		path.draw_polyline(todo, PATH_TODO, 4.0, true)

func _add_node(i: int) -> void:
	var n: int = i + 1
	var ch: Dictionary = Story.get_chapter(n)
	var unlocked: bool = Story.is_unlocked(n)
	var completed: bool = Story.is_completed(n)
	var current: bool = Story.is_current(n)
	var d: float = CURRENT_D if current else NORMAL_D
	var center: Vector2 = _centers[i]
	var tcol: Color = _type_color(ch)
	var border_col: Color = tcol if unlocked else GREY
	var border_w: int = 4 if current else 2
	var bg_a: float = 0.5 if current else (0.4 if completed else 0.16)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(d, d)
	btn.size = Vector2(d, d)
	btn.position = center - Vector2(d, d) * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	var sb := _round_style(d, bg_a, border_col, border_w)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, sb)

	if unlocked:
		btn.text = str(n)
		btn.add_theme_font_size_override("font_size", 26 if current else 22)
		var num_col: Color = tcol if completed else CREME
		for cname in ["font_color", "font_hover_color", "font_pressed_color"]:
			btn.add_theme_color_override(cname, num_col)
	else:
		# Verrouillé : pas de numéro, un cadenas centré. Le cadenas PRIME sur le liseré de type.
		var lock := TextureRect.new()
		lock.texture = load(LOCK_ICON)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.size = Vector2(d * 0.5, d * 0.5)
		lock.position = Vector2(d * 0.25, d * 0.25)
		lock.modulate = Color(1, 1, 1, 0.7)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lock)

	btn.pressed.connect(_on_node.bind(n, unlocked, btn))
	_map.add_child(btn)

	# Glow pulsant du nœud courant (tween lié au bouton → auto-libéré à la reconstruction).
	if current:
		var tw := btn.create_tween().set_loops()
		tw.tween_property(btn, "modulate", Color(1.25, 1.25, 1.25, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
		# Titre court du chapitre courant, sous le nœud.
		_add_label(ch.get("title", ""), 16, CREME, Vector2(center.x - 100.0, center.y + d * 0.5 + 6.0), 200.0)

	# Badge ✓ pour les chapitres complétés (en haut à droite du nœud).
	if completed:
		_add_label("✓", 18, tcol, Vector2(center.x + d * 0.12, center.y - d * 0.55), 24.0)

	# Marquage PIVOT au ch.20 (inversion chute → jetpack) : flèches ↓↑ au-dessus du nœud.
	if n == 20:
		_add_label("↓  ↑", 22, JAUNE, Vector2(center.x - 60.0, center.y - d * 0.5 - 30.0), 120.0)

func _add_label(txt: String, font_size: int, color: Color, pos: Vector2, width: float) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(width, float(font_size) + 8.0)
	lbl.custom_minimum_size = lbl.size
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(lbl)

func _round_style(d: float, bg_a: float, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.17, 0.27, bg_a)
	sb.set_corner_radius_all(int(d * 0.5))
	sb.set_border_width_all(border_w)
	sb.border_color = border
	return sb

func _type_color(ch: Dictionary) -> Color:
	if ch.get("type", "story") == "story":
		return CREME
	return JAUNE if ch.get("mode", "fall") == "jetpack" else TURQUOISE

# === Interactions ==========================================================================

func _on_node(n: int, unlocked: bool, btn: Button) -> void:
	if not unlocked:
		Audio.play_ui_click()
		Settings.vibrate(20)
		_shake(btn)
		return
	Audio.play_ui_click()
	var ch: Dictionary = Story.get_chapter(n)
	var ctx: String
	if ch.get("type", "story") == "story":
		ctx = "story"
	elif ch.get("text_when", "before") == "before":
		ctx = "play_before"
	else:
		ctx = "play_after"
	var r := get_tree().get_first_node_in_group("chapter_reader")
	if r != null:
		r.open_chapter(n, ctx)

func _shake(btn: Button) -> void:
	var x0: float = btn.position.x
	var t := btn.create_tween()
	t.tween_property(btn, "position:x", x0 - 6.0, 0.04)
	t.tween_property(btn, "position:x", x0 + 6.0, 0.06)
	t.tween_property(btn, "position:x", x0, 0.05)

func _on_gallery() -> void:
	Audio.play_ui_click()
	var r := get_tree().get_first_node_in_group("chapter_reader")
	if r != null:
		r.open_gallery()

func _on_retour() -> void:
	Audio.play_ui_click()
	visible = false

func _center_on_current() -> void:
	if _centers.is_empty():
		return
	var ci: int = clampi(Settings.story_chapter - 1, 0, _centers.size() - 1)
	var view_h: float = _scroll.size.y
	var target: float = _centers[ci].y - view_h * 0.5
	var max_s: float = maxf(0.0, _map.custom_minimum_size.y - view_h)
	_scroll.scroll_vertical = int(clampf(target, 0.0, max_s))
