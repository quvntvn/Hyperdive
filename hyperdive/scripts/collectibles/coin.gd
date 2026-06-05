extends Area3D
class_name Coin

const ROTATION_SPEED: float = 3.0

func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotation.y += ROTATION_SPEED * delta

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		Settings.add_coin()
		Audio.play_coin()   # son conservé ; la pièce disparaît, sans burst de particules
		queue_free()
