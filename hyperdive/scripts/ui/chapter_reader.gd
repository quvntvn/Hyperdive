extends CanvasLayer
class_name ChapterReader
# Lecteur de chapitre IMMERSIF, partagé entre le flux campagne et la galerie (un seul écran,
# piloté par `_ctx`). Image plein fond (ou placeholder dégradé élégant si l'image manque),
# voiles dégradés pour la lisibilité du texte clair, titre + paragraphe, boutons contextuels,
# fondu cinématique à l'ouverture/fermeture.
#
# Contextes (_ctx) :
#   "story"       narration → bouton CONTINUER (complète + retour carte)
#   "play_before" jouable, intro → bouton JOUER (étape 2 : stub complète ; étape 3 : lance le niveau)
#   "play_after"  jouable, outro → bouton CONTINUER (complète + retour carte)
#   "gallery"     relecture → ◀ ▶ parmi les chapitres débloqués + RETOUR (aucune complétion)

signal chapter_closed(n: int)   # émis après complétion (la carte se reconstruit / le menu rafraîchit)

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
	# STUB ÉTAPE 2 : tous les contextes complètent directement pour tester la progression.
	# ÉTAPE 3 : "play_before" ne complétera PLUS ici — il lancera le niveau jouable
	#   (Settings.active_mode = mode du chapitre + objectif Story, puis Transition.change_scene),
	#   et la complétion se fera à la réussite du niveau (puis outro via open_chapter "play_after").
	await _complete_and_close()

func _complete_and_close() -> void:
	var n: int = _n
	await _fade_out()
	visible = false
	Story.complete_chapter(n)   # crédite pièces + déblocages (ch.1→Classique, ch.20→Jetpack) + avance
	chapter_closed.emit(n)

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

# Placeholder élégant : dégradé DIAGONAL entre 2 couleurs de la palette choisies de façon
# DÉTERMINISTE selon le n° de chapitre (assombries pour que le titre/texte clair ressortent).
func _placeholder_gradient(n: int) -> GradientTexture2D:
	var i1: int = (n * 2) % PALETTE.size()
	var i2: int = (n * 2 + 3) % PALETTE.size()
	if i2 == i1:
		i2 = (i2 + 1) % PALETTE.size()
	var c1: Color = PALETTE[i1].lerp(DARK, 0.45)
	var c2: Color = PALETTE[i2].lerp(DARK, 0.70)
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
