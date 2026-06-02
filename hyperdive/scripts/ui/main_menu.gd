extends Node3D
class_name MainMenu

func _ready() -> void:
	%CampagneButton.pressed.connect(_on_campagne_pressed)
	%RecordButton.pressed.connect(_on_record_pressed)
	%JetpackButton.pressed.connect(_on_jetpack_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%DefisButton.pressed.connect(_on_defis_pressed)
	%SettingsGearButton.pressed.connect(_on_reglages_pressed)
	UIAnimations.wire_buttons(self)

	# Ville lointaine ancrée à la caméra du menu (même logique qu'en jeu, thème appliqué).
	CitySkyline.attach_to($PreviewCamera)

	# Le bouton campagne affiche le niveau de progression courant et le lance DIRECTEMENT
	# (plus d'écran intermédiaire). Relu à chaque _ready → reflète la progression au retour.
	%CampagneButton.text = "NIVEAU " + str(Settings.campaign_level)
	_style_gear_glass()

	_update_mode_buttons()
	update_stats()
	Settings.coin_collected.connect(func(_n: int) -> void: update_stats())

	Audio.stop_whoosh()
	Audio.stop_jetpack()
	Audio.unduck_music()
	Audio.play_music()

	_animate_title()

# Campagne toujours jouable. Record (infini) et Jetpack restent affichés mais GRISÉS
# (disabled) tant que verrouillés. La condition de déblocage est écrite DANS le bouton
# (pas de label séparé). Relu à CHAQUE _ready → un mode débloqué en jeu apparaît au retour.
func _update_mode_buttons() -> void:
	var record_unlocked: bool = Settings.is_infinite_unlocked()
	var jetpack_unlocked: bool = Settings.is_jetpack_unlocked()
	print("[Menu] déblocages — infinite=", record_unlocked,
		  " jetpack=", jetpack_unlocked,
		  " best_infinite_distance=", Settings.best_infinite_distance)
	# Libellés d'AFFICHAGE seulement ; active_mode reste "infinite"/"jetpack" en interne.
	_set_mode_button(%RecordButton, record_unlocked, "CLASSIQUE", "Termine le niveau 1")
	_set_mode_button(%JetpackButton, jetpack_unlocked, "JETPACK", "Atteins 1000m en Classique")

# Débloqué : texte = nom du mode, cliquable, grande police. Verrouillé : texte = nom +
# cadenas + condition (2 lignes), grisé, police réduite pour faire tenir la condition.
func _set_mode_button(btn: Button, unlocked: bool, mode_name: String, condition: String) -> void:
	btn.disabled = not unlocked
	if unlocked:
		btn.text = mode_name
		btn.add_theme_font_size_override("font_size", 32)
	else:
		btn.text = mode_name + " 🔒\n" + condition
		btn.add_theme_font_size_override("font_size", 20)

func update_stats() -> void:
	%BestLabel.text = "Record : " + str(Settings.best_distance) + " m"
	%CoinsLabel.text = "Pièces : " + str(Settings.coins_total)

func _on_campagne_pressed() -> void:
	Audio.play_ui_click()
	# Lancement direct du niveau de progression courant, sans écran intermédiaire.
	# Les pièces gagnées ne s'affichent qu'au pop-up de fin de niveau (dans le jeu).
	Settings.active_mode = "campaign"
	Settings.active_level = Settings.campaign_level
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_record_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "infinite"
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_jetpack_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "jetpack"
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_shop_pressed() -> void:
	Audio.play_ui_click()
	var shop := get_tree().get_first_node_in_group("shop_screen")
	if shop:
		shop.open()

func _on_defis_pressed() -> void:
	Audio.play_ui_click()
	var missions := get_tree().get_first_node_in_group("missions_screen")
	if missions:
		missions.open()

func _on_reglages_pressed() -> void:
	Audio.play_ui_click()
	var s := get_tree().get_first_node_in_group("settings_screen")
	if s:
		s.open()

# L'engrenage est un TextureButton (pas un Button → ignoré par l'autoload Glass). On lui
# pose un backing "verre" : un Panel translucide (arête claire + ombre) DERRIÈRE l'icône
# (show_behind_parent), avec un GlassBlur dessous pour flouter le décor. Cohérent avec les
# autres boutons sans casser le rendu net de l'icône.
func _style_gear_glass() -> void:
	var gear: Control = %SettingsGearButton
	if gear.has_node("GearGlass"):
		return
	var backing := Panel.new()
	backing.name = "GearGlass"
	backing.show_behind_parent = true
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.82, 0.86, 0.95, 0.18)
	sb.set_corner_radius_all(int(GlassBlur.DEFAULT_RADIUS))
	# Pas de contour qui fait le tour : seulement un reflet de verre TRÈS discret en haut.
	sb.set_border_width_all(0)
	sb.border_width_top = 1
	sb.border_color = Color(1.0, 1.0, 1.0, 0.18)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	backing.add_theme_stylebox_override("panel", sb)
	gear.add_child(backing)
	gear.move_child(backing, 0)
	GlassBlur.add_behind(backing)

func _animate_title() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(%TitleLabel, "modulate", Color(1.15, 1.15, 1.15, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%TitleLabel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
