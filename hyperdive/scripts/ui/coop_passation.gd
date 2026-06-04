extends Control
class_name CoopPassation
# Écran de PASSATION pass-and-play : "AU TOUR DE [Joueur X]" + sa couleur + le mode de la
# manche. La manche ne démarre QU'au clic PRÊT → protège du jeu par surprise quand le
# téléphone change de main. Scène autonome (atteinte via Transition), pas un overlay.

func _ready() -> void:
	# Garde-fou : si on arrive ici hors contexte coop, retour menu (évite un écran orphelin).
	if not Coop.active:
		Transition.change_scene("res://scenes/ui/main_menu.tscn")
		return
	# Le son de jeu de la manche précédente doit s'arrêter (le prochain tour le relancera).
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	$Center/Card.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	_populate()
	$ReadyButton.pressed.connect(_on_ready_pressed)
	UIAnimations.wire_buttons(self)
	# Attendre un frame que le CenterContainer dimensionne la carte (sinon pivot à 0 → l'anim
	# part du coin haut-gauche au lieu du centre).
	await get_tree().process_frame
	UIAnimations.pop_in($Center/Card)

func _populate() -> void:
	var vb := $Center/Card/Margin/VBox
	vb.get_node("RoundLabel").text = Coop.turn_round_label()
	vb.get_node("ModeLabel").text = Coop.mode_label(Coop.turn_mode())
	vb.get_node("NameLabel").text = Coop.turn_name()
	var col: Color = Coop.turn_color()
	vb.get_node("NameLabel").add_theme_color_override("font_color", col)
	(vb.get_node("ColorBar") as ColorRect).color = col

func _on_ready_pressed() -> void:
	Audio.play_ui_click()
	Coop.go_to_turn()
