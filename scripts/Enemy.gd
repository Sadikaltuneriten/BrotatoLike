extends CharacterBody2D

@export var speed: float = 100.0
var target_players: Array[Node2D] = []

func _ready():
	_update_target_players()

func _update_target_players():
	target_players.clear()
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		target_players.append(player)

func _physics_process(_delta):
	if target_players.is_empty():
		return

	var closest_player = null
	var min_distance = INF
	
	for player in target_players:
		if not is_instance_valid(player):
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_player = player
	
	if closest_player:
		var direction = (closest_player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()