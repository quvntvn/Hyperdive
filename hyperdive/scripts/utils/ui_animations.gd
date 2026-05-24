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
