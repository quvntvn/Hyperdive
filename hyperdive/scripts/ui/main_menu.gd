extends Node3D
class_name MainMenu

func _ready() -> void:
	# Garde-fou : atterrir au menu = toute session coop est terminée/abandonnée. On coupe
	# Coop.active ici (point unique) → un lancement solo ensuite n'hérite jamais du contexte coop.
	Coop.clear()
	%CampagneButton.pressed.connect(_on_campagne_pressed)
	%RecordButton.pressed.connect(_on_record_pressed)
	%JetpackButton.pressed.connect(_on_jetpack_pressed)
	%CoopButton.pressed.connect(_on_coop_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%DefisButton.pressed.connect(_on_defis_pressed)
	%SettingsGearButton.pressed.connect(_on_reglages_pressed)
	UIAnimations.wire_buttons(self)

	# Ville lointaine ancrée à la caméra du menu (même logique qu'en jeu, thème appliqué).
	CitySkyline.attach_to($PreviewCamera)

	# Quand un écran s'ouvre PAR-DESSUS le menu (réglages/défis/cosmétique/coop), on masque
	# les ÉLÉMENTS d'UI du menu (titre, stats, boutons, engrenage) pour qu'ils ne transparaissent
	# plus derrière le flou de l'écran. On GARDE le décor 3D (ville défilante) : il vit dans le
	# monde Node3D, pas dans MenuUI → le backdrop de l'écran continue de le flouter joliment.
	# Piloté par visibility_changed (un seul point de vérité, gère ouverture ET fermeture).
	for screen: CanvasLayer in [$ShopScreen, $SettingsScreen, $MissionsScreen, $CoopConfigScreen, $CampaignScreen, $ChapterReader, $ChapterEndScreen]:
		screen.visibility_changed.connect(_sync_menu_ui_visibility)

	# Le bouton campagne ouvre la CARTE de l'HISTOIRE (campagne narrative 40 chapitres).
	%CampagneButton.text = "HISTOIRE"
	# Descend l'engrenage sous la safe area (encoche/caméra frontale), avec une marge mini
	# généreuse même sans encoche pour qu'il ne soit pas collé au bord haut.
	UIAnimations.apply_top_safe_area(%SettingsGearButton, 28.0)
	# Descend le bloc menu (centré) pour que le titre HYPERDIVE passe SOUS l'engrenage et ne
	# le chevauche plus. On augmente seulement le haut de la zone (le bloc reste centré dedans).
	$MenuUI/Screen/Layout.offset_top += UIAnimations.top_safe_inset(get_viewport()) + 64.0
	_style_gear_glass()

	_update_mode_buttons()
	update_stats()
	Settings.coin_collected.connect(func(_n: int) -> void: update_stats())

	Audio.stop_whoosh()
	Audio.stop_jetpack()
	# Menu = hors gameplay → musique BAISSÉE (règle unique : plein seulement en jeu). play_music
	# garantit la reprise (utile après le ch.1 « 2028 » qui coupe la musique via stop_music).
	Audio.duck_music()
	Audio.play_music()

	_animate_title()

	# Retour d'un chapitre HISTOIRE (victoire/échec/abandon) → on rouvre la carte (et l'outro
	# en attente le cas échéant) au lieu d'atterrir sur le menu racine. Après les connexions de
	# visibilité ci-dessus → l'ouverture de la carte masque bien l'UI du menu.
	_handle_story_return()

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
	_set_mode_button(%RecordButton, record_unlocked, "CLASSIQUE", "Termine le chapitre 1")
	_set_mode_button(%JetpackButton, jetpack_unlocked, "JETPACK", "Termine le chapitre 20")

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

# Cache l'UI du menu (MenuUI : titre, stats, boutons, engrenage) dès qu'un écran est ouvert ;
# la réaffiche quand ils sont tous fermés. Le décor 3D reste visible (hors MenuUI).
func _sync_menu_ui_visibility() -> void:
	var any_open: bool = false
	for screen: CanvasLayer in [$ShopScreen, $SettingsScreen, $MissionsScreen, $CoopConfigScreen, $CampaignScreen, $ChapterReader, $ChapterEndScreen]:
		if screen.visible:
			any_open = true
			break
	$MenuUI.visible = not any_open

func update_stats() -> void:
	# Deux records distincts : Classique (best_infinite_distance) et Jetpack (best_jetpack_distance).
	%BestLabel.text = "Classique : " + UIAnimations.format_number(Settings.best_infinite_distance) + " m"
	%JetpackLabel.text = "Jetpack : " + UIAnimations.format_number(Settings.best_jetpack_distance) + " m"
	%CoinsLabel.text = "Pièces : " + UIAnimations.format_number(Settings.coins_total)

func _on_campagne_pressed() -> void:
	Audio.play_ui_click()
	# Ouvre la CARTE de l'histoire (carte verticale des 40 chapitres) au lieu de lancer un niveau.
	var campaign := get_tree().get_first_node_in_group("campaign_screen")
	if campaign:
		campaign.open()

# Au retour d'un chapitre joué (Story.active resté actif), rouvre la carte centrée sur le
# chapitre courant ; si une outro est en attente (chapitre à texte "after" tout juste réussi),
# l'affiche par-dessus en lecture seule. Puis coupe le contexte campagne.
func _handle_story_return() -> void:
	if not Story.active and Story.pending_outro <= 0 and Story.pending_reward <= 0:
		return
	var outro: int = Story.pending_outro
	var reward_n: int = Story.pending_reward   # chapitre dont le pop-up réussite reste à afficher
	Story.pending_outro = 0
	Story.pending_reward = 0
	Story.clear()
	var campaign := get_tree().get_first_node_in_group("campaign_screen")
	if campaign:
		campaign.open()
	if outro > 0:
		# Lit l'HISTOIRE (outro) d'abord ; à sa fermeture, le pop-up récompense s'affiche
		# PAR-DESSUS la carte (nouvel ordre : niveau → histoire → pop-up réussite).
		var reader := get_tree().get_first_node_in_group("chapter_reader")
		if reader:
			if reward_n > 0:
				reader.outro_closed.connect(
					func(_cn: int) -> void: _show_reward_popup(reward_n),
					CONNECT_ONE_SHOT)
			reader.open_chapter(outro, "outro")
	elif reward_n > 0:
		# Chapitre sans outro (cas théorique : tous les jouables sont "after" aujourd'hui) →
		# pop-up récompense directement sur la carte.
		_show_reward_popup(reward_n)

# Pop-up "CHAPITRE RÉUSSI" + pièces, affiché PAR-DESSUS la carte au menu. Il n'AFFICHE que le
# gain (déjà crédité à la victoire via Story.complete_chapter) ; son bouton referme le pop-up.
func _show_reward_popup(n: int) -> void:
	var screen := get_tree().get_first_node_in_group("chapter_end_screen")
	if screen:
		screen.show_reward(n)

# Rafraîchit les boutons de mode + stats après une complétion de chapitre (la carte appelle
# ça quand un chapitre débloque Classique (ch.1) ou Jetpack (ch.20)). Le menu reste chargé
# derrière la carte → il suffit de relire les déblocages/stats.
func refresh_after_story() -> void:
	_update_mode_buttons()
	update_stats()

func _on_record_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "infinite"
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_jetpack_pressed() -> void:
	Audio.play_ui_click()
	Settings.active_mode = "jetpack"
	Transition.change_scene("res://scenes/game/main_game.tscn")

func _on_coop_pressed() -> void:
	Audio.play_ui_click()
	var coop := get_tree().get_first_node_in_group("coop_config_screen")
	if coop:
		coop.open()

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
	# Pas de contour du tout (contour blanc retiré) : verre + arrondi seuls.
	sb.set_border_width_all(0)
	backing.add_theme_stylebox_override("panel", sb)
	gear.add_child(backing)
	gear.move_child(backing, 0)
	GlassBlur.add_behind(backing)
	# Icône engrenage 2× plus petite, CENTRÉE, fond verre/blur inchangé. La texture remplissait
	# tout le bouton (80×80) ; on la retire du TextureButton et on la repose en TextureRect 40×40
	# centré → plus de marge autour du pictogramme, le rond verre garde sa taille.
	var tb := gear as TextureButton
	if tb != null and tb.texture_normal != null and not gear.has_node("GearIcon"):
		var icon := TextureRect.new()
		icon.name = "GearIcon"
		icon.texture = tb.texture_normal
		tb.texture_normal = null
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -20.0
		icon.offset_top = -20.0
		icon.offset_right = 20.0
		icon.offset_bottom = 20.0
		gear.add_child(icon)

func _animate_title() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(%TitleLabel, "modulate", Color(1.15, 1.15, 1.15, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(%TitleLabel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
