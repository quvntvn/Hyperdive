extends Node
class_name MissionsCatalog
# Catalogue des défis permanents (autoload "Missions"). Données pures : la progression et
# le claim vivent dans settings_manager.gd (qui lit les stats persistées). L'UI est
# missions_screen.gd.
#
# Champs d'un défi :
#   id, name, desc, type, target, reward (pièces)
#   chain (optionnel)        : id de chaîne de paliers — l'UI n'affiche que le PROCHAIN
#                              palier non réclamé de chaque chaîne (paliers ascendants).
#   reward_skin / reward_trail (optionnel) : id d'un cosmétique exclusif débloqué au claim.
#
# Types reconnus (voir settings_manager.get_mission_progress) :
#   campaign_level, infinite_distance, jetpack_distance, coins_lifetime, total_games,
#   obstacles_dodged, obstacles_run, coins_run, no_wall_time, powerups_used, deaths,
#   ascetic, dual_distance, all_shop_skins, all_shop_trails, all_shop_themes,
#   owned_skins, owned_themes, trail_equipped.

const MISSIONS: Array[Dictionary] = [
	# === PALIERS — Distance CLASSIQUE (best_infinite_distance) ===
	{"id": "c_dist_500",   "chain": "c_dist", "name": "Première descente",   "desc": "Parcours 500 m en classique",   "type": "infinite_distance", "target": 500,   "reward": 40},
	{"id": "c_dist_1000",  "chain": "c_dist", "name": "Chute libre",          "desc": "Parcours 1 000 m en classique", "type": "infinite_distance", "target": 1000,  "reward": 75},
	{"id": "c_dist_2000",  "chain": "c_dist", "name": "Aérodynamique",        "desc": "Parcours 2 000 m en classique", "type": "infinite_distance", "target": 2000,  "reward": 120},
	{"id": "c_dist_3500",  "chain": "c_dist", "name": "Sans filet",           "desc": "Parcours 3 500 m en classique", "type": "infinite_distance", "target": 3500,  "reward": 180},
	{"id": "c_dist_5000",  "chain": "c_dist", "name": "Vitesse terminale",    "desc": "Parcours 5 000 m en classique", "type": "infinite_distance", "target": 5000,  "reward": 260},
	{"id": "c_dist_7500",  "chain": "c_dist", "name": "Stratosphère",         "desc": "Parcours 7 500 m en classique", "type": "infinite_distance", "target": 7500,  "reward": 350},
	{"id": "c_dist_10000", "chain": "c_dist", "name": "Au bout du vide",      "desc": "Parcours 10 000 m en classique","type": "infinite_distance", "target": 10000, "reward": 500, "reward_trail": "comete"},

	# === PALIERS — Altitude JETPACK (best_jetpack_distance) ===
	{"id": "j_dist_500",   "chain": "j_dist", "name": "Décollage",            "desc": "Monte à 500 m en jetpack",      "type": "jetpack_distance", "target": 500,   "reward": 50},
	{"id": "j_dist_1000",  "chain": "j_dist", "name": "Ascension",            "desc": "Monte à 1 000 m en jetpack",    "type": "jetpack_distance", "target": 1000,  "reward": 90},
	{"id": "j_dist_2000",  "chain": "j_dist", "name": "Haute altitude",       "desc": "Monte à 2 000 m en jetpack",    "type": "jetpack_distance", "target": 2000,  "reward": 140},
	{"id": "j_dist_3500",  "chain": "j_dist", "name": "Ligne de Kármán",      "desc": "Monte à 3 500 m en jetpack",    "type": "jetpack_distance", "target": 3500,  "reward": 200},
	{"id": "j_dist_5000",  "chain": "j_dist", "name": "En orbite",            "desc": "Monte à 5 000 m en jetpack",    "type": "jetpack_distance", "target": 5000,  "reward": 300},
	{"id": "j_dist_7500",  "chain": "j_dist", "name": "Vers l'infini",        "desc": "Monte à 7 500 m en jetpack",    "type": "jetpack_distance", "target": 7500,  "reward": 400, "reward_skin": "chrome"},

	# === PALIERS — Campagne (campaign_level) ===
	{"id": "camp_3",  "chain": "camp", "name": "Apprenti plongeur",  "desc": "Atteins le niveau 3",  "type": "campaign_level", "target": 3,  "reward": 50},
	{"id": "camp_5",  "chain": "camp", "name": "Vétéran",             "desc": "Atteins le niveau 5",  "type": "campaign_level", "target": 5,  "reward": 100},
	{"id": "camp_10", "chain": "camp", "name": "Confirmé",            "desc": "Atteins le niveau 10", "type": "campaign_level", "target": 10, "reward": 180},
	{"id": "camp_15", "chain": "camp", "name": "Expert",              "desc": "Atteins le niveau 15", "type": "campaign_level", "target": 15, "reward": 280},
	{"id": "camp_20", "chain": "camp", "name": "Maître",              "desc": "Atteins le niveau 20", "type": "campaign_level", "target": 20, "reward": 400},
	{"id": "camp_25", "chain": "camp", "name": "Légende de 1962",     "desc": "Atteins le niveau 25", "type": "campaign_level", "target": 25, "reward": 600, "reward_skin": "or1962"},

	# === PALIERS — Pièces cumulées (coins_lifetime) ===
	{"id": "coins_500",   "chain": "coins", "name": "Économe",            "desc": "Ramasse 500 pièces au total",    "type": "coins_lifetime", "target": 500,   "reward": 30},
	{"id": "coins_2000",  "chain": "coins", "name": "Pécule",             "desc": "Ramasse 2 000 pièces au total",  "type": "coins_lifetime", "target": 2000,  "reward": 80},
	{"id": "coins_5000",  "chain": "coins", "name": "Magot",              "desc": "Ramasse 5 000 pièces au total",  "type": "coins_lifetime", "target": 5000,  "reward": 150},
	{"id": "coins_10000", "chain": "coins", "name": "Petite fortune",     "desc": "Ramasse 10 000 pièces au total", "type": "coins_lifetime", "target": 10000, "reward": 280},
	{"id": "coins_25000", "chain": "coins", "name": "Coffre-fort",        "desc": "Ramasse 25 000 pièces au total", "type": "coins_lifetime", "target": 25000, "reward": 500},
	{"id": "coins_50000", "chain": "coins", "name": "Dragon sur son or",  "desc": "Ramasse 50 000 pièces au total", "type": "coins_lifetime", "target": 50000, "reward": 800, "reward_trail": "confettis"},

	# === PALIERS — Parties jouées (total_games) ===
	{"id": "games_10",  "chain": "games", "name": "Première chute",   "desc": "Joue 10 parties",  "type": "total_games", "target": 10,  "reward": 25},
	{"id": "games_50",  "chain": "games", "name": "Habitué",          "desc": "Joue 50 parties",  "type": "total_games", "target": 50,  "reward": 70},
	{"id": "games_100", "chain": "games", "name": "Accro",            "desc": "Joue 100 parties", "type": "total_games", "target": 100, "reward": 130},
	{"id": "games_250", "chain": "games", "name": "Vétéran du vide",  "desc": "Joue 250 parties", "type": "total_games", "target": 250, "reward": 250},
	{"id": "games_500", "chain": "games", "name": "Increvable",       "desc": "Joue 500 parties", "type": "total_games", "target": 500, "reward": 450, "reward_skin": "briscard"},

	# === EXPLOITS SPÉCIAUX (tous visibles) ===
	{"id": "dodge_50",     "name": "Slalomeur",                "desc": "Esquive 50 obstacles au total",      "type": "obstacles_dodged", "target": 50,   "reward": 40},
	{"id": "dodge_500",    "name": "Anguille",                 "desc": "Esquive 500 obstacles au total",     "type": "obstacles_dodged", "target": 500,  "reward": 120},
	{"id": "dodge_2000",   "name": "Frôleur professionnel",    "desc": "Esquive 2 000 obstacles au total",   "type": "obstacles_dodged", "target": 2000, "reward": 300, "reward_trail": "froleur"},
	{"id": "dodge_run_30", "name": "Tête froide",              "desc": "Esquive 30 obstacles en une partie", "type": "obstacles_run",    "target": 30,   "reward": 80},
	{"id": "coins_run_30", "name": "Pillard",                  "desc": "Ramasse 30 pièces en une partie",    "type": "coins_run",        "target": 30,   "reward": 60},
	{"id": "coins_run_60", "name": "Cleptomane",               "desc": "Ramasse 60 pièces en une partie",    "type": "coins_run",        "target": 60,   "reward": 120},
	{"id": "nowall_30",    "name": "Équilibriste",             "desc": "Survis 30 s sans toucher un mur",    "type": "no_wall_time",     "target": 30,   "reward": 70},
	{"id": "nowall_60",    "name": "Funambule",                "desc": "Survis 60 s sans toucher un mur",    "type": "no_wall_time",     "target": 60,   "reward": 150, "reward_skin": "funambule"},
	{"id": "powerups_all", "name": "Bricoleur",                "desc": "Utilise les 4 types de power-up",    "type": "powerups_used",    "target": 4,    "reward": 100},
	{"id": "deaths_10",    "name": "Première chair à ragdoll", "desc": "Meurs 10 fois",                       "type": "deaths",           "target": 10,   "reward": 25},
	{"id": "deaths_100",   "name": "Collectionneur de ragdolls","desc": "Meurs 100 fois",                     "type": "deaths",           "target": 100,  "reward": 100, "reward_trail": "fantome"},
	{"id": "deaths_500",   "name": "Roi du crash",             "desc": "Meurs 500 fois",                      "type": "deaths",           "target": 500,  "reward": 250},
	{"id": "ascetic",      "name": "Ascète",                   "desc": "Atteins 1 500 m en classique sans ramasser une pièce", "type": "ascetic", "target": 1, "reward": 90},
	{"id": "coins_run_75", "name": "Glouton",                  "desc": "Ramasse 75 pièces en une partie",    "type": "coins_run",        "target": 75,   "reward": 160},
	{"id": "dual_1000",    "name": "Polyvalent",               "desc": "Atteins 1 000 m en classique ET en jetpack", "type": "dual_distance", "target": 1000, "reward": 150},
	{"id": "all_skins",    "name": "Garde-robe complète",      "desc": "Possède tous les skins du shop",     "type": "all_shop_skins",   "target": 5,    "reward": 80},
	{"id": "all_trails",   "name": "Palette de sang",          "desc": "Possède tous les trails du shop",    "type": "all_shop_trails",  "target": 9,    "reward": 80},
	{"id": "all_themes",   "name": "Décorateur",               "desc": "Possède tous les thèmes du shop",    "type": "all_shop_themes",  "target": 6,    "reward": 80},
]
