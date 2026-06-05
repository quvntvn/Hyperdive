extends RefCounted
class_name UIAnimations

const POP_DURATION: float = 0.2

# Sépare un entier par groupes de 3 chiffres avec une espace INSÉCABLE (U+00A0) :
# 1561161 → "1 561 161". Insécable → un nombre ne se coupe jamais en bout de ligne.
# AFFICHAGE seulement : la logique garde les ints, on formate juste au moment de l'afficher.
# < 1000 → inchangé (pas d'espace) ; 0 → "0" ; négatifs gérés (signe conservé).
static func format_number(n: int) -> String:
	var neg: bool = n < 0
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" + out) if neg else out

static func pop_in(panel: Control, scrim: Control = null) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var t := panel.create_tween().set_parallel(true)
	t.tween_property(panel, "scale", Vector2.ONE, POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, POP_DURATION * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if scrim:
		scrim.modulate.a = 0.0
		t.tween_property(scrim, "modulate:a", 1.0, POP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Style "carte verre" partagé (translucide + arête claire + ombre légère, coins arrondis),
# pour les lignes d'items du shop et des défis sur fond décor. Pas de blur par carte (coût) :
# le fond de l'écran porte déjà un backdrop-blur plein écran. Mutualisé (une seule ressource).
static var _card_style: StyleBoxFlat = null

static func glass_card_style() -> StyleBoxFlat:
	if _card_style == null:
		var sb := StyleBoxFlat.new()
		# Verre bleu nuit MODÉRÉMENT sombre (présence/contraste), mais moins dense que les
		# boutons → les boutons clairs ressortent par-dessus. Reste translucide (devine le flou).
		sb.bg_color = Color(0.13, 0.17, 0.27, 0.36)
		sb.set_corner_radius_all(int(GlassBlur.DEFAULT_RADIUS))
		# Pas de contour complet : seulement un reflet de verre discret en haut.
		sb.set_border_width_all(0)
		sb.border_width_top = 1
		sb.border_color = Color(1.0, 1.0, 1.0, 0.16)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 10.0
		_card_style = sb
	return _card_style

# Style "panneau verre" pour les modales plein panneau (réglages/pause/game over/fin niveau).
# Translucide + arête claire en haut, PAS de fond opaque : posé sur le backdrop-blur plein écran
# de l'écran, on devine le décor flouté derrière → cohérent avec les cartes du shop/défis.
# (Le thème global garde son Panel opaque pour le HUD/cartes coop ; override ciblé seulement.)
static var _panel_style: StyleBoxFlat = null

static func glass_panel_style() -> StyleBoxFlat:
	if _panel_style == null:
		var sb := StyleBoxFlat.new()
		# Verre bleu nuit MODÉRÉMENT sombre : un peu plus dense que les cartes d'items, mais
		# toujours moins sombre que les boutons → les boutons clairs ressortent dessus.
		sb.bg_color = Color(0.13, 0.17, 0.27, 0.4)
		sb.set_corner_radius_all(int(GlassBlur.DEFAULT_RADIUS))
		sb.set_border_width_all(0)
		sb.border_width_top = 1
		sb.border_color = Color(1.0, 1.0, 1.0, 0.18)
		_panel_style = sb
	return _panel_style

# Transforme un Panel modal en "panneau verre" : stylebox translucide + backdrop-blur derrière
# (frosté, lisible). À appeler une fois dans le _ready de l'écran. Mutualisé entre les 4 écrans.
static func make_glass_panel(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", glass_panel_style())
	GlassBlur.add_behind(panel)

static func wire_button(btn: BaseButton) -> void:
	btn.button_down.connect(func() -> void:
		Settings.vibrate(20)   # petit "tic" haptique au clic (centralisé → tous les boutons)
		btn.pivot_offset = btn.size / 2.0
		var t := btn.create_tween()
		t.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.06).set_trans(Tween.TRANS_QUAD)
	)
	btn.button_up.connect(func() -> void:
		var t := btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

static func wire_buttons(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		wire_button(node as BaseButton)

# Laisse le glissement tactile remonter jusqu'au ScrollContainer parent : met tous les Control
# non-boutons en MOUSE_FILTER_PASS (sinon ils avalent le drag et la liste ne défile pas au doigt
# sur mobile). Les boutons gardent STOP pour rester cliquables. Mutualisé entre défis et shop.
static func allow_scroll_through(node: Node) -> void:
	if node is Control and not (node is BaseButton):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		allow_scroll_through(child)

# Inset haut de la safe area (encoche/poinçon/barre de statut) converti en pixels GUI.
# DisplayServer.get_display_safe_area() est en pixels PHYSIQUES ; on convertit via le ratio
# canvas/écran (stretch canvas_items). 0 sur desktop (pas d'encoche).
static func top_safe_inset(vp: Viewport) -> float:
	if vp == null:
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var gui_per_phys: float = vp.get_visible_rect().size.y / float(win.y)
	return maxf(float(safe.position.y), 0.0) * gui_per_phys

# Descend un Control sous la safe area : ajoute (inset haut, ou min_margin si pas d'encoche)
# a offset_top ET offset_bottom → l'element descend en gardant sa taille/son comportement.
# Gere tous les telephones automatiquement (encoche ou non) + une marge mini sur desktop.
static func apply_top_safe_area(ctrl: Control, min_margin: float = 0.0) -> void:
	var shift: float = maxf(top_safe_inset(ctrl.get_viewport()), min_margin)
	if shift <= 0.0:
		return
	ctrl.offset_top += shift
	ctrl.offset_bottom += shift
