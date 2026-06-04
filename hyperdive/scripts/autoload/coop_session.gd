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

# Couleurs d'identité par joueur (5 teintes bien distinctes) :
# J1 orange, J2 turquoise, J3 jaune moutarde, J4 rose, J5 vert.
const PLAYER_COLORS: Array[Color] = [
	Color(0.914, 0.310, 0.216),  # J1 #E94F37 orange brûlé
	Color(0.235, 0.682, 0.639),  # J2 #3CAEA3 turquoise rétro
	Color(0.949, 0.757, 0.306),  # J3 #F2C14E jaune moutarde
	Color(0.925, 0.282, 0.600),  # J4 #EC4899 rose
	Color(0.298, 0.686, 0.314),  # J5 #4CAF50 vert
]

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 5
const MIN_ROUNDS: int = 1
const MAX_ROUNDS: int = 10

# Barème de points par PLACE (façon ranked / Mario Kart). Index 0 = 1re place.
# Avec N joueurs on n'utilise que les N premières valeurs (à 2 j. : 10/7 ; à 3 : 10/7/5…).
const PLACE_POINTS: Array[int] = [10, 7, 5, 3, 1]

# États de routage renvoyés par advance_after_turn().
enum { NEXT_PLAYER, ROUND_OVER }

# Chemins de scènes du flux coop (toutes les transitions passent par cet autoload → un seul
# endroit qui connaît les scènes). Le classement de manche / l'écran final arrivent aux
# commits 3-4 ; d'ici là ROUND_OVER retombe sur un placeholder (retour menu + log).
const SCENE_MAIN_GAME := "res://scenes/game/main_game.tscn"
const SCENE_PASSATION := "res://scenes/ui/coop_passation.tscn"
const SCENE_ROUND_RESULT := "res://scenes/ui/coop_round_result.tscn"
const SCENE_TIEBREAK := "res://scenes/ui/coop_tiebreak.tscn"
const SCENE_FINAL := "res://scenes/ui/coop_final.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu.tscn"

# === Config (figée au start_session) ===
var num_players: int = 2
var num_rounds: int = 3
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

# === Round final de départage (tiebreak) — déclenché si égalité de points à la 1re place ===
var tiebreak_active: bool = false       # surcouche : un round joué seulement par les ex-æquo
var tiebreak_players: Array = []        # contenders du round final COURANT
var tiebreak_scores: Dictionary = {}    # joueur -> score du round final courant
var tiebreak_cur_idx: int = 0           # index dans tiebreak_players du joueur qui joue
var tiebreak_mode: String = "infinite"  # mode tiré pour ce round final
var tiebreak_winner: int = -1           # vainqueur départagé (-1 tant que non résolu)
var tiebreak_orig_leaders: Array = []   # ex-æquo 1re place INITIAUX (pour le classement final)
var tiebreak_last_scores: Dictionary = {}  # scores du DERNIER round final résolutif
var tiebreak_bonus: Dictionary = {}     # joueur -> points bonus (+1 au vainqueur du départage)

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
	_reset_tiebreak()
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
	num_rounds = 3
	current_round = 0
	current_player = 0
	_reset_tiebreak()

func _reset_tiebreak() -> void:
	tiebreak_active = false
	tiebreak_players = []
	tiebreak_scores = {}
	tiebreak_cur_idx = 0
	tiebreak_mode = "infinite"
	tiebreak_winner = -1
	tiebreak_orig_leaders = []
	tiebreak_last_scores = {}
	tiebreak_bonus = {}

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
# Contexte du TOUR courant — abstrait "manche normale" vs "round final de départage".
# La passation, le HUD live et l'interception de la mort lisent CE contexte → un seul code
# pour les deux cas. En tiebreak, seuls les ex-æquo (tiebreak_players) sont concernés.
# ──────────────────────────────────────────────────────────────────────────────

func turn_current_player() -> int:
	return tiebreak_players[tiebreak_cur_idx] if tiebreak_active else current_player

func turn_mode() -> String:
	return tiebreak_mode if tiebreak_active else current_mode()

func turn_color() -> Color:
	return player_color(turn_current_player())

func turn_name() -> String:
	return player_names[turn_current_player()]

func turn_round_label() -> String:
	return "ROUND FINAL" if tiebreak_active else round_label()

# Joueurs concernés par ce tour-round (tous, ou seulement les ex-æquo en tiebreak).
func turn_players() -> Array:
	if tiebreak_active:
		return tiebreak_players.duplicate()
	var a: Array = []
	for i in range(num_players):
		a.append(i)
	return a

# Score d'un joueur pour CE tour-round (manche courante, ou round final).
func turn_score(p: int) -> int:
	return int(tiebreak_scores.get(p, 0)) if tiebreak_active else int(scores[p][current_round])

# Le joueur p (≠ courant) a-t-il déjà joué ce tour-round ? (ordre de jeu = ordre d'index)
func turn_has_played(p: int) -> bool:
	if tiebreak_active:
		return tiebreak_scores.has(p)
	return p < current_player

func turn_done_players() -> Array:
	var cur: int = turn_current_player()
	var out: Array = []
	for p in turn_players():
		if p != cur and turn_has_played(p):
			out.append(p)
	return out

func turn_pending_players() -> Array:
	var cur: int = turn_current_player()
	var out: Array = []
	for p in turn_players():
		if p != cur and not turn_has_played(p):
			out.append(p)
	return out

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
	Settings.active_mode = turn_mode()   # normal : mode de la manche ; tiebreak : mode tiré
	Transition.change_scene(SCENE_MAIN_GAME)

# Fin d'un tour (appelé depuis l'interception de la mort dans player.gd). En tiebreak, route
# vers le départage ; sinon : joueur suivant → passation, ou manche finie → classement.
func end_turn(score: int) -> void:
	if tiebreak_active:
		_tiebreak_record_and_advance(score)
		return
	record_turn(score)
	var step: int = advance_after_turn()
	if step == NEXT_PLAYER:
		Transition.change_scene(SCENE_PASSATION)
	else:
		Transition.change_scene(SCENE_ROUND_RESULT)

# Classement de manche CONTINUER : manche suivante (passation J1), ou fin de session →
# départage (si égalité de points à la 1re place) ou écran final.
func continue_after_round() -> void:
	if is_last_round():
		_finish_or_tiebreak()
	else:
		start_next_round()
		Transition.change_scene(SCENE_PASSATION)

# Écran final REJOUER : relance une session avec la MÊME config (mêmes joueurs/pseudos,
# mode, nombre de manches) → en Mix les modes sont re-tirés. Puis on entre par la passation.
func restart_same_config() -> void:
	start_session(num_players, num_rounds, mode_choice, player_names.duplicate())
	begin_session_flow()

# ──────────────────────────────────────────────────────────────────────────────
# Round final de départage (tiebreak)
# ──────────────────────────────────────────────────────────────────────────────

# Fin de la dernière manche : s'il y a égalité de POINTS à la 1re place → round final entre
# ces ex-æquo ; sinon → écran final directement.
func _finish_or_tiebreak() -> void:
	var leaders: Array = _first_place_leaders()
	if leaders.size() > 1:
		tiebreak_orig_leaders = leaders.duplicate()
		_start_tiebreak(leaders)
	else:
		Transition.change_scene(SCENE_FINAL)

# Joueurs partageant le maximum de points (candidats au départage de la 1re place).
func _first_place_leaders() -> Array:
	var st: Array = standings(num_rounds - 1)
	var max_pts: int = int(st[0]["points"])
	var leaders: Array = []
	for e in st:
		if int(e["points"]) == max_pts:
			leaders.append(int(e["player"]))
	return leaders

# Lance (ou relance après re-égalité) un round final entre `players` : mode tiré aléatoirement,
# scores remis à zéro, annonce "ÉGALITÉ ! ROUND FINAL" avant la passation.
func _start_tiebreak(players: Array) -> void:
	tiebreak_active = true
	tiebreak_players = players.duplicate()
	tiebreak_scores = {}
	tiebreak_cur_idx = 0
	tiebreak_mode = "jetpack" if randi() % 2 == 0 else "infinite"
	print("[coop] ÉGALITÉ 1re place — round final entre %s, mode=%s" % [str(tiebreak_players), tiebreak_mode])
	Transition.change_scene(SCENE_TIEBREAK)

# Annonce "ROUND FINAL" → entrée dans la passation du 1er ex-æquo.
func begin_tiebreak_turn() -> void:
	Transition.change_scene(SCENE_PASSATION)

func _tiebreak_record_and_advance(score: int) -> void:
	tiebreak_scores[tiebreak_players[tiebreak_cur_idx]] = score
	tiebreak_cur_idx += 1
	if tiebreak_cur_idx < tiebreak_players.size():
		Transition.change_scene(SCENE_PASSATION)   # ex-æquo suivant
	else:
		_resolve_tiebreak()

# Compare les scores du round final : un seul meilleur → vainqueur (écran final) ; re-égalité
# → nouveau round final entre les nouveaux ex-æquo (boucle jusqu'à départage).
func _resolve_tiebreak() -> void:
	var best: int = -1
	for p in tiebreak_players:
		best = maxi(best, int(tiebreak_scores[p]))
	var winners: Array = []
	for p in tiebreak_players:
		if int(tiebreak_scores[p]) == best:
			winners.append(p)
	if winners.size() == 1:
		tiebreak_winner = winners[0]
		tiebreak_last_scores = tiebreak_scores.duplicate()
		# +1 point bonus au vainqueur du départage → il passe officiellement devant les ex-æquo
		# au classement de points (plus d'égalité affichée à la 1re place). Va au vainqueur FINAL
		# si plusieurs rounds finals se sont enchaînés (récompense le départage tranché).
		tiebreak_bonus[tiebreak_winner] = 1
		tiebreak_active = false
		Transition.change_scene(SCENE_FINAL)
	else:
		_start_tiebreak(winners)   # re-égalité → on relance entre les ex-æquo restants

# Classement final affiché : si départage, le vainqueur passe en tête de son groupe d'ex-æquo
# (puis les autres ex-æquo selon le dernier round final) ; le reste suit le classement points.
func final_standings() -> Array:
	var st: Array = standings(num_rounds - 1)
	if tiebreak_winner < 0:
		return st
	var leaders: Array = []
	var rest: Array = []
	for e in st:
		if int(e["player"]) in tiebreak_orig_leaders:
			leaders.append(e)
		else:
			rest.append(e)
	leaders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = int(a["player"])
		var pb: int = int(b["player"])
		if pa == tiebreak_winner:
			return true
		if pb == tiebreak_winner:
			return false
		var sa: int = int(tiebreak_last_scores.get(pa, 0))
		var sb: int = int(tiebreak_last_scores.get(pb, 0))
		if sa != sb:
			return sa > sb
		return pa < pb)
	return leaders + rest

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
			# +bonus = +1 au vainqueur d'un round final de départage (vide hors départage).
			"player": p,
			"points": points_through(p, last_round) + int(tiebreak_bonus.get(p, 0)),
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
