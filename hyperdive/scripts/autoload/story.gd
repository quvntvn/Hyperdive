extends Node
class_name StoryManager
# Autoload "Story" — campagne narrative de 40 chapitres (l'histoire de Hyperdive).
# Modèle du pattern Coop : porte (1) le CATALOGUE des chapitres, (2) le flag `active`
# (garde-fou global qui court-circuite les stats perso, comme Coop.active), (3) l'état du
# run de chapitre (chapitre courant + compteur d'esquive pour l'objectif "dodge").
#
# Progression : Settings.story_chapter (persisté). Débloquage LINÉAIRE — story_chapter = le
# plus haut chapitre débloqué = chapitre COURANT à faire. < courant = complété, > = verrouillé.
#
# IMPORTANT pièces : compléter un chapitre crédite des pièces (coins_total + coins_lifetime),
# volontairement NON gaté (c'est la monnaie réelle du shop). Le RESTE des stats (records
# distance/jetpack, parties, morts…) reste gaté par `active` → la campagne ne pollue jamais
# les records solo.
#
# Structure d'un chapitre :
#   { n, title, text, image, type }  + si type == "play" : mode, objective {kind, value}, text_when
#   type     : "story" (narration : lire pour avancer) | "play" (jouable : un niveau à réussir)
#   mode     : "fall" (chute) | "jetpack" (montée)         (pas de coop dans les chapitres)
#   objective:
#     "distance" : atteindre value mètres    | "survive" : survivre value secondes
#     "dodge"    : esquiver value obstacles   | "descent" : OUVERTURE (ch.1) — MOURIR = réussir
#   text_when : "before" (lire avant le niveau) | "after" (lire après la réussite)
#
# NB : les textes et titres ci-dessous sont des PLACEHOLDERS (« [texte à venir] »). La grille
# (type / mode / objectif / before-after par chapitre) sera ajustée avec les 40 vrais textes.

const CHAPTERS: Array[Dictionary] = [
	{"n": 1,  "type": "play",  "mode": "fall",    "objective": {"kind": "descent",  "value": 0},    "text_when": "after",  "title": "Chapitre 1",  "text": "Chapitre 1 — [texte à venir]",  "image": "res://assets/story/ch01.png"},
	{"n": 2,  "type": "story",                                                                                            "title": "Chapitre 2",  "text": "Chapitre 2 — [texte à venir]",  "image": "res://assets/story/ch02.png"},
	{"n": 3,  "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 460},  "text_when": "before", "title": "Chapitre 3",  "text": "Chapitre 3 — [texte à venir]",  "image": "res://assets/story/ch03.png"},
	{"n": 4,  "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 24},   "text_when": "before", "title": "Chapitre 4",  "text": "Chapitre 4 — [texte à venir]",  "image": "res://assets/story/ch04.png"},
	{"n": 5,  "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 15},   "text_when": "before", "title": "Chapitre 5",  "text": "Chapitre 5 — [texte à venir]",  "image": "res://assets/story/ch05.png"},
	{"n": 6,  "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 520},  "text_when": "before", "title": "Chapitre 6",  "text": "Chapitre 6 — [texte à venir]",  "image": "res://assets/story/ch06.png"},
	{"n": 7,  "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 27},   "text_when": "before", "title": "Chapitre 7",  "text": "Chapitre 7 — [texte à venir]",  "image": "res://assets/story/ch07.png"},
	{"n": 8,  "type": "story",                                                                                            "title": "Chapitre 8",  "text": "Chapitre 8 — [texte à venir]",  "image": "res://assets/story/ch08.png"},
	{"n": 9,  "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 580},  "text_when": "before", "title": "Chapitre 9",  "text": "Chapitre 9 — [texte à venir]",  "image": "res://assets/story/ch09.png"},
	{"n": 10, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 30},   "text_when": "before", "title": "Chapitre 10", "text": "Chapitre 10 — [texte à venir]", "image": "res://assets/story/ch10.png"},
	{"n": 11, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 21},   "text_when": "before", "title": "Chapitre 11", "text": "Chapitre 11 — [texte à venir]", "image": "res://assets/story/ch11.png"},
	{"n": 12, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 640},  "text_when": "before", "title": "Chapitre 12", "text": "Chapitre 12 — [texte à venir]", "image": "res://assets/story/ch12.png"},
	{"n": 13, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 33},   "text_when": "before", "title": "Chapitre 13", "text": "Chapitre 13 — [texte à venir]", "image": "res://assets/story/ch13.png"},
	{"n": 14, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 24},   "text_when": "before", "title": "Chapitre 14", "text": "Chapitre 14 — [texte à venir]", "image": "res://assets/story/ch14.png"},
	{"n": 15, "type": "story",                                                                                            "title": "Chapitre 15", "text": "Chapitre 15 — [texte à venir]", "image": "res://assets/story/ch15.png"},
	{"n": 16, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 36},   "text_when": "before", "title": "Chapitre 16", "text": "Chapitre 16 — [texte à venir]", "image": "res://assets/story/ch16.png"},
	{"n": 17, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 27},   "text_when": "before", "title": "Chapitre 17", "text": "Chapitre 17 — [texte à venir]", "image": "res://assets/story/ch17.png"},
	{"n": 18, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 760},  "text_when": "before", "title": "Chapitre 18", "text": "Chapitre 18 — [texte à venir]", "image": "res://assets/story/ch18.png"},
	{"n": 19, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 39},   "text_when": "before", "title": "Chapitre 19", "text": "Chapitre 19 — [texte à venir]", "image": "res://assets/story/ch19.png"},
	{"n": 20, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 30},   "text_when": "before", "title": "Chapitre 20", "text": "Chapitre 20 — [texte à venir]", "image": "res://assets/story/ch20.png"},
	{"n": 21, "type": "play",  "mode": "jetpack", "objective": {"kind": "distance", "value": 820},  "text_when": "before", "title": "Chapitre 21", "text": "Chapitre 21 — [texte à venir]", "image": "res://assets/story/ch21.png"},
	{"n": 22, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 42},   "text_when": "before", "title": "Chapitre 22", "text": "Chapitre 22 — [texte à venir]", "image": "res://assets/story/ch22.png"},
	{"n": 23, "type": "story",                                                                                            "title": "Chapitre 23", "text": "Chapitre 23 — [texte à venir]", "image": "res://assets/story/ch23.png"},
	{"n": 24, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 880},  "text_when": "before", "title": "Chapitre 24", "text": "Chapitre 24 — [texte à venir]", "image": "res://assets/story/ch24.png"},
	{"n": 25, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 45},   "text_when": "before", "title": "Chapitre 25", "text": "Chapitre 25 — [texte à venir]", "image": "res://assets/story/ch25.png"},
	{"n": 26, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 36},   "text_when": "before", "title": "Chapitre 26", "text": "Chapitre 26 — [texte à venir]", "image": "res://assets/story/ch26.png"},
	{"n": 27, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 940},  "text_when": "before", "title": "Chapitre 27", "text": "Chapitre 27 — [texte à venir]", "image": "res://assets/story/ch27.png"},
	{"n": 28, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 48},   "text_when": "before", "title": "Chapitre 28", "text": "Chapitre 28 — [texte à venir]", "image": "res://assets/story/ch28.png"},
	{"n": 29, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 39},   "text_when": "before", "title": "Chapitre 29", "text": "Chapitre 29 — [texte à venir]", "image": "res://assets/story/ch29.png"},
	{"n": 30, "type": "story",                                                                                            "title": "Chapitre 30", "text": "Chapitre 30 — [texte à venir]", "image": "res://assets/story/ch30.png"},
	{"n": 31, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 51},   "text_when": "before", "title": "Chapitre 31", "text": "Chapitre 31 — [texte à venir]", "image": "res://assets/story/ch31.png"},
	{"n": 32, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 42},   "text_when": "before", "title": "Chapitre 32", "text": "Chapitre 32 — [texte à venir]", "image": "res://assets/story/ch32.png"},
	{"n": 33, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 1060}, "text_when": "before", "title": "Chapitre 33", "text": "Chapitre 33 — [texte à venir]", "image": "res://assets/story/ch33.png"},
	{"n": 34, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 54},   "text_when": "before", "title": "Chapitre 34", "text": "Chapitre 34 — [texte à venir]", "image": "res://assets/story/ch34.png"},
	{"n": 35, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 45},   "text_when": "before", "title": "Chapitre 35", "text": "Chapitre 35 — [texte à venir]", "image": "res://assets/story/ch35.png"},
	{"n": 36, "type": "story",                                                                                            "title": "Chapitre 36", "text": "Chapitre 36 — [texte à venir]", "image": "res://assets/story/ch36.png"},
	{"n": 37, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 57},   "text_when": "before", "title": "Chapitre 37", "text": "Chapitre 37 — [texte à venir]", "image": "res://assets/story/ch37.png"},
	{"n": 38, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 48},   "text_when": "before", "title": "Chapitre 38", "text": "Chapitre 38 — [texte à venir]", "image": "res://assets/story/ch38.png"},
	{"n": 39, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 1180}, "text_when": "before", "title": "Chapitre 39", "text": "Chapitre 39 — [texte à venir]", "image": "res://assets/story/ch39.png"},
	{"n": 40, "type": "story",                                                                                            "title": "Chapitre 40", "text": "Chapitre 40 — [texte à venir]", "image": "res://assets/story/ch40.png"},
]

# === Récompense pièces par chapitre (créditée à la complétion, NON gatée) ===
const REWARD_STORY: int = 15            # chapitre narration (la lecture fait avancer)

func chapter_reward(n: int) -> int:
	var ch: Dictionary = get_chapter(n)
	if ch.is_empty():
		return 0
	if ch.get("type", "story") == "story":
		return REWARD_STORY
	return 40 + n * 5                   # jouable : croissant (récompense les chapitres tardifs)

# === État runtime (transient, non persisté) ===
var active: bool = false                # garde-fou global du contexte campagne (miroir Coop.active)
var active_chapter: int = 0             # chapitre en cours de jeu (0 = aucun)
var dodged: int = 0                     # esquives du run courant (objectif "dodge"), NON gaté

func chapter_count() -> int:
	return CHAPTERS.size()

func get_chapter(n: int) -> Dictionary:
	if n >= 1 and n <= CHAPTERS.size():
		return CHAPTERS[n - 1]
	return {}

func is_playable(n: int) -> bool:
	return get_chapter(n).get("type", "story") == "play"

# Objectif du chapitre actuellement EN COURS (vide si aucun / narration).
func objective() -> Dictionary:
	return get_chapter(active_chapter).get("objective", {})

func is_unlocked(n: int) -> bool:
	return n <= Settings.story_chapter

func is_completed(n: int) -> bool:
	return n < Settings.story_chapter

func is_current(n: int) -> bool:
	return n == Settings.story_chapter

# Remet à zéro le compteur d'esquive (appelé au début de chaque run, gratuit hors campagne).
func reset_run() -> void:
	dodged = 0

# Incrémenté au despawn d'un obstacle (point unique), seulement en campagne.
func notify_dodge() -> void:
	if active:
		dodged += 1

# Marque un chapitre RÉUSSI : crédite les pièces (NON gaté → monnaie réelle), débloque CLASSIQUE
# au ch.1, et avance la frontière de progression d'un cran. Renvoie le gain (pour l'écran de
# réussite). NB : les écrans / le routage seront câblés aux étapes suivantes.
func complete_chapter(n: int) -> int:
	var reward: int = chapter_reward(n)
	if reward > 0:
		Settings.coins_total += reward
		Settings.coins_lifetime += reward
		Settings.coin_collected.emit(Settings.coins_total)
	if n == 1:
		Settings.infinite_unlocked = true   # CLASSIQUE débloqué dès la fin du chapitre 1
	if n == Settings.story_chapter and n < CHAPTERS.size():
		Settings.story_chapter = n + 1      # avance linéaire (le chapitre courant uniquement)
	Settings.save_settings()
	return reward

# Coupe le contexte campagne (retour menu / fin de chapitre).
func clear() -> void:
	active = false
	active_chapter = 0
	dodged = 0
