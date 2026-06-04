extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _coin_label: Label
var _campaign_mode: bool = false
# Pastilles power-up : un widget par type (icone coloree + barre de compte a rebours).
# Cle = type, valeur = { "root": PanelContainer, "bar": ProgressBar }.
var _pills: Dictionary = {}

# ── Classement live coop (en jeu) ─────────────────────────────────────────────
const COOP_GOLD := Color(0.949, 0.757, 0.306)
const COOP_CREAM := Color(0.957, 0.914, 0.804)
const COOP_OUTLINE := Color(0.04, 0.02, 0.01, 0.92)

var _coop_active: bool = false
var _coop_box: VBoxContainer                 # conteneur des rangees (dans InfoBar/VBox)
var _coop_rows: Dictionary = {}              # joueur -> { root, name, score, crown }
var _coop_order: Array = []                  # ordre d'affichage courant (indices joueurs)
var _coop_cur: int = 0                       # joueur courant (celui qui joue)
var _coop_round: int = 0
var _coop_first_player: bool = false         # current_player == 0 -> aucun effet (rien a battre)
var _coop_done: Array = []                   # joueurs ayant deja joue cette manche (indices < cur)
var _coop_final: Dictionary = {}             # joueur deja joue -> score final de la manche
var _coop_passed: Dictionary = {}            # joueur deja DEPASSE ce tour (flash une seule fois)
var _coop_crown_holder: int = -1             # joueur actuellement couronne (leader)

# Couleurs par type (memes teintes que les power-up 3D).
const PILL_COLORS: Dictionary = {
	"shield": Color(0.235, 0.682, 0.639, 1.0),
	"boost": Color(0.914, 0.310, 0.216, 1.0),
	"slowmo": Color(0.612, 0.796, 0.906, 1.0),
	"magnet": Color(0.949, 0.757, 0.306, 1.0),
}
const PILL_NAMES: Dictionary = {
	"shield": "BOUCLIER", "boost": "BOOST", "slowmo": "RALENTI", "magnet": "AIMANT",
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
	# Le contenu du VBox change (1 ou 2 lignes) → recaler la hauteur du fond (différé : la
	# taille mini du conteneur se met à jour après le toggle de visibilité).
	_resize_info_bar.call_deferred()

# Coop : remplace l'affichage solo (distance + pièces) par un CLASSEMENT LIVE — une rangée par
# joueur, triée par score décroissant en temps réel. Le joueur courant voit son score monter et
# sa position bouger ; les autres affichent leur score final (déjà joué) ou "..." (pas encore).
func set_coop_mode() -> void:
	_coop_active = true
	_distance_label.visible = false
	$InfoBar/VBox/CoinCounter.visible = false
	# Élargir l'InfoBar : noms + scores demandent plus de largeur que le seul score solo.
	($InfoBar as Panel).offset_left = -300.0

	_coop_cur = Coop.current_player
	_coop_round = Coop.current_round
	_coop_first_player = (_coop_cur == 0)   # 1er à jouer cette manche → personne à battre
	_coop_done = []
	_coop_final = {}
	_coop_passed = {}
	_coop_crown_holder = -1
	for p in range(Coop.num_players):
		if p < _coop_cur:   # ordre de jeu = ordre d'index → joueurs avant le courant ont déjà joué
			_coop_done.append(p)
			_coop_final[p] = int(Coop.scores[p][_coop_round])

	_build_coop_rows()
	_coop_order = _compute_coop_order(0)
	_apply_coop_order()
	# Couronne de départ : le meilleur des joueurs déjà passés (silencieuse). Jamais pour le 1er.
	if not _coop_first_player:
		_set_coop_crown(_coop_order[0])
		_coop_crown_holder = _coop_order[0]
	_resize_info_bar.call_deferred()

func _build_coop_rows() -> void:
	_coop_box = VBoxContainer.new()
	_coop_box.add_theme_constant_override("separation", 3)
	$InfoBar/VBox.add_child(_coop_box)
	_coop_rows = {}
	for p in range(Coop.num_players):
		var row := _make_coop_row(p)
		_coop_box.add_child(row["root"])
		_coop_rows[p] = row

func _make_coop_row(p: int) -> Dictionary:
	var col: Color = Coop.player_color(p)
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _coop_row_style(false))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var crown := _coop_label("", 18, Color.WHITE, 22.0)
	var name_lbl := _coop_label(Coop.player_names[p], 20, col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	var score_lbl := _coop_label("", 20, COOP_CREAM)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Texte initial : joueurs déjà passés = score final ; pas encore joué = "..." ; courant = 0.
	if p < _coop_cur:
		score_lbl.text = UIAnimations.format_number(_coop_final[p])
	elif p > _coop_cur:
		score_lbl.text = "…"
	else:
		score_lbl.text = "0"
	hb.add_child(crown)
	hb.add_child(name_lbl)
	hb.add_child(score_lbl)
	root.add_child(hb)
	return {"root": root, "name": name_lbl, "score": score_lbl, "crown": crown}

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

# Style d'une rangée : transparent par défaut ; liseré + fond dorés quand le joueur est leader.
func _coop_row_style(crowned: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	if crowned:
		sb.bg_color = Color(COOP_GOLD.r, COOP_GOLD.g, COOP_GOLD.b, 0.18)
		sb.set_border_width_all(2)
		sb.border_color = COOP_GOLD
	else:
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
	for p in range(Coop.num_players):
		if p > _coop_cur:
			order.append(p)
	return order

func _apply_coop_order() -> void:
	for i in range(_coop_order.size()):
		_coop_box.move_child(_coop_rows[_coop_order[i]]["root"], i)

func _update_coop_ranking() -> void:
	var live: int = int(abs(_player.global_position.y))
	(_coop_rows[_coop_cur]["score"] as Label).text = UIAnimations.format_number(live)

	# Effets seulement à partir du 2e joueur (le 1er n'a personne à dépasser).
	if not _coop_first_player:
		# Dépassement : à chaque joueur déjà passé que l'on franchit (une fois), flash + son + vibration.
		for d in _coop_done:
			if not _coop_passed.has(d) and live > _coop_final[d]:
				_coop_passed[d] = true
				Audio.play_coop_overtake()
				Settings.vibrate(30)
				_flash_coop_row(_coop_cur)
				_flash_coop_row(d)

	var order: Array = _compute_coop_order(live)
	if order != _coop_order:
		_coop_order = order
		_apply_coop_order()

	# Couronne = leader (tête du classement). Quand le COURANT prend la tête → son + flash + couronne.
	if not _coop_first_player:
		var leader: int = order[0]
		if leader != _coop_crown_holder:
			_set_coop_crown(leader)
			if leader == _coop_cur:
				Audio.play_coop_lead()
				Settings.vibrate(30)
				_flash_coop_row(_coop_cur)
			_coop_crown_holder = leader

# Pose la couronne (liseré doré + 👑) sur le joueur p, la retire des autres.
func _set_coop_crown(p: int) -> void:
	for pp in _coop_rows:
		var on: bool = (pp == p)
		(_coop_rows[pp]["root"] as PanelContainer).add_theme_stylebox_override("panel", _coop_row_style(on))
		(_coop_rows[pp]["crown"] as Label).text = "👑" if on else ""

# Flash d'une rangée : petit "punch" d'échelle (lisible même sans HDR sur mobile).
func _flash_coop_row(p: int) -> void:
	var root := _coop_rows[p]["root"] as Control
	root.pivot_offset = root.size / 2.0
	root.scale = Vector2(1.12, 1.12)
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_campaign_time(seconds: float) -> void:
	_distance_label.text = str(ceili(seconds)) + "s"

func _process(_delta: float) -> void:
	if _player == null:
		return
	if _coop_active:
		_update_coop_ranking()
	elif not _campaign_mode:
		_distance_label.text = UIAnimations.format_number(int(abs(_player.global_position.y))) + " m"
	_update_powerup_indicator()

# Construit les 4 pastilles (cachees par defaut). Ordre d'empilement bas-gauche.
func _build_powerup_pills() -> void:
	var container := $PowerupIndicator as VBoxContainer
	for type: String in ["shield", "boost", "slowmo", "magnet"]:
		var timed: bool = type != "shield"   # le bouclier n'a pas de timer
		var pill := _make_pill(PILL_COLORS[type], PILL_NAMES[type], timed)
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
	_set_pill("boost", _player.boost_timer > 0.0, _player.boost_timer / PlayerController.BOOST_DURATION)
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
	print("GAME OVER")

func _on_coin_collected(new_total: int) -> void:
	_coin_label.text = UIAnimations.format_number(new_total)

func _on_pause_pressed() -> void:
	Audio.play_ui_click()
	var pause := get_tree().get_first_node_in_group("pause_screen")
	if pause:
		pause.open()
