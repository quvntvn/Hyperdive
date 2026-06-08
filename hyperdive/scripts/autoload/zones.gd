extends Node
# Autoload "Zones" : coordinateur partagé des ZONES SPÉCIALES (visuelles + obstacles).
#
# Deux rôles :
#  1) BUS d'ambiance visuelle : CorridorWalls (le pilote) écrit ici l'ambiance courante
#     (nom + blend + multiplicateur de vitesse) ; player/spawner/coin_spawner la LISENT
#     pour appliquer leur twist gameplay assorti.
#  2) EXCLUSION mutuelle : une zone visuelle et une zone d'obstacles ne doivent jamais se
#     chevaucher. Chaque producteur réserve une BANDE de depth ; l'autre vérifie l'intersection
#     avant de se déclencher.
#
# "depth" = coordonnée dir-relative monotone croissante (= Settings.get_fall_dir() * y),
# positive et croissante en chute ET en jetpack. Tous les producteurs partagent ce repère.

# --- État zone visuelle courante (écrit par CorridorWalls, lu par les consommateurs) ---
var visual_name: String = ""         # "" / "neon" / "clouds" / "cosmic"
var visual_blend: float = 0.0        # 0 hors zone → 1 plein ; lerp doux entrée/sortie
var visual_speed_mult: float = 1.0   # multiplicateur de vitesse du twist, DÉJÀ blendé
# Bande de depth occupée par la zone visuelle courante (pour les twists spawn-ahead :
# nuages = moins d'obstacles, cosmique = bonus pièces, posés DANS cette bande).
var visual_band_start: float = 0.0
var visual_band_end: float = 0.0

# --- Bandes réservées (depth) pour l'exclusion mutuelle ---
# Chaque bande = Vector2(start_depth, end_depth). Élaguées quand passées (end < player_depth).
var _obstacle_bands: Array[Vector2] = []
var _visual_bands: Array[Vector2] = []

# Remis à zéro au début de chaque partie (autoload persistant entre scènes).
func reset() -> void:
	visual_name = ""
	visual_blend = 0.0
	visual_speed_mult = 1.0
	visual_band_start = 0.0
	visual_band_end = 0.0
	_obstacle_bands.clear()
	_visual_bands.clear()

func register_obstacle_band(start_d: float, end_d: float) -> void:
	_obstacle_bands.append(Vector2(start_d, end_d))

func register_visual_band(start_d: float, end_d: float) -> void:
	_visual_bands.append(Vector2(start_d, end_d))
	visual_band_start = start_d
	visual_band_end = end_d

# true si [a,b] (+ marge) chevauche une bande d'obstacles → gate une zone visuelle.
func obstacle_band_intersects(a: float, b: float, margin: float = 0.0) -> bool:
	return _intersects(_obstacle_bands, a, b, margin)

# true si [a,b] (+ marge) chevauche une bande visuelle → gate une zone d'obstacles.
func visual_band_intersects(a: float, b: float, margin: float = 0.0) -> bool:
	return _intersects(_visual_bands, a, b, margin)

func _intersects(bands: Array[Vector2], a: float, b: float, margin: float) -> bool:
	for band in bands:
		if a <= band.y + margin and b >= band.x - margin:
			return true
	return false

# true si le depth donné tombe dans la bande visuelle courante ET que l'ambiance == name.
# Utilisé par spawner/coin_spawner pour n'appliquer leur twist QUE dans la zone visible.
func in_visual_band(depth: float, name: String) -> bool:
	return visual_name == name and depth >= visual_band_start and depth <= visual_band_end

# Élagage : retire les bandes entièrement passées derrière le joueur (depth croissant).
func prune(player_depth: float) -> void:
	_obstacle_bands = _obstacle_bands.filter(func(b: Vector2) -> bool: return b.y >= player_depth)
	_visual_bands = _visual_bands.filter(func(b: Vector2) -> bool: return b.y >= player_depth)
