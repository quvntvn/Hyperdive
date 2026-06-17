extends Node
class_name Tutorial
# Surcouche DIDACTICIEL — vit UNIQUEMENT au chapitre tuto (Story.is_tutorial(), ch.1 « 2028 »).
# Greffée par main_game PAR-DESSUS la descente scriptée (le sol à 200 m reste la victoire).
# Possède son propre CanvasLayer (au-dessus du HUD, sous la pause).
#
# Deux pilotes distincts :
#   • TEXTE 1 + FLÈCHE ↔  → pilotés par le 1er INPUT (ralenti d'intro 0.025× tant que rien, puis
#     coupé ; texte 1 tenu un court instant puis fondu ; la flèche s'estompe AVEC le texte 1).
#   • TEXTE 2 + RANGÉES de power-up + TEXTE 3 → pilotés par des SEUILS D'ALTITUDE (altimètre
#     restant = floor − |y|), pas par des minuteries : une rangée slow-time inratable à ~120 m,
#     le texte 2 juste avant (~130 m), le texte 3 « La mort est inévitable » à ~45 m
#     (reste jusqu'à l'impact).
#
# Détection du 1er input : signal PlayerController.first_input_received (point unique côté joueur,
# touch ET clavier) → garantie que le ralenti 0.025× se coupe TOUJOURS.

const INTRO_SPEED_FACTOR := 0.025   # info : la valeur effective vit dans PlayerController.TUTORIAL_INTRO_FACTOR
const TEXT1_HOLD_AFTER_INPUT := 2.0 # le texte 1 reste 2 s après le 1er input puis se fond
const FADE := 0.5                   # durée des fondus de texte
const FONT_SIZE := 29               # taille de police des textes (réduite ~15 % depuis 34)
const PULSE_MIN := 1.0              # échelle de pulsation basse
const PULSE_MAX := 1.08            # échelle de pulsation haute
const PULSE_PERIOD := 1.2          # période de la pulsation (s)

# Seuils d'ALTITUDE (mètres restants avant le sol) : chaque événement se déclenche une fois quand
# l'altimètre restant passe sous le seuil. Monotone décroissant → ordre garanti.
const TEXT2_AT_M := 130.0          # texte 2 « Attrape les bonus ! » (juste avant la rangée)
const ROW1_AT_M := 120.0           # rangée de power-up slow-time (unique)
const TEXT2_FADE_AT_M := 95.0      # fondu du texte 2
const TEXT3_AT_M := 45.0           # texte 3 « La mort est inévitable » (reste jusqu'à l'impact)

const ROW_LEAD := 14.0             # rangée posée à 14 m devant (dir) le joueur au déclenchement
const ROW_CLEAR_HALF := 8.0        # demi-bande sans obstacle autour de la rangée
const ROW_X_MIN := -5.0            # rangée pleine largeur (couloir = ±4,5)
const ROW_X_MAX := 5.0
const ROW_X_STEP := 1.0            # espacement (catch ~1 m/powerup → inratable)
const TUTORIAL_OBSTACLES_ENABLED := true   # false = aucun obstacle pendant le tuto

# Flèche directionnelle ↔ (Polygon2D blanc plein, sans contour) affichée pendant l'intro pour
# signaler « déplace-toi gauche/droite ». FINE et EFFILÉE. Taille + position via ces constantes.
const ARROW_LENGTH := 240.0        # longueur totale pointe-à-pointe (px GUI)
const ARROW_THICKNESS := 12.0      # épaisseur de la hampe (px) — fine
const ARROW_HEAD_LENGTH := 60.0    # longueur de chaque tête triangulaire (px) — allongée
const ARROW_HEAD_HALF := 22.0      # demi-hauteur des têtes (px) — étroite → pointe effilée
const ARROW_Y_FRAC := 0.85         # centre vertical à 15 % du BAS de l'écran (0=haut → 1=bas)
const ARROW_ALPHA_MIN := 0.05      # alpha au creux de la pulsation (texte au plus petit)
const ARROW_ALPHA_MAX := 0.25      # alpha au pic de la pulsation (texte au plus grand)

# Textes placeholder ÉDITABLES. Variante texte 1 selon le mode de contrôle (tilt supprimé du jeu).
const TEXT1_TOUCH := "Glisse ton doigt pour te déplacer"
const TEXT1_KEY   := "Utilise ←  → pour te déplacer"
const TEXT2       := "Attrape les bonus !"
const TEXT3       := "La mort est inévitable"

const POWERUP_SCENE: PackedScene = preload("res://scenes/collectibles/powerup.tscn")

var _player: PlayerController
var _obstacles: ObstacleSpawner
var _floor_m: float = 200.0    # distance au sol (objectif descent) → base de l'altimètre restant
var _label: Label              # texte 1 puis texte 2 (séquentiels, jamais simultanés)
var _label3: Label             # texte 3 (persistant, dédié)
var _arrow: Polygon2D
var _arrow_fade: float = 0.0   # 0..1, fondu maître de la flèche (apparaît/s'estompe AVEC le texte 1)
var _pulse_tween: Tween
var _done: bool = false        # texte 2 montré (info ; en descent la victoire = collision au sol)
# Garde-fous « une seule fois » des seuils d'altitude.
var _did_text2: bool = false
var _did_row1: bool = false
var _did_text2_fade: bool = false
var _did_text3: bool = false

func is_done() -> bool:
	return _done

func setup(player: PlayerController, obstacles: ObstacleSpawner) -> void:
	_player = player
	_obstacles = obstacles
	_floor_m = float(Story.objective().get("value", 200))
	if not TUTORIAL_OBSTACLES_ENABLED and _obstacles != null:
		_obstacles.set_process(false)
	_build_ui()
	# Ralenti d'intro ON immédiatement + texte 1 (variante selon le mode de contrôle) + flèche ↔.
	_player.set_intro_slow(true)
	var touch: bool = Settings.control_mode == SettingsManager.ControlMode.TOUCH
	_show_text(TEXT1_TOUCH if touch else TEXT1_KEY)
	_show_arrow()
	# Abonnement FIABLE au 1er input (signal du joueur). Si l'input est déjà passé (cas limite),
	# on réagit tout de suite ; sinon on attend le signal.
	if _player.has_first_input():
		_on_first_input()
	else:
		_player.first_input_received.connect(_on_first_input)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2   # au-dessus du HUD (1), sous la pause (5)
	add_child(layer)
	_label = _make_label()
	layer.add_child(_label)
	_label3 = _make_label()
	layer.add_child(_label3)
	_build_arrow(layer)

# Fabrique un label centré au style tuto (police réduite, blanc translucide, liseré sombre).
func _make_label() -> Label:
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.anchor_left = 0.1
	lab.anchor_right = 0.9
	lab.anchor_top = 0.5
	lab.anchor_bottom = 0.5
	lab.offset_top = -90.0
	lab.offset_bottom = 90.0
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))   # blanc translucide
	lab.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.5))
	lab.add_theme_constant_override("outline_size", 6)
	lab.modulate.a = 0.0
	return lab

# Flèche bidirectionnelle ↔ : UN seul Polygon2D (hampe + 2 têtes), blanc plein, sans contour.
# Centrée horizontalement, basse (ARROW_Y_FRAC). Alpha via modulate.a.
func _build_arrow(layer: CanvasLayer) -> void:
	_arrow = Polygon2D.new()
	_arrow.color = Color(1.0, 1.0, 1.0, 1.0)   # blanc plein ; l'alpha effectif passe par modulate.a
	var hl: float = ARROW_LENGTH * 0.5
	var ht: float = ARROW_THICKNESS * 0.5
	var sx: float = hl - ARROW_HEAD_LENGTH      # x où commencent les têtes
	var hh: float = ARROW_HEAD_HALF
	# Contour fermé, sens horaire, depuis la pointe gauche.
	_arrow.polygon = PackedVector2Array([
		Vector2(-hl, 0.0),    # pointe gauche
		Vector2(-sx, -hh),    # tête gauche, haut
		Vector2(-sx, -ht),    # hampe, haut-gauche
		Vector2(sx, -ht),     # hampe, haut-droit
		Vector2(sx, -hh),     # tête droite, haut
		Vector2(hl, 0.0),     # pointe droite
		Vector2(sx, hh),      # tête droite, bas
		Vector2(sx, ht),      # hampe, bas-droit
		Vector2(-sx, ht),     # hampe, bas-gauche
		Vector2(-sx, hh),     # tête gauche, bas
	])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_arrow.position = Vector2(vp.x * 0.5, vp.y * ARROW_Y_FRAC)
	_arrow.modulate.a = 0.0
	layer.add_child(_arrow)

func _show_arrow() -> void:
	create_tween().tween_property(self, "_arrow_fade", 1.0, FADE)

func _fade_out_arrow() -> void:
	create_tween().tween_property(self, "_arrow_fade", 0.0, FADE)

func _show_text(t: String) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_label.text = t
	_label.scale = Vector2.ONE
	_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, FADE)
	_start_pulse()

# Texte 3 : fondu d'apparition puis RESTE (pas de pulsation, pas de fondu de sortie).
func _show_text3() -> void:
	_label3.text = TEXT3
	_label3.modulate.a = 0.0
	create_tween().tween_property(_label3, "modulate:a", 1.0, FADE)

# Pulsation centrée : le pivot doit être au CENTRE du label, mais sa taille n'est connue
# qu'APRÈS le 1er layout → on attend une frame (ou que size > 0) avant de poser pivot_offset.
func _start_pulse() -> void:
	await get_tree().process_frame
	while _label != null and _label.size == Vector2.ZERO:
		await get_tree().process_frame
	if _label == null:
		return
	_label.pivot_offset = _label.size / 2.0
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_label, "scale", Vector2.ONE * PULSE_MAX, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_label, "scale", Vector2.ONE * PULSE_MIN, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE)

func _fade_out_text() -> void:
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 0.0, FADE)
	tw.tween_callback(func() -> void:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill())

func _on_first_input() -> void:
	_player.set_intro_slow(false)   # vitesse normale, TOUJOURS, dès le 1er input
	# Le texte 1 reste TEXT1_HOLD_AFTER_INPUT puis se fond ; la flèche s'estompe AVEC lui.
	# La suite (texte 2 / rangées / texte 3) est pilotée par l'altitude, pas par minuterie.
	await get_tree().create_timer(TEXT1_HOLD_AFTER_INPUT).timeout
	_fade_out_text()
	_fade_out_arrow()

func _process(_delta: float) -> void:
	# Alpha de la flèche piloté par la MÊME pulsation que l'échelle du texte 1 : t reconstruit
	# depuis _label.scale (PULSE_MIN→0 … PULSE_MAX→1) → alpha lerp ARROW_ALPHA_MIN…MAX, le tout
	# multiplié par le fondu maître (_arrow_fade) pour l'apparition/l'estompage avec le texte 1.
	if _arrow != null and _label != null:
		var t: float = clampf((_label.scale.x - PULSE_MIN) / (PULSE_MAX - PULSE_MIN), 0.0, 1.0)
		_arrow.modulate.a = _arrow_fade * lerpf(ARROW_ALPHA_MIN, ARROW_ALPHA_MAX, t)
	if _player == null:
		return
	# Altimètre restant = pilote des étapes pédagogiques (chaque seuil une seule fois).
	var remaining: float = _floor_m - absf(_player.global_position.y)
	if not _did_text2 and remaining <= TEXT2_AT_M:
		_did_text2 = true
		_show_text(TEXT2)
		_done = true   # leçon montrée (info ; en descent la victoire = collision au sol)
	if not _did_row1 and remaining <= ROW1_AT_M:
		_did_row1 = true
		_spawn_slowmo_row()
	if not _did_text2_fade and remaining <= TEXT2_FADE_AT_M:
		_did_text2_fade = true
		_fade_out_text()
	if not _did_text3 and remaining <= TEXT3_AT_M:
		_did_text3 = true
		_show_text3()

# Rangée pleine largeur de slow-time, inratable, posée ROW_LEAD devant le joueur (dir-relatif).
# On nettoie une bande sans obstacle autour pour garantir le ramassage.
func _spawn_slowmo_row() -> void:
	var dir: float = Settings.get_fall_dir()   # -1 en chute (ch.1)
	var y: float = _player.global_position.y + dir * ROW_LEAD
	if _obstacles != null and TUTORIAL_OBSTACLES_ENABLED:
		_obstacles.reserve_clear_band(y - ROW_CLEAR_HALF, y + ROW_CLEAR_HALF)
	var x: float = ROW_X_MIN
	while x <= ROW_X_MAX + 0.001:
		var pu: Powerup = POWERUP_SCENE.instantiate()
		pu.type = "slowmo"
		get_parent().add_child(pu)   # parent = MainGame (même que les autres spawns)
		pu.global_position = Vector3(x, y, 0.0)
		x += ROW_X_STEP
