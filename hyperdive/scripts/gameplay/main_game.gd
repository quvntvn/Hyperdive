extends Node3D
class_name MainGame

# Objectif de chapitre HISTOIRE en cours (lu depuis Story quand Story.active).
var _objective_kind: String = ""
var _objective_value: int = 0
var _story_time: float = 0.0
var _success_handled: bool = false
var _player_alive: bool = true

func _ready() -> void:
	# La skyline est ancrée à la caméra. En jetpack (caméra vers le haut) on lui passe le
	# flag pour compenser le tangage et la garder en bas de l'écran comme en chute.
	CitySkyline.attach_to(get_viewport().get_camera_3d(), Settings.active_mode == "jetpack")
	# COOP : pièces OFF + power-up sans aimant (branche campagne du spawner), mais PAS d'objectif
	# — la manche coop se joue jusqu'à la mort (mode infini/jetpack), classement live au HUD.
	if Coop.active:
		$CoinSpawner.set_process(false)
		($PowerupSpawner as PowerupSpawner).set_campaign_mode(true)
		($GameHUD as GameHUD).set_coop_mode()
		return
	# HISTOIRE (chapitre jouable) : pièces OFF + power-up sans aimant (même setup que coop), et
	# un OBJECTIF (distance/survie/esquive) dont la réussite déclenche l'écran de victoire.
	if Story.active:
		$CoinSpawner.set_process(false)
		($PowerupSpawner as PowerupSpawner).set_campaign_mode(true)
		var obj: Dictionary = Story.current_objective()
		_objective_kind = obj.get("kind", "")
		_objective_value = int(obj.get("value", 0))
		($GameHUD as GameHUD).set_campaign_mode(true)   # masque les pièces + fige l'auto-distance
		_push_progress(0)
		($Player as PlayerController).game_over.connect(func() -> void: _player_alive = false)
		return

func _process(delta: float) -> void:
	if not Story.active or _success_handled or not _player_alive:
		return
	var player := $Player as PlayerController
	var cur: int = 0
	match _objective_kind:
		"distance":
			cur = int(abs(player.global_position.y))
		"survive":
			_story_time += delta
			cur = int(_story_time)
		"dodge":
			cur = Story.dodged
		_:
			return   # "descent" (ch.1) = ouverture spéciale (étape 4), non gérée ici
	_push_progress(cur)
	if _objective_value > 0 and cur >= _objective_value:
		_on_objective_success()

# Met à jour la progression vers l'objectif dans le HUD ("320 / 800 m", "12 / 24 s"…).
func _push_progress(cur: int) -> void:
	var t: String = ""
	match _objective_kind:
		"distance": t = "%d / %d m" % [cur, _objective_value]
		"survive":  t = "%d / %d s" % [cur, _objective_value]
		"dodge":    t = "%d / %d esquives" % [cur, _objective_value]
		_:          return
	($GameHUD as GameHUD).update_story_progress(t)

func _on_objective_success() -> void:
	_success_handled = true
	var player := $Player as PlayerController
	await player.win_parachute()   # redressement parachute (anim de victoire)
	var n: int = Story.active_chapter
	var ch: Dictionary = Story.get_chapter(n)
	var reward: int = Story.chapter_reward(n)
	Story.complete_chapter(n)      # crédite pièces + déblocages + avance la progression
	var has_outro: bool = ch.get("text_when", "before") == "after"
	var screen := get_tree().get_first_node_in_group("chapter_end_screen")
	if screen:
		screen.show_victory(n, reward, has_outro)
	else:
		Transition.change_scene("res://scenes/ui/main_menu.tscn")
