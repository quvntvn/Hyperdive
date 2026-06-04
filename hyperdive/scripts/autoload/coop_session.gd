extends Node
class_name CoopSession
# Autoload "Coop" — état d'une session coop pass-and-play (TRANSIENT, non persisté).
#
# Coop.active = LE garde-fou global. Quand true, le contexte coop est une SURCOUCHE sur le
# gameplay solo : player.gd / main_game.gd lisent ce flag pour (a) forcer la couleur du
# joueur, (b) couper les pièces, (c) court-circuiter TOUS les hooks de stats perso, (d)
# rediriger la mort vers le flux coop. false par défaut → le mode solo est intouchable.
#
# Le modèle (scores, barème de points, classements) vit ICI. Les écrans (config, passation,
# classement, final) ne font que lire/appeler cette API. Le routage entre scènes arrive au
# commit 2 (quand les écrans de passation/classement existent).

# Couleurs d'identité par joueur (palette stricte du jeu) :
# J1 orange brûlé, J2 turquoise rétro, J3 jaune moutarde, J4 bleu nuit doux.
const PLAYER_COLORS: Array[Color] = [
	Color(0.914, 0.310, 0.216),  # J1 #E94F37
	Color(0.235, 0.682, 0.639),  # J2 #3CAEA3
	Color(0.949, 0.757, 0.306),  # J3 #F2C14E
	Color(0.122, 0.188, 0.369),  # J4 #1F305E
]

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4
const MIN_ROUNDS: int = 1
const MAX_ROUNDS: int = 10

# Barème de points par PLACE (façon ranked / Mario Kart). Index 0 = 1re place.
# Avec N joueurs on n'utilise que les N premières valeurs (à 2 j. : 10/6 ; à 3 : 10/6/3).
const PLACE_POINTS: Array[int] = [10, 6, 3, 1]

# États de routage renvoyés par advance_after_turn().
enum { NEXT_PLAYER, ROUND_OVER }

# Chemins de scènes du flux coop (toutes les transitions passent par cet autoload → un seul
# endroit qui connaît les scènes). Le classement de manche / l'écran final arrivent aux
# commits 3-4 ; d'ici là ROUND_OVER retombe sur un placeholder (retour menu + log).
const SCENE_MAIN_GAME := "res://scenes/game/main_game.tscn"
const SCENE_PASSATION := "res://scenes/ui/coop_passation.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu.tscn"

# === Config (figée au start_session) ===
var num_players: int = 2
var num_rounds: int = 5
var mode_choice: String = "mix"   # "mix" | "infinite" | "jetpack"

# === Joueurs ===
var player_names: Array[String] = []
# scores[player][round] = int (distance/altitude atteinte ce tour). 0 = non encore joué.
var scores: Array = []

# === Modes par manche (Mix pré-tiré au start → MÊME mode pour tous les joueurs d'une manche) ===
var round_modes: Array[String] = []

# === Curseurs (machine à états pass-and-play) ===
var current_round: int = 0    # 0-based
var current_player: int = 0   # 0-based
var active: bool = false       # garde-fou global du contexte coop

# ──────────────────────────────────────────────────────────────────────────────
# Cycle de vie de session
# ──────────────────────────────────────────────────────────────────────────────

# Démarre (ou redémarre) une session : reset COMPLET, aucun résidu de la précédente.
# p_names : pseudos saisis (peut être plus court / vide → complété en "Joueur N").
func start_session(p_num_players: int, p_num_rounds: int, p_mode: String, p_names: Array) -> void:
	num_players = clampi(p_num_players, MIN_PLAYERS, MAX_PLAYERS)
	num_rounds = clampi(p_num_rounds, MIN_ROUNDS, MAX_ROUNDS)
	mode_choice = p_mode

	player_names = []
	for i in range(num_players):
		var nm: String = ""
		if i < p_names.size():
			nm = String(p_names[i]).strip_edges()
		player_names.append(nm if nm != "" else "Joueur %d" % (i + 1))

	scores = []
	for i in range(num_players):
		var row: Array = []
		for r in range(num_rounds):
			row.append(0)
		scores.append(row)

	# Pré-tirage des modes : Mix → tiré aléatoirement par manche ; sinon le mode choisi répété.
	round_modes = []
	for r in range(num_rounds):
		round_modes.append(_roll_round_mode())

	current_round = 0
	current_player = 0
	active = true
	print("[coop] start: %d joueurs, %d manches, mode=%s, modes=%s, noms=%s"
		% [num_players, num_rounds, mode_choice, str(round_modes), str(player_names)])

func _roll_round_mode() -> String:
	match mode_choice:
		"infinite": return "infinite"
		"jetpack":  return "jetpack"
		_:          return "jetpack" if randi() % 2 == 0 else "infinite"   # mix

# Réinitialise tout et coupe le contexte coop (appelé au retour menu).
func clear() -> void:
	active = false
	scores = []
	round_modes = []
	player_names = []
	num_players = 2
	num_rounds = 5
	current_round = 0
	current_player = 0

# ──────────────────────────────────────────────────────────────────────────────
# Accès au tour courant
# ──────────────────────────────────────────────────────────────────────────────

func current_mode() -> String:
	return round_modes[current_round] if current_round < round_modes.size() else "infinite"

func current_color() -> Color:
	return player_color(current_player)

func current_name() -> String:
	return player_names[current_player] if current_player < player_names.size() else ""

# Couleur d'un joueur (bornée à la palette ; au-delà → blanc, ne devrait pas arriver).
func player_color(p: int) -> Color:
	return PLAYER_COLORS[p] if p >= 0 and p < PLAYER_COLORS.size() else Color.WHITE

# Numéro de manche affichable (1-based) et libellé de mode.
func round_label() -> String:
	return "MANCHE %d / %d" % [current_round + 1, num_rounds]

func mode_label(mode: String) -> String:
	return "JETPACK" if mode == "jetpack" else "CLASSIQUE"

# ──────────────────────────────────────────────────────────────────────────────
# Enregistrement d'un tour + avance des curseurs
# ──────────────────────────────────────────────────────────────────────────────

# Score (distance/altitude) du joueur courant pour la manche courante.
func record_turn(score: int) -> void:
	if current_player < scores.size() and current_round < scores[current_player].size():
		scores[current_player][current_round] = score

# Avance APRÈS un tour. Renvoie NEXT_PLAYER (un joueur reste sur cette manche → passation)
# ou ROUND_OVER (tous les joueurs ont joué la manche → écran de classement de manche).
# Au ROUND_OVER, current_player reste sur le dernier joueur (sans importance, on lit toute
# la manche au classement). Le passage à la manche suivante se fait via start_next_round().
func advance_after_turn() -> int:
	if current_player + 1 < num_players:
		current_player += 1
		return NEXT_PLAYER
	return ROUND_OVER

func is_last_round() -> bool:
	return current_round + 1 >= num_rounds

# Appelé depuis l'écran de classement de manche (CONTINUER) quand ce n'est PAS la dernière.
func start_next_round() -> void:
	current_round += 1
	current_player = 0

# ──────────────────────────────────────────────────────────────────────────────
# Routage entre scènes (toutes les transitions du flux coop passent par ici)
# ──────────────────────────────────────────────────────────────────────────────

# Config terminé : on entre dans le flux par la passation du 1er joueur.
func begin_session_flow() -> void:
	Transition.change_scene(SCENE_PASSATION)

# Passation PRÊT : on pose le mode de la manche (le gameplay solo le lit tel quel) et on
# lance la partie. C'est la SEULE chose qui distingue le mode au niveau du player.
func go_to_turn() -> void:
	Settings.active_mode = current_mode()
	Transition.change_scene(SCENE_MAIN_GAME)

# Fin d'un tour (appelé depuis l'interception de la mort dans player.gd). Enregistre le
# score puis route : joueur suivant → passation ; manche finie → classement (placeholder
# commit 2 en attendant le vrai écran de classement au commit 3).
func end_turn(score: int) -> void:
	record_turn(score)
	var step: int = advance_after_turn()
	if step == NEXT_PLAYER:
		Transition.change_scene(SCENE_PASSATION)
	else:
		_round_over_placeholder()

# PLACEHOLDER commit 2 : log du classement de la manche + retour menu. Remplacé au commit 3
# (écran de classement) puis 4 (boucle de manches + écran final).
func _round_over_placeholder() -> void:
	print("[coop] manche %d terminée — classement :" % (current_round + 1))
	for e in round_ranking(current_round):
		print("  J%d %s : %d → place %d (+%d pts)"
			% [int(e["player"]) + 1, player_names[e["player"]], int(e["score"]),
			   int(e["place"]) + 1, int(e["points"])])
	clear()
	Transition.change_scene(SCENE_MENU)

# ──────────────────────────────────────────────────────────────────────────────
# Scoring / classements (logique pure, sans UI)
# ──────────────────────────────────────────────────────────────────────────────

# Points gagnés à une PLACE (0-based). Hors barème (place trop lointaine) → 0.
func points_for_place(place: int) -> int:
	return PLACE_POINTS[place] if place >= 0 and place < PLACE_POINTS.size() else 0

# Classement d'UNE manche, trié par score décroissant. Gère les ex-æquo en "competition
# ranking" : place = nombre de joueurs STRICTEMENT meilleurs → même score = même place =
# mêmes points (ex : deux 1ers à 10 pts, puis le suivant en place 2 = 3 pts).
# Renvoie un Array de { player, score, place, points }.
func round_ranking(r: int) -> Array:
	var entries: Array = []
	for p in range(num_players):
		entries.append({"player": p, "score": int(scores[p][r])})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["player"] < b["player"]
	)
	for e in entries:
		var place: int = 0
		for other in entries:
			if other["score"] > e["score"]:
				place += 1
		e["place"] = place
		e["points"] = points_for_place(place)
	return entries

# Points d'un joueur sur les manches 0..last_round inclus (les manches non jouées sont
# exclues en passant le bon last_round → évite de compter des 0 à 0 comme des ex-æquo).
func points_through(p: int, last_round: int) -> int:
	var total: int = 0
	for r in range(mini(last_round + 1, num_rounds)):
		for e in round_ranking(r):
			if e["player"] == p:
				total += int(e["points"])
				break
	return total

func _best_single_score(p: int, last_round: int) -> int:
	var best: int = 0
	for r in range(mini(last_round + 1, num_rounds)):
		best = maxi(best, int(scores[p][r]))
	return best

func _rounds_won(p: int, last_round: int) -> int:
	var won: int = 0
	for r in range(mini(last_round + 1, num_rounds)):
		for e in round_ranking(r):
			if e["player"] == p:
				if int(e["place"]) == 0:
					won += 1
				break
	return won

# Classement GÉNÉRAL après les manches 0..last_round, trié par points décroissants.
# Départage : meilleur score unique sur l'ensemble → manches gagnées (1res places) → index.
# Renvoie un Array de { player, points, best_score, rounds_won }.
func standings(last_round: int) -> Array:
	var entries: Array = []
	for p in range(num_players):
		entries.append({
			"player": p,
			"points": points_through(p, last_round),
			"best_score": _best_single_score(p, last_round),
			"rounds_won": _rounds_won(p, last_round),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["best_score"] != b["best_score"]:
			return a["best_score"] > b["best_score"]
		if a["rounds_won"] != b["rounds_won"]:
			return a["rounds_won"] > b["rounds_won"]
		return a["player"] < b["player"]
	)
	return entries
