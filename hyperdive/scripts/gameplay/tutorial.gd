extends Node
class_name Tutorial
# Surcouche DIDACTICIEL — vit UNIQUEMENT au chapitre tuto (Story.is_tutorial(), ch.3).
# Ajoutée par main_game. Possède son propre CanvasLayer (au-dessus du HUD, sous la pause).
# Pilote : ralenti d'intro 0.2× tant que le joueur n'a pas donné d'input, deux textes pulsants
# en TEMPS RÉEL, et une rangée pleine largeur de slow-time inratable synchronisée avec le texte 2.
#
# Détection du 1er input : on s'abonne au signal PlayerController.first_input_received (point
# unique côté joueur, touch ET clavier) → garantie que le ralenti 0.2× se coupe TOUJOURS.

const INTRO_SPEED_FACTOR := 0.2     # info : la valeur effective vit dans PlayerController.TUTORIAL_INTRO_FACTOR
const TEXT1_HOLD_AFTER_INPUT := 2.0 # le texte 1 reste 2 s après le 1er input puis se fond
const GAP_BEFORE_TEXT2 := 7.0       # délai après le fondu du texte 1 avant texte 2 + rangée
const TEXT2_VISIBLE := 4.0          # durée d'affichage du texte 2 avant fondu
const FADE := 0.5                   # durée des fondus de texte
const PULSE_MIN := 1.0              # échelle de pulsation basse
const PULSE_MAX := 1.08            # échelle de pulsation haute
const PULSE_PERIOD := 1.2          # période de la pulsation (s)
const ROW_SPAWN_AHEAD := 30.0      # rangée spawnée à 30 m devant (dir) au moment du texte 2
const ROW_CLEAR_HALF := 8.0        # demi-bande sans obstacle autour de la rangée
const ROW_X_MIN := -5.0            # rangée pleine largeur (couloir = ±4,5)
const ROW_X_MAX := 5.0
const ROW_X_STEP := 1.0            # espacement (catch ~1 m/powerup → inratable)
const TUTORIAL_OBSTACLES_ENABLED := true   # false = aucun obstacle pendant le tuto

# Textes placeholder ÉDITABLES. Variante selon le mode de contrôle (tilt supprimé du jeu).
const TEXT1_TOUCH := "Glisse ton doigt pour te déplacer"
const TEXT1_KEY   := "Utilise ←  → pour te déplacer"
const TEXT2       := "Récupère les bonus pour t'aider\n— celui-ci ralentit le temps !"

const POWERUP_SCENE: PackedScene = preload("res://scenes/collectibles/powerup.tscn")

var _player: PlayerController
var _obstacles: ObstacleSpawner
var _label: Label
var _pulse_tween: Tween
var _done: bool = false        # texte 2 montré → la victoire à 150 m est autorisée
var _t2_timer: float = -1.0    # compte à rebours réel avant texte 2 (armé au fondu du texte 1)

func is_done() -> bool:
	return _done

func setup(player: PlayerController, obstacles: ObstacleSpawner) -> void:
	_player = player
	_obstacles = obstacles
	if not TUTORIAL_OBSTACLES_ENABLED and _obstacles != null:
		_obstacles.set_process(false)
	_build_ui()
	# Ralenti d'intro ON immédiatement + texte 1 (variante selon le mode de contrôle).
	_player.set_intro_slow(true)
	var touch: bool = Settings.control_mode == SettingsManager.ControlMode.TOUCH
	_show_text(TEXT1_TOUCH if touch else TEXT1_KEY)
	# Abonnement FIABLE au 1er input (signal du joueur). Si l'input est déjà passé (cas limite),
	# on réagit tout de suite ; sinon on attend le signal.
	if _player.has_first_input():
		_on_first_input()
	else:
		_player.first_input_received.connect(_on_first_input)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2   # au-dessus du HUD (1), sous la pause (5)
	add_child(layer)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.1
	_label.anchor_right = 0.9
	_label.anchor_top = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_top = -90.0
	_label.offset_bottom = 90.0
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))   # blanc translucide
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.5))
	_label.add_theme_constant_override("outline_size", 6)
	_label.modulate.a = 0.0
	layer.add_child(_label)

func _show_text(t: String) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_label.text = t
	_label.scale = Vector2.ONE
	_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, FADE)
	_start_pulse()

# Pulsation centrée : le pivot doit être au CENTRE du label, mais sa taille n'est connue
# qu'APRÈS le 1er layout → on attend une frame (ou que size > 0) avant de poser pivot_offset.
func _start_pulse() -> void:
	await get_tree().process_frame
	while _label != null and _label.size == Vector2.ZERO:
		await get_tree().process_frame
	if _label == null:
		return
	_label.pivot_offset = _label.size / 2.0
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_label, "scale", Vector2.ONE * PULSE_MAX, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_label, "scale", Vector2.ONE * PULSE_MIN, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE)

func _fade_out_text() -> void:
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 0.0, FADE)
	tw.tween_callback(func() -> void:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill())

func _on_first_input() -> void:
	_player.set_intro_slow(false)   # vitesse normale, TOUJOURS, dès le 1er input
	# Le texte 1 reste TEXT1_HOLD_AFTER_INPUT puis se fond, et ARME le compte à rebours du texte 2.
	await get_tree().create_timer(TEXT1_HOLD_AFTER_INPUT).timeout
	_fade_out_text()
	_t2_timer = GAP_BEFORE_TEXT2

func _process(delta: float) -> void:
	if _t2_timer > 0.0:
		_t2_timer -= delta
		if _t2_timer <= 0.0:
			_t2_timer = -1.0
			_trigger_text2_and_row()

func _trigger_text2_and_row() -> void:
	_show_text(TEXT2)
	_spawn_slowmo_row()
	_done = true   # leçon montrée → la victoire à 150 m est désormais autorisée
	await get_tree().create_timer(TEXT2_VISIBLE).timeout
	_fade_out_text()

# Rangée pleine largeur de slow-time, inratable, devant le joueur (dir-relatif). On nettoie une
# bande sans obstacle autour pour garantir le ramassage.
func _spawn_slowmo_row() -> void:
	var dir: float = Settings.get_fall_dir()   # -1 en chute (ch.3)
	var y: float = _player.global_position.y + dir * ROW_SPAWN_AHEAD
	if _obstacles != null and TUTORIAL_OBSTACLES_ENABLED:
		_obstacles.reserve_clear_band(y - ROW_CLEAR_HALF, y + ROW_CLEAR_HALF)
	var x: float = ROW_X_MIN
	while x <= ROW_X_MAX + 0.001:
		var pu: Powerup = POWERUP_SCENE.instantiate()
		pu.type = "slowmo"
		get_parent().add_child(pu)   # parent = MainGame (même que les autres spawns)
		pu.global_position = Vector3(x, y, 0.0)
		x += ROW_X_STEP
