extends CanvasLayer
class_name MissionsScreen

var _coins_label: Label
var _mission_list: VBoxContainer

func _ready() -> void:
	add_to_group("missions_screen")
	_coins_label = $Content/CoinsLabel
	_mission_list = $Content/ScrollContainer/MissionList
	# Le conteneur de liste ne doit pas bloquer le glissement tactile (sinon le ScrollContainer
	# parent ne reçoit jamais le drag → liste non défilable au doigt sur mobile).
	_mission_list.mouse_filter = Control.MOUSE_FILTER_PASS
	$Content/MenuButton.pressed.connect(_on_menu_pressed)
	Settings.mission_claimed.connect(func() -> void: refresh())
	UIAnimations.wire_buttons(self)
	Settings.daily_claimed_signal.connect(func() -> void: refresh())
	Settings.coin_collected.connect(func(_n: int) -> void: refresh())
	refresh()

func refresh() -> void:
	_coins_label.text = "Pièces : " + str(Settings.coins_total)
	for child in _mission_list.get_children():
		_mission_list.remove_child(child)
		child.queue_free()
	_add_section_label("DÉFIS DU JOUR", Color(0.914, 0.310, 0.216))
	for ch in Settings.daily_challenges:
		_build_daily_row(ch)
	var sep := HSeparator.new()
	_mission_list.add_child(sep)
	_add_section_label("DÉFIS", Color(0.957, 0.914, 0.804))
	# Chaînes de paliers : n'afficher que le PROCHAIN palier non réclamé de chaque chaîne
	# (l'array est ordonné en paliers croissants). Les exploits (sans chain) restent tous visibles.
	var shown_chains: Dictionary = {}
	for mission in Missions.MISSIONS:
		if mission.has("chain"):
			if Settings.is_mission_claimed(mission["id"]):
				continue                      # palier déjà réclamé → passer au suivant de la chaîne
			var ch: String = mission["chain"]
			if shown_chains.has(ch):
				continue                      # prochain palier de cette chaîne déjà affiché
			shown_chains[ch] = true
		_build_row(mission)
	UIAnimations.wire_buttons(_mission_list)

# Enveloppe une ligne de défi dans une "carte verre" (translucide + arête + ombre) posée
# sur le fond décor flouté. Pas de blur par carte (le backdrop plein écran suffit).
func _add_card(row: Control) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	card.add_child(row)
	# Laisser le glissement tactile remonter jusqu'au ScrollContainer : tous les éléments non
	# interactifs (carte, ligne, labels) passent en PASS ; seuls les boutons gardent STOP (clic).
	_allow_scroll_through(card)
	_mission_list.add_child(card)

# Met les Control non-boutons en MOUSE_FILTER_PASS pour ne pas capturer le drag du ScrollContainer.
func _allow_scroll_through(node: Node) -> void:
	if node is Control and not (node is BaseButton):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_allow_scroll_through(child)

func _add_section_label(title: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	_mission_list.add_child(lbl)

func _build_daily_row(ch: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var desc_label := Label.new()
	desc_label.text = ch["desc"]
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)
	row.add_child(info)
	var id: String = ch["id"]
	var progress: int = Settings.daily_progress.get(id, 0)
	var target: int = ch["target"]
	var reward: int = ch["reward"]
	if Settings.is_daily_claimed(id):
		var claimed_label := Label.new()
		claimed_label.text = "✓ Réclamé"
		claimed_label.add_theme_font_size_override("font_size", 18)
		claimed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
		row.add_child(claimed_label)
	elif Settings.is_daily_complete(ch):
		var btn := Button.new()
		btn.text = "RÉCLAMER " + str(reward)
		btn.custom_minimum_size = Vector2(148.0, 48.0)
		btn.pressed.connect(func() -> void:
			Audio.play_ui_click()
			Settings.claim_daily(ch))
		row.add_child(btn)
	else:
		var prog_label := Label.new()
		prog_label.text = _format_daily_progress(ch, progress, target)
		prog_label.add_theme_font_size_override("font_size", 18)
		prog_label.add_theme_color_override("font_color", Color(0.949, 0.757, 0.306))
		row.add_child(prog_label)
	_add_card(row)

func _format_daily_progress(ch: Dictionary, progress: int, target: int) -> String:
	match ch["type"]:
		"distance": return "%d/%d m" % [progress, target]
		"coins":    return "%d/%d pièces" % [progress, target]
		"time":     return "%ds/%ds" % [progress, target]
		"games":    return "%d/%d parties" % [progress, target]
	return "%d/%d" % [progress, target]

func _build_row(mission: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = mission["name"]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
	var desc_label := Label.new()
	desc_label.text = mission["desc"]
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_label)
	info.add_child(desc_label)
	# Jalon à récompense cosmétique : on l'indique en jaune moutarde sous la description.
	var cosmetic_name: String = _reward_cosmetic_name(mission)
	if cosmetic_name != "":
		var reward_label := Label.new()
		reward_label.text = "🎁 Débloque : " + cosmetic_name
		reward_label.add_theme_font_size_override("font_size", 15)
		reward_label.add_theme_color_override("font_color", Color(0.949, 0.757, 0.306))
		info.add_child(reward_label)
	row.add_child(info)

	var mission_id: String = mission["id"]
	var progress: int = Settings.get_mission_progress(mission)
	var target: int = mission["target"]
	var reward: int = mission["reward"]

	if Settings.is_mission_claimed(mission_id):
		var claimed_label := Label.new()
		claimed_label.text = "✓ Réclamé"
		claimed_label.add_theme_font_size_override("font_size", 18)
		claimed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
		row.add_child(claimed_label)
	elif Settings.is_mission_complete(mission):
		var btn := Button.new()
		btn.text = "RÉCLAMER " + str(reward)
		btn.custom_minimum_size = Vector2(148.0, 48.0)
		btn.pressed.connect(func() -> void:
			Audio.play_ui_click()
			Settings.claim_mission(mission))
		row.add_child(btn)
	else:
		var prog_label := Label.new()
		prog_label.text = _format_progress(mission, progress, target)
		prog_label.add_theme_font_size_override("font_size", 18)
		prog_label.add_theme_color_override("font_color", Color(0.949, 0.757, 0.306))
		row.add_child(prog_label)

	_add_card(row)

func _format_progress(mission: Dictionary, progress: int, target: int) -> String:
	match mission["type"]:
		"campaign_level":
			return "Niveau %d/%d" % [progress, target]
		"infinite_distance", "jetpack_distance", "distance", "dual_distance":
			return "%d/%d m" % [progress, target]
		"coins_lifetime", "coins_run":
			return "%d/%d pièces" % [progress, target]
		"obstacles_dodged", "obstacles_run":
			return "%d/%d esquives" % [progress, target]
		"no_wall_time":
			return "%ds/%ds" % [progress, target]
		"powerups_used":
			return "%d/%d power-ups" % [progress, target]
		"deaths":
			return "%d/%d morts" % [progress, target]
		"total_games":
			return "%d/%d parties" % [progress, target]
		"ascetic":
			return "À accomplir"
		"all_shop_skins", "owned_skins":
			return "%d/%d skins" % [progress, target]
		"all_shop_trails":
			return "%d/%d trails" % [progress, target]
		"all_shop_themes", "owned_themes":
			return "%d/%d thèmes" % [progress, target]
		"trail_equipped":
			return "Non équipé" if progress == 0 else "Équipé"
	return "%d/%d" % [progress, target]

# Nom lisible du cosmétique récompense d'un jalon (ou "" si pas de récompense cosmétique).
func _reward_cosmetic_name(mission: Dictionary) -> String:
	if mission.has("reward_skin"):
		return Catalog.get_skin_by_id(mission["reward_skin"])["name"]
	if mission.has("reward_trail"):
		return Catalog.get_trail(mission["reward_trail"])["name"]
	return ""

func open() -> void:
	Settings.ensure_daily_challenges()
	visible = true
	refresh()
	UIAnimations.pop_in($Content, $Tint)

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	visible = false
