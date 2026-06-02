extends RefCounted
class_name UIAnimations

const POP_DURATION: float = 0.2

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
		sb.bg_color = Color(0.82, 0.86, 0.95, 0.14)
		sb.set_corner_radius_all(int(GlassBlur.DEFAULT_RADIUS))
		sb.set_border_width_all(1)
		sb.border_color = Color(1.0, 1.0, 1.0, 0.32)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 10.0
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		_card_style = sb
	return _card_style

static func wire_button(btn: BaseButton) -> void:
	btn.button_down.connect(func() -> void:
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
