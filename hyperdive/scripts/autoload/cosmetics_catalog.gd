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
