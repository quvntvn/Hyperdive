extends Node
class_name MissionsCatalog
# Catalogue des défis permanents (autoload "Missions"). Données pures : la progression et
# le claim vivent dans settings_manager.gd (qui lit les stats persistées). L'UID écran est
# missions_screen.gd. Un défi = {id, name, desc, type, target, reward, [reward_skin/trail], [chain]}.

const MISSIONS: Array[Dictionary] = [
	{"id": "apprenti",   "name": "Apprenti plongeur",  "desc": "Atteins le niveau 3",         "type": "campaign_level", "target": 3,   "reward": 50},
	{"id": "veteran",    "name": "Vétéran",             "desc": "Atteins le niveau 5",         "type": "campaign_level", "target": 5,   "reward": 100},
	{"id": "descente",   "name": "Première descente",   "desc": "Parcours 300 m en infini",    "type": "distance",       "target": 300, "reward": 40},
	{"id": "chutelibre", "name": "Chute libre",         "desc": "Parcours 600 m en infini",    "type": "distance",       "target": 600, "reward": 80},
	{"id": "collec",     "name": "Collectionneur",      "desc": "Possède 3 skins",             "type": "owned_skins",    "target": 3,   "reward": 30},
	{"id": "styliste",   "name": "Styliste",            "desc": "Possède 2 thèmes",            "type": "owned_themes",   "target": 2,   "reward": 40},
	{"id": "trailcolor", "name": "Sillage coloré",      "desc": "Équipe un trail coloré",      "type": "trail_equipped", "target": 1,   "reward": 20},
]
