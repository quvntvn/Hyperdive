extends Node3D
class_name MainGame

# Objectif de chapitre HISTOIRE en cours (lu depuis Story quand Story.active).
var _objective_kind: String = ""
var _objective_value: int = 0
var _story_time: float = 0.0
var _success_handled: bool = false
var _player_alive: bool = true
var _tutorial: Tutorial = null   # surcouche didacticiel (ch.1 « 2028 » uniquement)

func _ready() -> void:
	# La skyline est ancrée à la caméra. En jetpack (caméra vers le haut) on lui passe le
	# flag pour compenser le tangage et la garder en bas de l'écran comme en chute.
	# En campagne, le thème du CHAPITRE prime sur le thème équipé ("" hors campagne).
	CitySkyline.attach_to(get_viewport().get_camera_3d(), Settings.active_mode == "jetpack", Story.current_theme_id())
	# Overlay d'éclaboussures de sang (GLOBAL, tous modes) : player.gd le retrouve via le groupe
	# "blood_overlay" pour les taches de mur (fugaces) et de mort (permanentes).
	var blood := BloodOverlay.new()
	blood.name = "BloodOverlay"
	add_child(blood)
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
		if _objective_kind == "descent":
			_setup_descent()
			# Surcouche didacticiel (ch.1 « 2028 » uniquement) : nœud dédié + son propre CanvasLayer,
			# greffée PAR-DESSUS la descente scriptée (le sol à 150 m reste la victoire).
			if Story.is_tutorial():
				_tutorial = Tutorial.new()
				_tutorial.name = "Tutorial"
				add_child(_tutorial)
				_tutorial.setup($Player as PlayerController, $ObstacleSpawner as ObstacleSpawner)
			return
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
		"descent":
			# OUVERTURE ch.1 : ALTIMÈTRE DÉCROISSANT (mètres restants avant le sol), orange sous
			# 50 m (tension). AUCUNE réussite en vol — seule la collision avec le sol termine,
			# routée en réussite par player.gd (la mort EST la réussite).
			# DIDACTICIEL : tant que le joueur n'a pas donné son 1er input, l'altimètre est FIGÉ à
			# la valeur de départ (la progression est « en pause » — le perso dérive au ralenti
			# 2,5 % mais ces ~quelques mètres ne comptent pas). Au 1er toucher, le décompte démarre.
			if not player.has_first_input():
				($GameHUD as GameHUD).update_story_progress("%d m" % _objective_value)
				return
			var remaining: int = int(maxf(0.0, float(_objective_value) - absf(player.global_position.y)))
			($GameHUD as GameHUD).update_story_progress("%d m" % remaining)
			($GameHUD as GameHUD).set_story_progress_urgent(remaining <= 50)
			return
		_:
			return
	_push_progress(cur)
	if _objective_value > 0 and cur >= _objective_value:
		# DIDACTICIEL : on attend AUSSI que la séquence pédagogique soit finie (texte 2 montré),
		# sinon la victoire à 150 m (~9 s) couperait la leçon power-up.
		if _tutorial != null and not _tutorial.is_done():
			return
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

# OUVERTURE ch.1 (objectif "descent" : MOURIR = réussir) : chute scriptée, rien à esquiver ni à
# ramasser — obstacles et power-ups coupés (les pièces le sont déjà), MUSIQUE coupée (le whoosh
# seul porte la brutalité de la scène ; le menu la relance au retour), un SOL inévitable à
# `value` mètres et la famille en silhouettes qui se disperse pendant la descente.
func _setup_descent() -> void:
	$ObstacleSpawner.set_process(false)
	$PowerupSpawner.set_process(false)
	Audio.stop_music()
	_spawn_descent_ground(float(_objective_value))
	var fallers := StoryFallers.new()
	fallers.name = "StoryFallers"
	add_child(fallers)
	fallers.setup($Player, float(_objective_value))
	($GameHUD as GameHUD).update_story_progress("%d m" % _objective_value)

# Le sol de l'ouverture : une dalle SOMBRE (la rue en bas de la tour) bien plus large que le
# couloir — pas d'esquive possible. Surface EXACTEMENT à y = -dist (l'altimètre tombe à 0
# dessus). Groupe "obstacles" → la collision passe par le chemin de mort EXISTANT
# (player._on_body_entered → ragdoll), que player.gd route en réussite pour "descent".
func _spawn_descent_ground(dist: float) -> void:
	var ground := StaticBody3D.new()
	ground.name = "DescentGround"
	ground.add_to_group("obstacles")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 2.0, 60.0)
	shape.shape = box
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.11, 0.09, 0.08)   # asphalte noyer sombre (palette, décor terne)
	mesh.material_override = mat
	ground.add_child(mesh)
	ground.position = Vector3(0.0, -dist - 1.0, 0.0)   # demi-épaisseur 1 → top de dalle à -dist
	add_child(ground)

func _on_objective_success() -> void:
	_success_handled = true
	var player := $Player as PlayerController
	player.complete_run()   # fige le run (invincible, stats stoppées), le perso file encore
	# Un court instant de chute libre, puis on quitte vers la carte. La simulation coupe net —
	# pas d'atterrissage héroïque (l'ancien parachute ne collait plus au ton de l'histoire).
	await get_tree().create_timer(0.5).timeout
	Audio.stop_whoosh()
	Audio.stop_jetpack()
	var n: int = Story.active_chapter
	var ch: Dictionary = Story.get_chapter(n)
	# Crédite les pièces UNE seule fois ici (+ déblocages + avance). Le pop-up de réussite
	# affiché plus tard ne fait que MONTRER ce gain, il ne crédite rien.
	Story.complete_chapter(n)
	# Nouveau flux : on NE montre PLUS le pop-up "Chapitre réussi" en jeu. On va d'abord lire
	# l'HISTOIRE (outro), puis le pop-up récompense s'affiche PAR-DESSUS au retour menu.
	# pending_outro → la carte ouvre le lecteur en mode "outro" ; pending_reward → après le
	# CONTINUER de l'outro, le pop-up récompense apparaît (retour carte ensuite).
	if ch.get("text_when", "before") == "after":
		Story.pending_outro = n
	Story.pending_reward = n
	# Fondu au noir DOUX (~1 s) avant le chargement de la carte (l'ancien fondu était trop sec).
	Transition.change_scene("res://scenes/ui/main_menu.tscn", 1.0)
