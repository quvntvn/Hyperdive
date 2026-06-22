extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _coin_label: Label
var _campaign_mode: bool = false
var _progress_urgent: bool = false   # altimètre "descent" passé en orange (état → pas de réécriture/frame)
# Pastilles power-up : un widget par type (icone coloree + barre de compte a rebours).
# Cle = type, valeur = { "root": PanelContainer, "bar": ProgressBar }.
var _pills: Dictionary = {}

# ── Classement live coop (en jeu) ─────────────────────────────────────────────
const COOP_GOLD := Color(0.949, 0.757, 0.306)
const COOP_CREAM := Color(0.957, 0.914, 0.804)
const COOP_OUTLINE := Color(0.04, 0.02, 0.01, 0.92)
# Couronne en ICÔNE (l'emoji 👑 ne rend pas sous Android : Poppins n'a pas les emojis).
const CROWN_TEX: Texture2D = preload("res://assets/ui/crown_icon.svg")

var _coop_active: bool = false
var _coop_box: VBoxContainer                 # conteneur des rangees (dans InfoBar/VBox)
var _coop_rows: Dictionary = {}              # joueur -> { root, name, score, crown }
var _coop_order: Array = []                  # ordre d'affichage courant (indices joueurs)
var _coop_cur: int = 0                       # joueur courant (celui qui joue)
var _coop_players: Array = []                # joueurs concernes par ce tour (tous, ou ex-aequo en tiebreak)
var _coop_done: Array = []                   # joueurs ayant deja joue ce tour-round
var _coop_pending: Array = []                # joueurs pas encore joues ce tour-round ("...")
var _coop_final: Dictionary = {}             # joueur deja joue -> son score de ce tour-round
var _coop_passed: Dictionary = {}            # joueur deja DEPASSE ce tour (flash une seule fois)

# Couleurs par type (memes teintes que les power-up 3D).
const PILL_COLORS: Dictionary = {
	"shield": Color(0.235, 0.682, 0.639, 1.0),
	"boost": Color(0.914, 0.310, 0.216, 1.0),
	"slowmo": Color(0.612, 0.796, 0.906, 1.0),
	"magnet": Color(0.949, 0.757, 0.306, 1.0),
	"megaboost": Color(0.69, 0.149, 1.0, 1.0),   # magenta/violet #B026FF
}
# Valeurs = CLÉS de traduction (le libellé est résolu via tr() à la construction des pastilles).
const PILL_NAMES: Dictionary = {
	"shield": "HUD_PU_SHIELD", "boost": "HUD_PU_BOOST", "slowmo": "HUD_PU_SLOWMO",
	"magnet": "HUD_PU_MAGNET", "megaboost": "HUD_PU_MEGABOOST",
}

func _ready() -> void:
	var node := get_node_or_null(player_path)
	if node is PlayerController:
		_player = node as PlayerController
		_player.game_over.connect(_on_game_over)
	_distance_label = $InfoBar/VBox/DistanceLabel
	_coin_label = $InfoBar/VBox/CoinCounter/CoinLabel
	_build_powerup_pills()
	_coin_label.text = UIAnimations.format_number(Settings.coins_total)
	Settings.coin_collected.connect(_on_coin_collected)
	%PauseButton.pressed.connect(_on_pause_pressed)
	# Bandeau d'infos en verre flouté (score + pièces sur la même rangée), comme les boutons.
	$InfoBar.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	GlassBlur.add_behind($InfoBar)
	UIAnimations.wire_buttons(self)   # feedback + haptique sur le bouton pause
	# Descend les éléments hauts du HUD sous la safe area (encoche/caméra frontale).
	UIAnimations.apply_top_safe_area($InfoBar, 12.0)
	UIAnimations.apply_top_safe_area(%PauseButton, 12.0)
	# Hauteur adaptative : recalée après le 1er layout (largeur fixe en scène, hauteur = contenu).
	_resize_info_bar.call_deferred()

# Largeur FIXE (offsets gauche/droite de la scène) ; hauteur ADAPTÉE au contenu visible du VBox
# (2 lignes en classique/jetpack, 1 ligne en campagne quand les pièces sont masquées). Le
# GlassBlur plein-rect derrière suit cette hauteur et recalcule son masque sur 'resized'.
func _resize_info_bar() -> void:
	var bar := $InfoBar as Panel
	var vbox := $InfoBar/VBox as Control
	var content_h: float = vbox.get_combined_minimum_size().y
	bar.offset_bottom = bar.offset_top + content_h + 16.0   # +16 = padding vertical (8 haut + 8 bas)

func set_campaign_mode(enabled: bool) -> void:
	_campaign_mode = enabled
	$InfoBar/VBox/CoinCounter.visible = not enabled
	# Progression d'objectif plus SOBRE : même taille que les noms du HUD coop (20, vs 36 par
	# défaut du score solo) → la ligne "320 / 800 m" ne mange plus le haut de l'écran.
	if enabled:
		_distance_label.add_theme_font_size_override("font_size", 20)
	# Le contenu du VBox change (1 ou 2 lignes) → recaler la hauteur du fond (différé : la
	# taille mini du conteneur se met à jour après le toggle de visibilité).
	_resize_info_bar.call_deferred()

# Coop : remplace l'affichage solo (distance + pièces) par un CLASSEMENT LIVE — une rangée par
# joueur concerné, triée par score décroissant en temps réel. Le joueur courant voit son score
# monter et sa position bouger ; les autres affichent leur score (déjà joué) ou "…" (pas encore).
# Lit le CONTEXTE DE TOUR de Coop → marche en manche normale ET en round final (tiebreak : seuls
# les ex-æquo apparaissent).
func set_coop_mode() -> void:
	_coop_active = true
	_distance_label.visible = false
	$InfoBar/VBox/CoinCounter.visible = false
	# Élargir l'InfoBar : noms + scores demandent plus de largeur que le seul score solo.
	($InfoBar as Panel).offset_left = -300.0

	_coop_cur = Coop.turn_current_player()
	_coop_players = Coop.turn_players()
	_coop_done = Coop.turn_done_players()
	_coop_pending = Coop.turn_pending_players()
	_coop_final = {}
	for p in _coop_done:
		_coop_final[p] = Coop.turn_score(p)
	_coop_passed = {}

	_build_coop_rows()
	_coop_order = _compute_coop_order(0)
	_apply_coop_order()
	_refresh_coop_ranks()   # rangs initiaux (couronne au meilleur déjà passé, silencieuse)
	_resize_info_bar.call_deferred()

func _build_coop_rows() -> void:
	_coop_box = VBoxContainer.new()
	_coop_box.add_theme_constant_override("separation", 3)
	$InfoBar/VBox.add_child(_coop_box)
	_coop_rows = {}
	for p in _coop_players:
		var row := _make_coop_row(p)
		_coop_box.add_child(row["root"])
		_coop_rows[p] = row

func _make_coop_row(p: int) -> Dictionary:
	var col: Color = Coop.player_color(p)
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _coop_row_style())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	# Colonne de rang à gauche : icône couronne pour le leader, chiffre sinon (l'un OU l'autre
	# visible, géré par _refresh_coop_ranks). Mêmes largeurs → le nom reste aligné.
	var rank_crown := TextureRect.new()
	rank_crown.texture = CROWN_TEX
	rank_crown.custom_minimum_size = Vector2(26, 22)
	rank_crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rank_crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rank_crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_crown.visible = false
	var rank_num := _coop_label("", 18, COOP_CREAM, 26.0)
	rank_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_lbl := _coop_label(Coop.player_names[p], 20, col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	var score_lbl := _coop_label("", 20, COOP_CREAM)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Texte initial : déjà joué = son score ; pas encore joué = "…" ; courant = 0 (montera en live).
	if p in _coop_done:
		score_lbl.text = UIAnimations.format_number(int(_coop_final[p]))
	elif p == _coop_cur:
		score_lbl.text = "0"
		# Score du joueur EN COURS → liseré blanc FIN pour le distinguer sans noyer les chiffres.
		score_lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		score_lbl.add_theme_constant_override("outline_size", 2)
	else:
		score_lbl.text = "…"
	hb.add_child(rank_crown)
	hb.add_child(rank_num)
	hb.add_child(name_lbl)
	hb.add_child(score_lbl)
	root.add_child(hb)
	return {"root": root, "name": name_lbl, "score": score_lbl, "rank_num": rank_num, "rank_crown": rank_crown}

func _coop_label(text: String, size: int, color: Color, min_w: float = 0.0) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", COOP_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if min_w > 0.0:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	return lbl

# Style d'une rangée : fond transparent pour TOUTES (le leader se distingue uniquement par la
# couronne devant son nom, plus de liseré ni de fond doré).
func _coop_row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	return sb

# Ordre d'affichage : joueurs AVEC un score (déjà passés + courant en live) triés décroissant
# (égalité → le joueur courant devant), puis joueurs PAS ENCORE passés (en bas, ordre d'index).
func _compute_coop_order(live: int) -> Array:
	var scored: Array = []
	for d in _coop_done:
		scored.append([_coop_final[d], d, false])
	scored.append([live, _coop_cur, true])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[2] != b[2]:
			return a[2]            # à score égal, le joueur courant passe devant
		return a[1] < b[1])
	var order: Array = []
	for e in scored:
		order.append(e[1])
	for p in _coop_pending:   # pas encore joués → en bas, sans score
		order.append(p)
	return order

func _apply_coop_order() -> void:
	for i in range(_coop_order.size()):
		_coop_box.move_child(_coop_rows[_coop_order[i]]["root"], i)

func _update_coop_ranking() -> void:
	var live: int = int(abs(_player.global_position.y))
	(_coop_rows[_coop_cur]["score"] as Label).text = UIAnimations.format_number(live)

	# Dépassement : à chaque joueur déjà passé que l'on franchit (une fois), flash + son + vibration.
	# _coop_done est vide pour le 1er joueur d'une manche → aucun dépassement (rien à dépasser),
	# mais la couronne du rang 1 s'affiche quand même (gérée par _refresh_coop_ranks).
	for d in _coop_done:
		if not _coop_passed.has(d) and live > _coop_final[d]:
			_coop_passed[d] = true
			Audio.play_coop_overtake()
			Settings.vibrate(30)
			_flash_coop_row(_coop_cur)
			_flash_coop_row(d)

	var order: Array = _compute_coop_order(live)
	if order != _coop_order:
		var prev_leader: int = _coop_order[0] if not _coop_order.is_empty() else -1
		_coop_order = order
		_apply_coop_order()
		_refresh_coop_ranks()   # rangs (couronne/chiffres) + liseré doré suivent le nouvel ordre
		# Prise de tête par le COURANT (transition) → son + flash.
		if order[0] == _coop_cur and prev_leader != _coop_cur:
			Audio.play_coop_lead()
			Settings.vibrate(30)
			_flash_coop_row(_coop_cur)

# Rang à gauche de chaque rangée selon l'ordre courant : 👑 pour le leader (rang 1, pour TOUS
# y compris le 1er joueur de la manche), chiffre sinon. Liseré doré sur le seul leader. Unifie
# rang + couronne (pas de doublon de couronne sur la ligne).
func _refresh_coop_ranks() -> void:
	for i in range(_coop_order.size()):
		var p: int = _coop_order[i]
		var is_leader: bool = (i == 0)
		(_coop_rows[p]["rank_crown"] as TextureRect).visible = is_leader
		var num := _coop_rows[p]["rank_num"] as Label
		num.visible = not is_leader
		num.text = str(i + 1)

# Flash d'une rangée : petit "punch" d'échelle (lisible même sans HDR sur mobile).
func _flash_coop_row(p: int) -> void:
	var root := _coop_rows[p]["root"] as Control
	root.pivot_offset = root.size / 2.0
	root.scale = Vector2(1.12, 1.12)
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_campaign_time(seconds: float) -> void:
	_distance_label.text = str(ceili(seconds)) + "s"

# Progression vers l'objectif d'un chapitre HISTOIRE ("320 / 800 m", "12 / 24 s", "8 / 15 esquives")
# — ou l'ALTIMÈTRE décroissant de l'ouverture "descent" ("240 m" → "0 m").
# Réutilise le label de distance (mode campagne actif → l'auto-distance de _process est figée).
func update_story_progress(text: String) -> void:
	_distance_label.text = text

# Tension de l'altimètre "descent" : sous le seuil, la valeur passe en orange brûlé (le sol
# approche).
func set_story_progress_urgent(urgent: bool) -> void:
	if urgent == _progress_urgent:
		return
	_progress_urgent = urgent
	if urgent:
		_distance_label.add_theme_color_override("font_color", Color(0.914, 0.310, 0.216))
	else:
		_distance_label.remove_theme_color_override("font_color")

func _process(_delta: float) -> void:
	if _player == null:
		return
	if _coop_active:
		_update_coop_ranking()
	elif not _campaign_mode:
		# [i18n lot 0] Nombre + unité : le NOMBRE garde son formatage (séparateur de milliers,
		# logique inchangée), seul le GABARIT "%s m" passe par tr() → une langue future pourrait
		# déplacer/changer l'unité sans toucher au code. Relu chaque frame ici → bascule live gratuite
		# (pas besoin du signal). NB : "m" est identique FR/EN par choix (mètres conservés).
		_distance_label.text = tr("HUD_DISTANCE_FMT") % UIAnimations.format_number(int(abs(_player.global_position.y)))
	_update_powerup_indicator()

# Construit les 4 pastilles (cachees par defaut). Ordre d'empilement bas-gauche.
func _build_powerup_pills() -> void:
	var container := $PowerupIndicator as VBoxContainer
	for type: String in ["shield", "boost", "megaboost", "slowmo", "magnet"]:
		var timed: bool = type != "shield"   # le bouclier n'a pas de timer
		var pill := _make_pill(PILL_COLORS[type], tr(PILL_NAMES[type]), timed)
		container.add_child(pill["root"])
		_pills[type] = pill

func _make_pill(color: Color, text: String, timed: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	panel.visible = false
	var mc := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(side, 10)
	panel.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	mc.add_child(vb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	vb.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150.0, 8.0)
	bar.visible = timed
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1.0, 1.0, 1.0, 0.15)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	vb.add_child(bar)
	return {"root": panel, "bar": bar}

func _update_powerup_indicator() -> void:
	_set_pill("shield", _player.has_shield, 1.0)
	# Boost et méga-boost partagent boost_timer ; boost_is_mega choisit quelle pastille afficher
	# (chacune avec sa durée max → barre correcte) pour distinguer l'orange du magenta.
	var mega: bool = _player.boost_is_mega
	_set_pill("boost", _player.boost_timer > 0.0 and not mega, _player.boost_timer / PlayerController.BOOST_DURATION)
	_set_pill("megaboost", _player.boost_timer > 0.0 and mega, _player.boost_timer / PlayerController.MEGA_BOOST_DURATION)
	_set_pill("slowmo", _player.slowmo_timer > 0.0, _player.slowmo_timer / PlayerController.SLOWMO_DURATION)
	_set_pill("magnet", _player.magnet_timer > 0.0, _player.magnet_timer / PlayerController.MAGNET_DURATION)

func _set_pill(type: String, active: bool, frac: float) -> void:
	var pill: Dictionary = _pills.get(type, {})
	if pill.is_empty():
		return
	var root := pill["root"] as PanelContainer
	root.visible = active
	if active:
		var bar := pill["bar"] as ProgressBar
		if bar.visible:
			bar.value = clampf(frac, 0.0, 1.0)

func _on_game_over() -> void:
	pass

func _on_coin_collected(new_total: int) -> void:
	_coin_label.text = UIAnimations.format_number(new_total)

func _on_pause_pressed() -> void:
	Audio.play_ui_click()
	var pause := get_tree().get_first_node_in_group("pause_screen")
	if pause:
		pause.open()
