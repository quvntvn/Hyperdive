extends Node
class_name CosmeticsCatalog

const SKINS: Array[Dictionary] = [
	{"id": "default",   "name": "Orange Brûlé",    "price": 0,  "color": Color(0.914, 0.310, 0.216)},
	{"id": "turquoise", "name": "Turquoise Rétro",  "price": 20, "color": Color(0.235, 0.682, 0.639)},
	{"id": "mustard",   "name": "Jaune Moutarde",   "price": 35, "color": Color(0.949, 0.757, 0.306)},
	{"id": "cream",     "name": "Crème Pâle",       "price": 50, "color": Color(0.957, 0.914, 0.804)},
	{"id": "bordeaux",  "name": "Bordeaux Lourd",   "price": 75, "color": Color(0.486, 0.180, 0.165)},
]

func get_skin_by_id(id: String) -> Dictionary:
	for skin in SKINS:
		if skin["id"] == id:
			return skin
	return SKINS[0]

const TRAILS: Array[Dictionary] = [
	{"id": "none",     "name": "Aucun",       "color": Color(0.0,  0.0,  0.0,  0.0), "price": 0},
	{"id": "sang",     "name": "Sang",        "color": Color(0.70, 0.05, 0.05), "price": 15},
	{"id": "royal",    "name": "Sang royal",   "color": Color(0.15, 0.20, 0.70), "price": 15},
	{"id": "bile",     "name": "Bile",         "color": Color(0.45, 0.62, 0.10), "price": 20},
	{"id": "ichor",    "name": "Sang d'or",    "color": Color(0.95, 0.75, 0.12), "price": 25},
	{"id": "encre",    "name": "Encre",        "color": Color(0.22, 0.10, 0.32), "price": 30},
	{"id": "antigel",  "name": "Antigel",      "color": Color(0.20, 0.85, 0.75), "price": 35},
	{"id": "lait",     "name": "Lait",         "color": Color(0.96, 0.95, 0.90), "price": 40},
	{"id": "petrole",  "name": "Pétrole",      "color": Color(0.10, 0.10, 0.13), "price": 45},
]

func get_trail(id: String) -> Dictionary:
	for trail in TRAILS:
		if trail["id"] == id:
			return trail
	return TRAILS[0]

const THEMES: Array[Dictionary] = [
	{"id": "default",  "name": "1962",              "wall_color": Color(0.24,  0.15,  0.08),  "line_color": Color(0.949, 0.757, 0.306), "sky_top": Color(0.122, 0.188, 0.369), "sky_horizon": Color(0.957, 0.914, 0.804), "price": 0},
	{"id": "minuit",   "name": "Minuit",             "wall_color": Color(0.05,  0.08,  0.22),  "line_color": Color(0.235, 0.682, 0.639), "sky_top": Color(0.03,  0.04,  0.12),  "sky_horizon": Color(0.14,  0.18,  0.35),  "price": 30},
	{"id": "sunset",   "name": "Coucher de soleil",  "wall_color": Color(0.28,  0.09,  0.06),  "line_color": Color(0.949, 0.757, 0.306), "sky_top": Color(0.40,  0.16,  0.18),  "sky_horizon": Color(0.96,  0.65,  0.30),  "price": 40},
	{"id": "ocean",    "name": "Océan",              "wall_color": Color(0.05,  0.17,  0.19),  "line_color": Color(0.957, 0.914, 0.804), "sky_top": Color(0.06,  0.22,  0.32),  "sky_horizon": Color(0.40,  0.72,  0.75),  "price": 35},
	{"id": "mono",     "name": "Monochrome",         "wall_color": Color(0.20,  0.19,  0.18),  "line_color": Color(0.95,  0.93,  0.88),  "sky_top": Color(0.30,  0.29,  0.28),  "sky_horizon": Color(0.88,  0.86,  0.83),  "price": 50},
	{"id": "foret",    "name": "Forêt",              "wall_color": Color(0.06,  0.16,  0.08),  "line_color": Color(0.949, 0.757, 0.306), "sky_top": Color(0.04,  0.11,  0.05),  "sky_horizon": Color(0.52,  0.66,  0.38),  "price": 45},
]

func get_theme(id: String) -> Dictionary:
	for theme in THEMES:
		if theme["id"] == id:
			return theme
	return THEMES[0]

const MISSIONS: Array[Dictionary] = [
	{"id": "apprenti",   "name": "Apprenti plongeur",  "desc": "Atteins le niveau 3",         "type": "campaign_level", "target": 3,   "reward": 50},
	{"id": "veteran",    "name": "Vétéran",             "desc": "Atteins le niveau 5",         "type": "campaign_level", "target": 5,   "reward": 100},
	{"id": "descente",   "name": "Première descente",   "desc": "Parcours 300 m en infini",    "type": "distance",       "target": 300, "reward": 40},
	{"id": "chutelibre", "name": "Chute libre",         "desc": "Parcours 600 m en infini",    "type": "distance",       "target": 600, "reward": 80},
	{"id": "collec",     "name": "Collectionneur",      "desc": "Possède 3 skins",             "type": "owned_skins",    "target": 3,   "reward": 30},
	{"id": "styliste",   "name": "Styliste",            "desc": "Possède 2 thèmes",            "type": "owned_themes",   "target": 2,   "reward": 40},
	{"id": "trailcolor", "name": "Sillage coloré",      "desc": "Équipe un trail coloré",      "type": "trail_equipped", "target": 1,   "reward": 20},
]
