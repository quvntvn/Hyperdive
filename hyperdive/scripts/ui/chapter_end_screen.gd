extends CanvasLayer
class_name ChapterEndScreen
# Overlay de fin de chapitre HISTOIRE, en surcouche sur le jeu (le décor reste derrière, flouté).
# Deux états :
#   VICTOIRE : "Chapitre réussi" + pièces gagnées + CONTINUER (→ outro si "after", sinon carte).
#   ÉCHEC    : "Tu es tombé" + RÉESSAYER (relance le même chapitre) + RETOUR CAMPAGNE.
# Échec = retry illimité doux : aucune stat, aucune perte (le chapitre n'est complété qu'en jeu,
# sur objectif atteint — pas ici).

const GOLD: Color = Color(0.949, 0.757, 0.306)
const CREAM: Color = Color(0.957, 0.914, 0.804)

var _n: int = 0
var _has_outro: bool = false
var _mode: String = ""   # "victory" | "failure"

func _ready() -> void:
	add_to_group("chapter_end_screen")
	%PrimaryButton.pressed.connect(_on_primary)
	%SecondaryButton.pressed.connect(_on_secondary)
	UIAnimations.wire_buttons(self)
	UIAnimations.make_glass_panel($Content)

func show_victory(n: int, reward: int, has_outro: bool) -> void:
	_n = n
	_mode = "victory"
	_has_outro = has_outro
	%TitleLabel.text = "CHAPITRE RÉUSSI"
	%RewardLabel.visible = true
	%RewardLabel.text = "+ " + UIAnimations.format_number(reward) + " pièces"
	%PrimaryButton.text = "CONTINUER"
	%SecondaryButton.visible = false
	# Son triomphant de réussite (bus SFX, non ducké). Gaté par chapitre : un chapitre marqué
	# "no_win_sfx" reste silencieux. Le ch.1 "descent" ne passe pas ici (mort = réussite → outro),
	# donc l'impact "2028" n'est jamais accompagné de la fanfare.
	if Story.chapter_plays_win_sfx(n):
		Audio.play_level_complete()
	_open()

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
	_leave_game()
	if _mode == "failure":
		Transition.reload_scene()   # même chapitre (Story.active persiste) → retry illimité
		return
	# Victoire : si le chapitre a un texte "after", on le lit (outro) au retour ; sinon carte directe.
	if _has_outro:
		Story.pending_outro = _n
	Transition.change_scene("res://scenes/ui/main_menu.tscn")

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
