extends Control
class_name CoopTiebreak
# Annonce "ÉGALITÉ ! ROUND FINAL" avant un round de départage : noms + couleurs des ex-æquo
# concernés et le mode tiré. Bouton C'EST PARTI → passation du 1er ex-æquo. Seuls les ex-æquo
# jouent ce round (les autres regardent). Scène autonome (atteinte via Transition).

func _ready() -> void:
	if not Coop.active or not Coop.tiebreak_active:
		Transition.change_scene("res://scenes/ui/main_menu.tscn")
		return
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	Audio.duck_music()       # écran hors gameplay → musique baissée (règle unique « plein en jeu »)
	Audio.play_coop_lead()   # petite fanfare de tension à l'annonce
	$Center/Card.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	_populate()
	$GoButton.pressed.connect(_on_go_pressed)
	UIAnimations.wire_buttons(self)
	await get_tree().process_frame
	UIAnimations.pop_in($Center/Card)

func _populate() -> void:
	var vb := $Center/Card/Margin/VBox
	(vb.get_node("ModeLabel") as Label).text = "Round final : " + Coop.mode_label(Coop.tiebreak_mode)
	var box := vb.get_node("PlayersBox") as VBoxContainer
	for child in box.get_children():
		child.queue_free()
	for p in Coop.tiebreak_players:
		var lbl := Label.new()
		lbl.text = Coop.player_names[p]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Coop.player_color(p))
		box.add_child(lbl)

func _on_go_pressed() -> void:
	Audio.play_ui_click()
	Coop.begin_tiebreak_turn()
