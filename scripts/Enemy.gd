extends CharacterBody2D

@export var speed: float = 100.0
@export var damage: int = 10

func _physics_process(delta):
	# Beispielhafte Logik zur Bewegung Richtung Spieler oder Companion
	var target = _find_closest_target()
	if target:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)

func _find_closest_target():
	var player = get_tree().get_first_node_in_group("player")
	var companion = get_tree().get_first_node_in_group("companion")
	
	if not player: return companion
	if not companion: return player
	
	var dist_player = global_position.distance_to(player.global_position)
	var dist_companion = global_position.distance_to(companion.global_position)
	
	return player if dist_player < dist_companion else companion