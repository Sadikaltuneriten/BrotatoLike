extends Node2D

const BULLET_SCENE = preload("res://scenes/weapons/Bullet.tscn")

var fire_timer := 0.0

func _process(delta: float) -> void:
	# 1. Schuss-Timer herunterzählen
	fire_timer -= delta
	if fire_timer <= 0.0:
		_shoot()
		fire_timer = 1.0 / float(GameState.stats.fire_rate)

	# 2. Nur noch zum nächsten Gegner drehen (keine Position-Verschiebung mehr)
	var target := _nearest_enemy()
	if target:
		var dir_to_enemy = (target.global_position - global_position).normalized()
		rotation = dir_to_enemy.angle()
	else:
		rotation = 0.0

func _shoot() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
		
	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	# Exakter Spawnpunkt vom Marker2D ("Muzzle"). 
	# Da der Marker mitrotiert, stimmt die Position für rechts UND links automatisch!
	var muzzle := get_node_or_null("Sprite2D/SpawnPoint") as Marker2D
	var spawn_pos = muzzle.global_position if muzzle else global_position
	bullet.global_position = spawn_pos
		
	# Schussrichtung exakt von der Mündung zum Gegner
	var shoot_dir = (target.global_position - spawn_pos).normalized()
	
	bullet.setup(
		shoot_dir,
		float(GameState.stats.bullet_speed),
		int(GameState.stats.damage)
	)

func _nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF
	for e in enemies:
		var d := global_position.distance_squared_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest
