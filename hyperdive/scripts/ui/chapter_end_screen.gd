extends CanvasLayer
class_name ChapterEndScreen
# Overlay de fin de chapitre HISTOIRE. Deux états / deux contextes :
#   RÉCOMPENSE (au MENU, par-dessus la carte) : "Chapitre réussi" + pièces gagnées + CONTINUER.
#       Affiché APRÈS l'outro (nouvel ordre : niveau → histoire → pop-up réussite). Il n'AFFICHE
#       que le gain — les pièces ont déjà été créditées à la victoire (Story.complete_chapter) —
#       et son bouton ne fait que refermer le pop-up (retour carte). Pas de pause de l'arbre.
#   ÉCHEC (en JEU, par-dessus le jeu) : "Tu es tombé" + RÉESSAYER (relance le même chapitre)
#       + RETOUR CAMPAGNE. Retry illimité doux : aucune stat, aucune perte.
# NB : le ch.1 "2028" (mort = réussite) ne déclenche PAS le pop-up récompense (flux sombre voulu).

const GOLD: Color = Color(0.949, 0.757, 0.306)
const CREAM: Color = Color(0.957, 0.914, 0.804)

var _n: int = 0
var _mode: String = ""   # "reward" (menu) | "failure" (jeu)

func _ready() -> void:
	add_to_group("chapter_end_screen")
	%PrimaryButton.pressed.connect(_on_primary)
	%SecondaryButton.pressed.connect(_on_secondary)
	UIAnimations.wire_buttons(self)
	UIAnimations.make_glass_panel($Content)

# Pop-up de réussite au MENU (par-dessus la carte), après l'outro. AFFICHE seulement le gain.
func show_reward(n: int) -> void:
	_n = n
	_mode = "reward"
	%TitleLabel.text = "CHAPITRE RÉUSSI"
	%RewardLabel.visible = true
	%RewardLabel.text = "+ " + UIAnimations.format_number(Story.chapter_reward(n)) + " pièces"
	%PrimaryButton.text = "CONTINUER"
	%SecondaryButton.visible = false
	# Le son de fin de niveau a déjà été joué AU MOMENT DE LA VICTOIRE (main_game, sur le fondu) —
	# plus ici (il arrivait trop tard, après l'histoire). La musique est déjà baissée (hors jeu).
	# Contexte MENU : on N'arrête PAS l'arbre (la carte vit derrière, animée). On ne fait
	# qu'ouvrir le pop-up par-dessus.
	visible = true
	UIAnimations.pop_in($Content, $Tint)

func show_failure(n: int) -> void:
	_n = n
	_mode = "failure"
	%TitleLabel.text = "TU ES TOMBÉ"
	# Pas de pièces en échec : on réutilise le label en sous-titre doux.
	%RewardLabel.visible = true
	%RewardLabel.text = "On réessaie ?"
	%RewardLabel.add_theme_color_override("font_color", CREAM)
	%RewardLabel.add_theme_font_size_override("font_size", 28)
	%PrimaryButton.text = "RÉESSAYER"
	%SecondaryButton.visible = true
	%SecondaryButton.text = "RETOUR CAMPAGNE"
	_open()

func _open() -> void:
	Audio.duck_music()
	visible = true
	get_tree().paused = true
	UIAnimations.pop_in($Content, $Tint)

func _on_primary() -> void:
	Audio.play_ui_click()
	if _mode == "reward":
		# Contexte MENU : on referme simplement le pop-up (la carte est déjà derrière). Pas de
		# changement de scène, pas d'arbre en pause à relâcher. La musique RESTE baissée (on est
		# hors gameplay, sur la carte).
		visible = false
		return
	# Échec (en jeu) : on relance le même chapitre (Story.active persiste) → retry illimité.
	_leave_game()
	Transition.reload_scene()

func _on_secondary() -> void:
	# Uniquement en échec : retour campagne sans réussir (le chapitre reste à refaire).
	Audio.play_ui_click()
	_leave_game()
	Transition.change_scene("res://scenes/ui/main_menu.tscn")

func _leave_game() -> void:
	Audio.unduck_music()
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	get_tree().paused = false
