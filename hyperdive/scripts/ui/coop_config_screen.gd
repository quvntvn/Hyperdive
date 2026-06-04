extends CanvasLayer
class_name CoopConfigScreen
# Écran de configuration d'une partie COOP pass-and-play (overlay plein écran, verre).
# Ouvert depuis le menu via open(). "DÉMARRER" construit la session (Coop.start_session).
#
# COMMIT 1 : "DÉMARRER" ne lance pas encore le jeu — il monte la session et affiche un
# RÉSUMÉ (modes tirés par manche + pseudos) pour valider l'écran sur mobile. La navigation
# vers la passation arrive au commit 2.

var _num_players: int = 2
var _mode: String = "mix"                       # "mix" | "infinite" | "jetpack"
var _rounds: int = 5
var _names: PackedStringArray = ["", "", "", ""]

var _form: VBoxContainer
var _pseudo_box: VBoxContainer
var _summary: Label
var _rounds_label: Label

func _ready() -> void:
	add_to_group("coop_config_screen")
	_form = $Content/ScrollContainer/Form
	_summary = $Content/SummaryLabel
	$Content/ButtonsRow/StartButton.pressed.connect(_on_start_pressed)
	$Content/ButtonsRow/MenuButton.pressed.connect(_on_menu_pressed)

func open() -> void:
	# Reset aux valeurs par défaut à chaque ouverture (session fraîche).
	_num_players = 2
	_mode = "mix"
	_rounds = 5
	_names = ["", "", "", ""]
	_summary.visible = false
	_build_form()
	visible = true
	UIAnimations.pop_in($Content, $Tint)

# ──────────────────────────────────────────────────────────────────────────────
# Construction du formulaire
# ──────────────────────────────────────────────────────────────────────────────

func _build_form() -> void:
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()

	_form.add_child(_section_header("JOUEURS"))
	_form.add_child(_build_segmented([2, 3, 4], ["2", "3", "4"], _num_players,
		func(v: Variant) -> void:
			_num_players = int(v)
			_rebuild_pseudos()))

	_form.add_child(_section_header("MODE"))
	_form.add_child(_build_segmented(["mix", "infinite", "jetpack"],
		["MIX", "CLASSIQUE", "JETPACK"], _mode,
		func(v: Variant) -> void: _mode = String(v)))

	_form.add_child(_section_header("MANCHES"))
	_form.add_child(_build_stepper())

	_form.add_child(_section_header("PSEUDOS (optionnel)"))
	_pseudo_box = VBoxContainer.new()
	_pseudo_box.add_theme_constant_override("separation", 8)
	_form.add_child(_pseudo_box)
	_rebuild_pseudos()

	UIAnimations.wire_buttons(_form)

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = &"Subtitle"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.949, 0.757, 0.306))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ne pas avaler le drag de scroll
	return lbl

# Sélecteur segmenté : une rangée de boutons, un seul "actif" (les autres atténués).
# values = valeurs logiques ; labels = textes affichés ; on_change(value) au clic.
func _build_segmented(values: Array, labels: Array, current: Variant, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var btns: Array[Button] = []
	for i in range(values.size()):
		var b := Button.new()
		b.text = String(labels[i])
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		var idx: int = i
		b.pressed.connect(func() -> void:
			Audio.play_ui_click()
			on_change.call(values[idx])
			_update_segmented(btns, idx))
		btns.append(b)
		row.add_child(b)
	var sel: int = values.find(current)
	_update_segmented(btns, sel if sel >= 0 else 0)
	return row

func _update_segmented(btns: Array[Button], sel: int) -> void:
	for i in range(btns.size()):
		btns[i].modulate = Color.WHITE if i == sel else Color(1.0, 1.0, 1.0, 0.4)

# Sélecteur de nombre de manches : [ − ]  valeur  [ + ], borné MIN_ROUNDS..MAX_ROUNDS.
func _build_stepper() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(64, 56)
	minus.add_theme_font_size_override("font_size", 28)
	_rounds_label = Label.new()
	_rounds_label.text = str(_rounds)
	_rounds_label.custom_minimum_size = Vector2(56, 0)
	_rounds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rounds_label.add_theme_font_size_override("font_size", 34)
	_rounds_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(64, 56)
	plus.add_theme_font_size_override("font_size", 28)
	minus.pressed.connect(func() -> void:
		Audio.play_ui_click()
		_rounds = maxi(CoopSession.MIN_ROUNDS, _rounds - 1)
		_rounds_label.text = str(_rounds))
	plus.pressed.connect(func() -> void:
		Audio.play_ui_click()
		_rounds = mini(CoopSession.MAX_ROUNDS, _rounds + 1)
		_rounds_label.text = str(_rounds))
	row.add_child(minus)
	row.add_child(_rounds_label)
	row.add_child(plus)
	return row

# Un champ pseudo par joueur (selon _num_players), précédé d'une pastille à sa couleur
# d'identité (J1 orange, J2 turquoise, J3 jaune, J4 bleu nuit). Reconstruit au changement
# de nombre de joueurs ; on conserve les pseudos déjà saisis.
func _rebuild_pseudos() -> void:
	if _pseudo_box == null:
		return
	for child in _pseudo_box.get_children():
		_pseudo_box.remove_child(child)
		child.queue_free()
	for i in range(_num_players):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var swatch := ColorRect.new()
		swatch.color = CoopSession.PLAYER_COLORS[i]
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var field := LineEdit.new()
		field.placeholder_text = "Joueur %d" % (i + 1)
		field.text = _names[i]
		field.max_length = 12
		field.custom_minimum_size = Vector2(0, 48)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		field.text_changed.connect(func(t: String) -> void: _names[idx] = t)
		line.add_child(swatch)
		line.add_child(field)
		_pseudo_box.add_child(line)

# ──────────────────────────────────────────────────────────────────────────────
# Actions
# ──────────────────────────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	Audio.play_ui_click()
	var names: Array = []
	for i in range(_num_players):
		names.append(_names[i])
	Coop.start_session(_num_players, _rounds, _mode, names)
	_show_summary()

# COMMIT 1 : résumé visible (testable mobile). Remplacé par la navigation vers la passation
# au commit 2.
func _show_summary() -> void:
	var modes: Array = []
	for m in Coop.round_modes:
		modes.append(Coop.mode_label(m))
	var txt: String = "Session prête : %d joueurs · %d manches\n" % [Coop.num_players, Coop.num_rounds]
	txt += "Manches : " + ", ".join(modes) + "\n"
	txt += "Joueurs : " + ", ".join(Coop.player_names)
	_summary.text = txt
	_summary.visible = true

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	visible = false
