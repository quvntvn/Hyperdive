extends Control
class_name CoopFinal
# Écran FINAL d'une session coop : vainqueur (plus de points au total) mis en avant + podium
# top-3 + classement général complet. Boutons REJOUER (même config) / MENU.
# Structure fonctionnelle ; le podium ANIMÉ + confettis + son de victoire viennent au commit 5.

const TEXT_CREAM := Color(0.957, 0.914, 0.804)
const TEXT_GOLD := Color(0.949, 0.757, 0.306)
const TEXT_DIM := Color(0.80, 0.78, 0.72)
const PODIUM_MAX_H := 250.0
# Hauteurs des piliers par place (1er le plus haut).
const PILLAR_H := {1: 160.0, 2: 115.0, 3: 80.0}
# Couronne en icône (l'emoji 👑 ne rend pas sous Android).
const CROWN_TEX: Texture2D = preload("res://assets/ui/crown_icon.svg")

func _ready() -> void:
	if not Coop.active:
		Transition.change_scene("res://scenes/ui/main_menu.tscn")
		return
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	Audio.duck_music()   # écran hors gameplay → musique baissée (règle unique « plein en jeu »)
	_populate()
	$Content/ButtonsRow/RejouerButton.pressed.connect(_on_rejouer_pressed)
	$Content/ButtonsRow/MenuButton.pressed.connect(_on_menu_pressed)
	UIAnimations.wire_buttons(self)

func _populate() -> void:
	# final_standings : si départage, le vainqueur passe en tête (sinon classement par points).
	var standings: Array = Coop.final_standings()
	# Vainqueur (1er du classement général).
	var winner: Dictionary = standings[0]
	var wp: int = int(winner["player"])
	var wcol: Color = Coop.player_color(wp)
	$Content/WinnerName.text = Coop.player_names[wp]
	$Content/WinnerName.add_theme_color_override("font_color", wcol)
	$Content/WinnerPoints.text = "%d points" % int(winner["points"])
	# Score du vainqueur mis en avant par un liseré blanc FIN (lisible).
	$Content/WinnerPoints.add_theme_color_override("font_outline_color", Color.WHITE)
	$Content/WinnerPoints.add_theme_constant_override("outline_size", 2)

	_populate_best_score()
	_build_podium(standings)

	var box := $Content/ScrollContainer/StandingsBox as VBoxContainer
	for child in box.get_children():
		child.queue_free()
	var rank: int = 1
	for s in standings:
		box.add_child(_make_standing_row(rank, s))
		rank += 1

# Mise en avant honorifique : le(s) joueur(s) au meilleur score du tournoi (+1 point bonus
# déjà appliqué dans les standings). Plusieurs ex-æquo → noms joints. Couleur du joueur si seul.
func _populate_best_score() -> void:
	var lbl := $Content/BestScoreLabel as Label
	var players: Array = Coop.tournament_best_players
	if players.is_empty():
		lbl.visible = false
		return
	var score_txt: String = UIAnimations.format_number(Coop.tournament_best_score)
	if players.size() == 1:
		var p: int = int(players[0])
		lbl.text = "★ Meilleur score du tournoi : %s — %s m  (+1)" % [Coop.player_names[p], score_txt]
		lbl.add_theme_color_override("font_color", Coop.player_color(p))
	else:
		var names: Array = []
		for p in players:
			names.append(Coop.player_names[int(p)])
		lbl.text = "★ Meilleur score du tournoi : %s — %s m  (+1 chacun)" % [", ".join(names), score_txt]
		lbl.add_theme_color_override("font_color", TEXT_GOLD)

# Podium : 2e à gauche, 1er au centre (plus haut), 3e à droite. Piliers alignés en bas.
# Robuste à 2 joueurs (pas de 3e pilier) comme à 4 (4e relégué au classement dessous).
func _build_podium(standings: Array) -> void:
	var podium := $Content/Podium as HBoxContainer
	for child in podium.get_children():
		child.queue_free()
	var n: int = standings.size()
	var slots: Array = []   # ordre VISUEL : [2e, 1er, 3e] selon disponibilité
	if n >= 2:
		slots.append({"s": standings[1], "place": 2})
	slots.append({"s": standings[0], "place": 1})
	if n >= 3:
		slots.append({"s": standings[2], "place": 3})
	for slot in slots:
		podium.add_child(_podium_slot(slot["s"], int(slot["place"])))

func _podium_slot(s: Dictionary, place: int) -> Control:
	var p: int = int(s["player"])
	var col: Color = Coop.player_color(p)
	var slot := VBoxContainer.new()
	slot.alignment = BoxContainer.ALIGNMENT_END   # contenu poussé en bas → piliers alignés
	slot.custom_minimum_size = Vector2(104, PODIUM_MAX_H)
	slot.add_theme_constant_override("separation", 4)

	# Couronne (icône) au-dessus du 1er ; spacer de même hauteur ailleurs → noms alignés.
	if place == 1:
		var crown := TextureRect.new()
		crown.texture = CROWN_TEX
		crown.custom_minimum_size = Vector2(0, 28)
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(crown)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 28)
		slot.add_child(spacer)
	var name_lbl := _label(Coop.player_names[p], 19, col)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(name_lbl)
	slot.add_child(_centered(_label("%d pts" % int(s["points"]), 17, TEXT_CREAM)))

	var pillar := PanelContainer.new()
	pillar.custom_minimum_size = Vector2(92, PILLAR_H.get(place, 80.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.85)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	pillar.add_theme_stylebox_override("panel", sb)
	var place_lbl := _label(str(place), 40, Color(1, 1, 1, 0.92))
	place_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pillar.add_child(place_lbl)
	slot.add_child(pillar)
	return slot

# Classement général : [rang] [pastille] [nom]  [total pts]. (manches gagnées non affichées —
# reste un critère interne de départage.)
func _make_standing_row(rank: int, s: Dictionary) -> PanelContainer:
	var p: int = int(s["player"])
	var col: Color = Coop.player_color(p)
	var card := _tinted_card(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%d." % rank, 22, TEXT_CREAM, 34))
	var swatch := ColorRect.new()
	swatch.color = col
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var name_lbl := _label(Coop.player_names[p], 22, col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var pts_lbl := _label("%d pts" % int(s["points"]), 22, TEXT_GOLD, 72)
	if rank == 1:   # vainqueur : liseré blanc FIN pour le mettre en avant (lisible)
		pts_lbl.add_theme_color_override("font_outline_color", Color.WHITE)
		pts_lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(pts_lbl)
	card.add_child(row)
	return card

# ── Helpers ──────────────────────────────────────────────────────────────────

func _tinted_card(col: Color, alpha: float = 0.16) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, alpha)
	sb.set_corner_radius_all(int(GlassBlur.DEFAULT_RADIUS))
	sb.set_border_width_all(0)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)
	return card

func _label(text: String, size: int, color: Color, min_w: float = 0.0) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if min_w > 0.0:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	return lbl

func _centered(c: Control) -> Control:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(c)
	return box

func _on_rejouer_pressed() -> void:
	Audio.play_ui_click()
	Coop.restart_same_config()

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	Coop.clear()
	Transition.change_scene("res://scenes/ui/main_menu.tscn")
