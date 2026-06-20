extends Control
class_name CoopRoundResult
# Classement d'une MANCHE coop : joueurs triés par score de la manche, score + points gagnés
# (+10/+6/+3/+1 selon la place) + cumul général mis à jour. CONTINUER → manche suivante ou
# écran final. Juice minimal (le style "ranked" complet vient au commit 5).

const TEXT_CREAM := Color(0.957, 0.914, 0.804)
const TEXT_GOLD := Color(0.949, 0.757, 0.306)
const TEXT_DIM := Color(0.80, 0.78, 0.72)

func _ready() -> void:
	if not Coop.active:
		Transition.change_scene("res://scenes/ui/main_menu.tscn")
		return
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	Audio.duck_music()   # écran hors gameplay → musique baissée (règle unique « plein en jeu »)
	_populate()
	var btn := $Content/ContinueButton as Button
	btn.text = "CLASSEMENT FINAL" if Coop.is_last_round() else "CONTINUER"
	btn.pressed.connect(_on_continue_pressed)
	UIAnimations.wire_buttons(self)

func _populate() -> void:
	var r: int = Coop.current_round
	$Content/TitleLabel.text = "MANCHE %d / %d" % [r + 1, Coop.num_rounds]
	$Content/ModeLabel.text = Coop.mode_label(Coop.current_mode())

	_populate_records(r)

	var rows := $Content/ScrollContainer/RowsBox as VBoxContainer
	for child in rows.get_children():
		child.queue_free()
	for e in Coop.round_ranking(r):
		rows.add_child(_make_round_row(e))

	var standings := $Content/StandingsBox as VBoxContainer
	for child in standings.get_children():
		child.queue_free()
	var header := _label("CLASSEMENT GÉNÉRAL", 22, TEXT_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	standings.add_child(header)
	var rank: int = 1
	for s in Coop.standings(r):
		standings.add_child(_make_standing_row(rank, s))
		rank += 1

# Deux lignes de référence sous le titre : meilleur score DE CE ROUND (+ auteur) et record
# PERSO du mode (non modifié par le tournoi). Si le round dépasse le record perso → "RECORD BATTU !".
func _populate_records(r: int) -> void:
	var box := $Content/RecordsBox as VBoxContainer
	for child in box.get_children():
		child.queue_free()

	# Meilleur score de ce round = 1er du classement de la manche (trié par score décroissant).
	var top: Dictionary = Coop.round_ranking(r)[0]
	var top_p: int = int(top["player"])
	var top_score: int = int(top["score"])
	var best_lbl := _label(
		"Meilleur ce round : %s m  (%s)" % [UIAnimations.format_number(top_score), Coop.player_names[top_p]],
		20, Coop.player_color(top_p))
	best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best_lbl)

	# Meilleur score du TOURNOI EN COURS (max individuel toutes manches jouées, tous joueurs) —
	# PAS le record perso (qui n'est jamais touché par le tournoi). RAZ à chaque nouveau tournoi.
	var best_tourn: int = Coop.tournament_best_through(r)
	var rec_lbl := _label(
		"Meilleur du tournoi : %s m" % UIAnimations.format_number(best_tourn),
		18, TEXT_DIM)
	rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rec_lbl)

	# Mise en avant si CE round établit (ou égale) le meilleur du tournoi : le top du round EST
	# le meilleur du tournoi → nouveau sommet posé cette manche.
	if top_score >= best_tourn and top_score > 0:
		var beat := _label("MEILLEUR DU TOURNOI !", 20, TEXT_GOLD)
		beat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		beat.add_theme_color_override("font_outline_color", Color.WHITE)
		beat.add_theme_constant_override("outline_size", 2)
		box.add_child(beat)

# Rangée de manche : [place] [pastille] [nom]  [score m]  [+pts]. Carte teintée couleur joueur.
func _make_round_row(e: Dictionary) -> PanelContainer:
	var p: int = int(e["player"])
	var col: Color = Coop.player_color(p)
	var card := _tinted_card(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_label("%d." % (int(e["place"]) + 1), 24, TEXT_CREAM, 34))
	var swatch := ColorRect.new()
	swatch.color = col
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var name_lbl := _label(Coop.player_names[p], 24, col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	row.add_child(_label("%s m" % UIAnimations.format_number(int(e["score"])), 22, TEXT_CREAM))
	row.add_child(_label("+%d" % int(e["points"]), 24, TEXT_GOLD, 56))

	card.add_child(row)
	return card

# Rangée de cumul : [rang] [nom]  [total pts]. Compacte, teintée légèrement.
func _make_standing_row(rank: int, s: Dictionary) -> PanelContainer:
	var p: int = int(s["player"])
	var col: Color = Coop.player_color(p)
	var card := _tinted_card(col, 0.10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%d." % rank, 20, TEXT_DIM, 30))
	var name_lbl := _label(Coop.player_names[p], 20, col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	row.add_child(_label("%d pts" % int(s["points"]), 22, TEXT_CREAM))
	card.add_child(row)
	return card

# ── Helpers ──────────────────────────────────────────────────────────────────

func _tinted_card(col: Color, alpha: float = 0.18) -> PanelContainer:
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

func _on_continue_pressed() -> void:
	Audio.play_ui_click()
	Coop.continue_after_round()
