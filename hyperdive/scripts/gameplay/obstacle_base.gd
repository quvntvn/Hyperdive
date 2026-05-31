extends StaticBody3D
class_name ObstacleBase

# Si true, le spawner place l'obstacle au CENTRE du couloir (x=0) et l'obstacle gère
# lui-même sa disposition latérale (barre, mur à trou, cube oscillant). Sinon le
# spawner lui donne une position X aléatoire (cube simple, etc.).
@export var spawn_centered: bool = false

func _ready() -> void:
	add_to_group("obstacles")
