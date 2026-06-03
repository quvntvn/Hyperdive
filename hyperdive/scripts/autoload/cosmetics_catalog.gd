extends Node
class_name CosmeticsCatalog

const SKINS: Array[Dictionary] = [
	{"id": "default",   "name": "Orange Brûlé",    "price": 0,  "color": Color(0.914, 0.310, 0.216)},
	{"id": "turquoise", "name": "Turquoise Rétro",  "price": 50,  "color": Color(0.235, 0.682, 0.639)},
	{"id": "mustard",   "name": "Jaune Moutarde",   "price": 150, "color": Color(0.949, 0.757, 0.306)},
	{"id": "cream",     "name": "Crème Pâle",       "price": 300, "color": Color(0.957, 0.914, 0.804)},
	{"id": "bordeaux",  "name": "Bordeaux Lourd",   "price": 450, "color": Color(0.486, 0.180, 0.165)},
	# Exclusifs défis (price -1 = non vendus au shop, débloqués par claim de défi).
	{"id": "chrome",    "name": "Chrome spatial",   "price": -1, "color": Color(0.580, 0.630, 0.720)},
	{"id": "or1962",    "name": "Or 1962",          "price": -1, "color": Color(0.945, 0.760, 0.255)},
	{"id": "briscard",  "name": "Vieux briscard",   "price": -1, "color": Color(0.780, 0.720, 0.580)},
	{"id": "funambule", "name": "Funambule",        "price": -1, "color": Color(0.520, 0.200, 0.180)},
]

func get_skin_by_id(id: String) -> Dictionary:
	for skin in SKINS:
		if skin["id"] == id:
			return skin
	return SKINS[0]

const TRAILS: Array[Dictionary] = [
	{"id": "none",     "name": "Aucun",       "color": Color(0.0,  0.0,  0.0,  0.0), "price": 0},
	{"id": "sang",     "name": "Sang",        "color": Color(0.70, 0.05, 0.05), "price": 40},
	{"id": "royal",    "name": "Sang royal",   "color": Color(0.15, 0.20, 0.70), "price": 80},
	{"id": "bile",     "name": "Bile",         "color": Color(0.45, 0.62, 0.10), "price": 110},
	{"id": "ichor",    "name": "Sang d'or",    "color": Color(0.95, 0.75, 0.12), "price": 250},
	{"id": "encre",    "name": "Encre",        "color": Color(0.22, 0.10, 0.32), "price": 140},
	{"id": "antigel",  "name": "Antigel",      "color": Color(0.20, 0.85, 0.75), "price": 200},
	{"id": "lait",     "name": "Lait",         "color": Color(0.96, 0.95, 0.90), "price": 160},
	{"id": "petrole",  "name": "Pétrole",      "color": Color(0.10, 0.10, 0.13), "price": 280},
	# Exclusifs défis (price -1 = non vendus au shop, débloqués par claim de défi).
	{"id": "comete",   "name": "Comète",       "color": Color(0.98, 0.90, 0.55), "price": -1},
	# Confettis : champ "ramp" = dégradé arc-en-ciel le long de la durée de vie (≠ couleur unique).
	# "color" sert juste à la pastille d'aperçu du shop.
	{"id": "confettis","name": "Confettis",    "color": Color(0.95, 0.35, 0.65), "price": -1,
		"ramp": [Color(0.95, 0.15, 0.15), Color(0.97, 0.55, 0.10), Color(0.97, 0.90, 0.20),
			Color(0.20, 0.80, 0.30), Color(0.15, 0.45, 0.95), Color(0.65, 0.25, 0.90)]},
	{"id": "froleur",  "name": "Frôleur",      "color": Color(0.20, 0.85, 0.80), "price": -1},
	# Fantôme : bleu pâle spectral + "alpha" bas → traînée vaporeuse translucide.
	{"id": "fantome",  "name": "Fantôme",      "color": Color(0.70, 0.85, 1.0), "price": -1, "alpha": 0.35},
]

func get_trail(id: String) -> Dictionary:
	for trail in TRAILS:
		if trail["id"] == id:
			return trail
	return TRAILS[0]

const THEMES: Array[Dictionary] = [
	{"id": "default",  "name": "1962",              "wall_color": Color(0.24,  0.15,  0.08),  "line_color": Color(0.949, 0.757, 0.306), "sky_top": Color(0.122, 0.188, 0.369), "sky_horizon": Color(0.957, 0.914, 0.804), "price": 0},
	{"id": "minuit",   "name": "Minuit",             "wall_color": Color(0.05,  0.08,  0.22),  "line_color": Color(0.235, 0.682, 0.639), "sky_top": Color(0.03,  0.04,  0.12),  "sky_horizon": Color(0.14,  0.18,  0.35),  "price": 60},
	{"id": "sunset",   "name": "Coucher de soleil",  "wall_color": Color(0.28,  0.09,  0.06),  "line_color": Color(0.949, 0.757, 0.306), "sky_top": Color(0.40,  0.16,  0.18),  "sky_horizon": Color(0.96,  0.65,  0.30),  "price": 200},
	{"id": "ocean",    "name": "Océan",              "wall_color": Color(0.05,  0.17,  0.19),  "line_color": Color(0.957, 0.914, 0.804), "sky_top": Color(0.06,  0.22,  0.32),  "sky_horizon": Color(0.40,  0.72,  0.75),  "price": 150},
	{"id": "mono",     "name": "Monochrome",         "wall_color": Color(0.20,  0.19,  0.18),  "line_color": Color(0.95,  0.93,  0.88),  "sky_top": Color(0.30,  0.29,  0.28),  "sky_horizon": Color(0.88,  0.86,  0.83),  "price": 350},
	{"id": "foret",    "name": "Forêt",              "wall_color": Color(0.06,  0.16,  0.08),  "line_color": Color(0.949, 0.757, 0.306), "sky_top": Color(0.04,  0.11,  0.05),  "sky_horizon": Color(0.52,  0.66,  0.38),  "price": 250},
]

func get_theme(id: String) -> Dictionary:
	for theme in THEMES:
		if theme["id"] == id:
			return theme
	return THEMES[0]
