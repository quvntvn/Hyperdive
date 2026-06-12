extends CanvasLayer
class_name ChapterReader
# Lecteur de chapitre IMMERSIF, partagé entre le flux campagne et la galerie (un seul écran,
# piloté par `_ctx`). Image plein fond (ou placeholder dégradé élégant si l'image manque),
# voiles dégradés pour la lisibilité du texte clair, titre + paragraphe, boutons contextuels,
# fondu cinématique à l'ouverture/fermeture.
#
# Contextes (_ctx) :
#   "story"       narration → bouton CONTINUER (complète + retour carte)
#   "play_before" jouable, intro → bouton JOUER (lance le niveau du chapitre)
#   "outro"       texte après une victoire (text_when "after") → CONTINUER (lecture seule, retour carte)
#   "gallery"     relecture → ◀ ▶ parmi les chapitres débloqués + RETOUR (aucune complétion)

signal chapter_closed(n: int)   # émis après complétion d'une narration (carte reconstruite / menu rafraîchi)
signal play_requested(n: int)   # JOUER sur un chapitre jouable → la carte lance le niveau

const FADE_TIME: float = 0.3

# Palette stricte Mid-Century (CLAUDE.md) — sert aux dégradés de placeholder (varient par chapitre).
const PALETTE: Array[Color] = [
	Color(0.914, 0.310, 0.216),   # orange brûlé
	Color(0.235, 0.682, 0.639),   # turquoise rétro
	Color(0.949, 0.757, 0.306),   # jaune moutarde
	Color(0.957, 0.914, 0.804),   # crème
	Color(0.486, 0.180, 0.165),   # bordeaux
	Color(0.122, 0.188, 0.369),   # bleu nuit
	Color(0.239, 0.173, 0.118),   # marron noyer
]
const DARK: Color = Color(0.05, 0.05, 0.09)   # base des voiles

var _n: int = 1
var _ctx: String = "story"
var _gallery: Array[int] = []
var _gallery_index: int = 0
var _scroll_fade: TextureRect      # fondu bas de zone de texte (signale du contenu en dessous)
var _scroll_chevron: Label         # chevron ▼ pulsant sous le texte (même signal, plus explicite)

@onready var _image_bg: TextureRect = $ImageBg
@onready var _placeholder_bg: TextureRect = $PlaceholderBg
@onready var _number: Label = $NumberLabel
@onready var _title: Label = $TitleLabel
@onready var _text_scroll: ScrollContainer = $TextScroll
@onready var _text: Label = $TextScroll/TextLabel
@onready var _action: Button = $ActionButton
@onready var _nav: HBoxContainer = $NavBox
@onready var _fade: ColorRect = $Fade

func _ready() -> void:
	add_to_group("chapter_reader")
	# Voiles dégradés (fixes) : haut sombre→transparent (titre), bas transparent→sombre (texte).
	$TopVeil.texture = _vertical_gradient(Color(DARK, 0.5), Color(DARK, 0.0))
	$BottomVeil.texture = _vertical_gradient(Color(DARK, 0.0), Color(DARK, 0.92))
	_action.pressed.connect(_on_action)
	$NavBox/PrevButton.pressed.connect(_on_prev)
	$NavBox/NextButton.pressed.connect(_on_next)
	$NavBox/BackButton.pressed.connect(_on_back)
	UIAnimations.wire_buttons(self)
	UIAnimations.apply_top_safe_area(_title, 24.0)
	_build_scroll_hint()
	# Le hint suit le scroll en continu (il disparaît une fois le bas atteint).
	_text_scroll.get_v_scroll_bar().value_changed.connect(
		func(_v: float) -> void: _update_scroll_hint())

# === Ouvertures ============================================================================

# Ouvre un chapitre dans le flux campagne. `ctx` = "story" | "play_before" | "play_after".
func open_chapter(n: int, ctx: String) -> void:
	_ctx = ctx
	_n = n
	_show_content(n)
	_configure_buttons()
	visible = true
	_fade_in()

# Ouvre la galerie : navigation parmi les chapitres DÉBLOQUÉS uniquement (verrouillés sautés).
func open_gallery() -> void:
	_ctx = "gallery"
	_gallery.clear()
	for n in range(1, Story.chapter_count() + 1):
		if Story.is_unlocked(n):
			_gallery.append(n)
	if _gallery.is_empty():
		_gallery.append(1)
	_gallery_index = 0
	_n = _gallery[0]
	_show_content(_n)
	_configure_buttons()
	visible = true
	_fade_in()

# === Contenu ===============================================================================

func _show_content(n: int) -> void:
	var ch: Dictionary = Story.get_chapter(n)
	_title.text = ch.get("title", "Chapitre %d" % n)
	_text.text = ch.get("text", "")
	_text_scroll.scroll_vertical = 0
	_refresh_scroll_hint()
	# Image plein fond si le fichier existe, sinon placeholder dégradé + numéro (jamais cassé).
	var img_path: String = ch.get("image", "")
	if img_path != "" and ResourceLoader.exists(img_path):
		_image_bg.texture = load(img_path)
		_image_bg.visible = true
		_placeholder_bg.visible = false
		_number.visible = false
	else:
		_image_bg.visible = false
		_placeholder_bg.texture = _placeholder_gradient(n)
		_placeholder_bg.visible = true
		_number.text = "%02d" % n
		_number.visible = true

func _configure_buttons() -> void:
	var gallery: bool = _ctx == "gallery"
	_nav.visible = gallery
	_action.visible = not gallery
	if gallery:
		$NavBox/PrevButton.disabled = _gallery_index <= 0
		$NavBox/NextButton.disabled = _gallery_index >= _gallery.size() - 1
	else:
		# JOUER pour une intro jouable, CONTINUER sinon (narration ou outro).
		_action.text = "JOUER" if _ctx == "play_before" else "CONTINUER"

# === Boutons ===============================================================================

func _on_action() -> void:
	Audio.play_ui_click()
	match _ctx:
		"play_before":
			await _request_play()   # JOUER → la carte lance le niveau (et fait la complétion à la victoire)
		"outro":
			await _close_only()     # texte déjà "complété" en jeu → simple retour carte
		_:                          # "story" : narration → lire = compléter
			await _complete_and_close()

func _complete_and_close() -> void:
	var n: int = _n
	await _fade_out()
	visible = false
	Story.complete_chapter(n)   # crédite pièces + déblocages (ch.1→Classique, ch.20→Jetpack) + avance
	chapter_closed.emit(n)

func _request_play() -> void:
	var n: int = _n
	await _fade_out()
	visible = false
	play_requested.emit(n)

func _close_only() -> void:
	await _fade_out()
	visible = false

func _on_prev() -> void:
	Audio.play_ui_click()
	if _gallery_index > 0:
		_gallery_index -= 1
		_n = _gallery[_gallery_index]
		_show_content(_n)
		_configure_buttons()

func _on_next() -> void:
	Audio.play_ui_click()
	if _gallery_index < _gallery.size() - 1:
		_gallery_index += 1
		_n = _gallery[_gallery_index]
		_show_content(_n)
		_configure_buttons()

func _on_back() -> void:
	Audio.play_ui_click()
	await _fade_out()
	visible = false

# === Fondu cinématique =====================================================================

func _fade_in() -> void:
	_fade.color.a = 1.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_QUAD)

func _fade_out() -> void:
	_fade.color.a = 0.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_QUAD)
	await t.finished

# === Indicateur de scroll ==================================================================
# Sur les chapitres longs, le texte est coupé et rien n'indiquait qu'on peut scroller (on
# ratait la fin sans le savoir). Deux signaux discrets, valables dans TOUS les contextes
# (narration/intro/outro/galerie) : un FONDU vers le sombre plaqué sur le bas de la zone de
# texte + un chevron ▼ à pulsation douce dessous. Les deux ne sont visibles que s'il reste
# du contenu sous le bord, et s'effacent dès qu'on atteint le bas du scroll.

func _build_scroll_hint() -> void:
	# Fondu : dégradé transparent → sombre PAR-DESSUS les dernières lignes (inséré juste après
	# TextScroll dans l'ordre de dessin → au-dessus du texte, sous les boutons et le Fade).
	_scroll_fade = TextureRect.new()
	_scroll_fade.texture = _vertical_gradient(Color(DARK, 0.0), Color(DARK, 0.95))
	_scroll_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scroll_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_fade.visible = false
	# Calé sur le BAS de TextScroll (ancré bas d'écran, bottom = -150 comme le .tscn).
	_scroll_fade.anchor_top = 1.0
	_scroll_fade.anchor_bottom = 1.0
	_scroll_fade.anchor_right = 1.0
	_scroll_fade.offset_top = -222.0
	_scroll_fade.offset_bottom = -150.0
	add_child(_scroll_fade)
	move_child(_scroll_fade, _text_scroll.get_index() + 1)

	_scroll_chevron = Label.new()
	_scroll_chevron.text = "▼"
	_scroll_chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_chevron.add_theme_font_size_override("font_size", 20)
	_scroll_chevron.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
	_scroll_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_chevron.visible = false
	# Dans la fine bande entre le bas du texte (-150) et le bouton d'action (-96).
	_scroll_chevron.anchor_top = 1.0
	_scroll_chevron.anchor_bottom = 1.0
	_scroll_chevron.anchor_right = 1.0
	_scroll_chevron.offset_top = -146.0
	_scroll_chevron.offset_bottom = -110.0
	add_child(_scroll_chevron)
	move_child(_scroll_chevron, _text_scroll.get_index() + 2)
	# Pulsation douce en boucle (respiration, pas un clignotement). Tourne même caché : coût
	# nul (un float), et le chevron réapparaît toujours en phase.
	var tw := create_tween().set_loops()
	tw.tween_property(_scroll_chevron, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_scroll_chevron, "modulate:a", 0.95, 0.8).set_trans(Tween.TRANS_SINE)

# La hauteur réelle du label (autowrap) n'est connue qu'après une frame de layout → on
# diffère la première évaluation (appelé à chaque _show_content, donc aussi en galerie).
func _refresh_scroll_hint() -> void:
	await get_tree().process_frame
	_update_scroll_hint()

func _update_scroll_hint() -> void:
	if _scroll_fade == null:
		return
	var bar: VScrollBar = _text_scroll.get_v_scroll_bar()
	# Reste-t-il du contenu sous le bord bas ? (marge 4 px : tolérance d'arrondi)
	var more: bool = bar.max_value - bar.page - bar.value > 4.0
	_scroll_fade.visible = more
	_scroll_chevron.visible = more

# === Dégradés ==============================================================================

# Texture dégradé VERTICAL (haut → bas). Sert aux voiles et au placeholder.
func _vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex

# Placeholder élégant : si le chapitre a un THÈME imposé (arc visuel narratif), dégradé tiré
# de ses couleurs de ciel (l'ambiance du chapitre transparaît dès la lecture) ; sinon repli
# sur un dégradé DIAGONAL entre 2 couleurs de la palette choisies de façon DÉTERMINISTE selon
# le n° de chapitre. Assombri dans les deux cas pour que le titre/texte clair ressortent.
func _placeholder_gradient(n: int) -> GradientTexture2D:
	var c1: Color
	var c2: Color
	var theme_id: String = Story.chapter_theme_id(n)
	if theme_id != "":
		var th: Dictionary = Catalog.get_theme(theme_id)
		c1 = (th["sky_top"] as Color).lerp(DARK, 0.35)
		c2 = (th["sky_horizon"] as Color).lerp(DARK, 0.45)
	else:
		var i1: int = (n * 2) % PALETTE.size()
		var i2: int = (n * 2 + 3) % PALETTE.size()
		if i2 == i1:
			i2 = (i2 + 1) % PALETTE.size()
		c1 = PALETTE[i1].lerp(DARK, 0.45)
		c2 = PALETTE[i2].lerp(DARK, 0.70)
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 1.0)
	return tex
