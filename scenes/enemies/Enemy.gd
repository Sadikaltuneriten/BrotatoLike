extends CharacterBody2D

const HIT_EFFECT_SCENE = preload("res://scenes/vfx/HitEffect.tscn")

# --- NEU: Verschiedene SpriteFrames für die Gegnertypen hier vorladen ---
# (Pfade anpassen, je nachdem wo du deine .tres SpriteFrames abgespeichert hast)
const FRAMES_STANDARD = preload("res://resources/sprites_standard.tres")
const FRAMES_SPEEDER = preload("res://resources/sprites_speeder.tres")
const FRAMES_TANK = preload("res://resources/sprites_tank.tres")

@export var speed := 80.0
@export var health := 30
@export var damage := 10
@export var xp_value := 5
@export var gold_value := 2

var body_radius := 14.0
var player: Node2D = null
var contact_timer := 0.0
const CONTACT_RATE := 0.5
var is_dying := false

const EnemyScaling = preload("res://scripts/logic/EnemyScaling.gd")

func setup_type(type: String, wave: int) -> void:
	var base := {"speed": speed, "health": health, "damage": damage, "xp_value": xp_value, "gold_value": gold_value}
	var s := EnemyScaling.stats_for(type, wave, base)
	speed = s.speed
	health = s.health
	damage = s.damage
	xp_value = s.xp_value
	gold_value = s.gold_value
	
	var sprite_node := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	match type:
		"speeder":
			body_radius = 10.0
			if sprite_node:
				sprite_node.scale = Vector2(0.25, 0.25)
				if FRAMES_SPEEDER:
					sprite_node.sprite_frames = FRAMES_SPEEDER # Anderes Spriteset zuweisen!
		"tank":
			body_radius = 20.0
			if sprite_node:
				sprite_node.scale = Vector2(0.4, 0.4)
				if FRAMES_TANK:
					sprite_node.sprite_frames = FRAMES_TANK # Anderes Spriteset zuweisen!
		_:
			if sprite_node:
				sprite_node.scale = Vector2(0.35, 0.35)
				if FRAMES_STANDARD:
					sprite_node.sprite_frames = FRAMES_STANDARD # Standard-Spriteset

	# Animation direkt nach dem Zuweisen starten
	if sprite_node and sprite_node.sprite_frames.has_animation("walk"):
		sprite_node.play("walk")

	var shape_node := get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is CircleShape2D:
		shape_node.shape = shape_node.shape.duplicate()
		(shape_node.shape as CircleShape2D).radius = body_radius

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

func _physics_process(delta: float) -> void:
	if is_dying or player == null:
		return
		
	velocity = (player.global_position - global_position).normalized() * speed
	move_and_slide()

	var sprite := get_node_or_null("AnimatedSprite2D")
	if sprite:
		if velocity.x < 0:
			sprite.flip_h = true
		elif velocity.x > 0:
			sprite.flip_h = false

	contact_timer -= delta
	if contact_timer <= 0.0:
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			if col and col.get_collider() and col.get_collider().is_in_group("player"):
				col.get_collider().take_damage(damage)
				contact_timer = CONTACT_RATE
				break

func _draw() -> void:
	pass

func take_damage(amount: int) -> void:
	if is_dying:
		return
		
	health -= amount
	
	var hit_effect := HIT_EFFECT_SCENE.instantiate()
	hit_effect.global_position = global_position
	var main_scene := get_tree().get_root().get_node_or_null("Main")
	if main_scene:
		main_scene.add_child(hit_effect)
	else:
		get_parent().add_child(hit_effect)
	
	if health <= 0:
		die()

func die() -> void:
	if is_dying:
		return
	is_dying = true
	
	GameState.add_xp(xp_value)
	GameState.add_gold(gold_value)
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector2.ZERO
	
	# Korrigierter Zugriff auf den AnimatedSprite2D und den Sound
	var sprite := get_node_or_null("death") as AnimatedSprite2D
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	
	var death_sound := get_node_or_null("deathsound") as AudioStreamPlayer2D
	if death_sound and death_sound.stream:
		death_sound.play()
	
	if sprite and sprite.sprite_frames.has_animation("death"):
		await sprite.animation_finished
		if sprite:
			sprite.hide()
	elif death_sound and death_sound.stream:
		await death_sound.finished
	else:
		await get_tree().create_timer(0.3).timeout
		
	queue_free()
