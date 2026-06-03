extends StaticBody3D
class_name ObstacleBase

# Si true, le spawner place l'obstacle au CENTRE du couloir (x=0) et l'obstacle gère
# lui-même sa disposition latérale (barre, mur à trou, cube oscillant). Sinon le
# spawner lui donne une position X aléatoire (cube simple, etc.).
@export var spawn_centered: bool = false

# Hauteur verticale qu'occupe l'obstacle (>0 = obstacle "zone rare" : rouleau, spirale).
# Le spawner saute cette longueur (+ une marge) après l'avoir posé pour réserver un couloir
# vide autour de la zone. 0 = obstacle ponctuel normal (le spawner avance d'un intervalle).
@export var zone_length: float = 0.0

func _ready() -> void:
	add_to_group("obstacles")
