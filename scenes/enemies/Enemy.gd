extends CharacterBody2D

const HIT_EFFECT_SCENE = preload("res://scenes/vfx/HitEffect.tscn")

# --- NEU: Verschiedene SpriteFrames für die Gegnertypen hier vorladen ---
# (Pfade anpassen, je nachdem wo du deine .tres SpriteFrames abgespeichert hast)
const FRAMES_STANDARD = preload("res://resources/sprites_standard.tres")
const FRAMES_SPEEDER = preload("res://resources/sprites_speeder.tres")
const FRAMES_TANK = preload("res://resources/sprites_tank.tres")

@export var speed := 400.0
@export var health := 30
@export var damage := 10
@export var xp_value := 5
@export var gold_value := 2

var body_radius := 14.0
var player: Node2D = null
var _target_players: Array = []    # Im 2P-Modus: Player + Companion
var contact_timer := 0.0
const CONTACT_RATE := 0.5
var is_dying := false
var _event_animation_active := false   # verhindert überlappende Event-Coroutinen
var _freeze_timer := 0.0              # Restzeit des Einfrierens (Bewegung stoppt)



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
	if sprite_node and sprite_node.sprite_frames.has_animation("walk_right"):
		sprite_node.play("walk_right")


	var shape_node := get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is CircleShape2D:
		shape_node.shape = shape_node.shape.duplicate()
		(shape_node.shape as CircleShape2D).radius = body_radius

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	# Companion-Referenz (nur relevant im 2-Spieler-Modus)
	var companions := get_tree().get_nodes_in_group("companion")
	if not companions.is_empty():
		_target_players = [player] + companions
	else:
		_target_players = [player]

	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames.has_animation("walk_right"):
		sprite.play("walk_right")

func _physics_process(delta: float) -> void:
	if is_dying or player == null:
		return

	# ── Freeze-Status (Eis-Effekt) ──────────────────────────────────────────────
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		velocity = Vector2.ZERO
	else:
		# Im 2-Spieler-Modus verfolgt der Gegner den NÄCHSTGELEGENEN
		# (aus Player + Companion); im Solo-Modus den Player.
		var target_pos := _get_nearest_target_pos()
		velocity = (target_pos - global_position).normalized() * speed
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
			# Treffer auf Player UND Companion (beide nehmen Schaden)
			if col and col.get_collider() and (col.get_collider().is_in_group("player") or col.get_collider().is_in_group("companion")):
				col.get_collider().take_damage(damage, global_position)
				contact_timer = CONTACT_RATE
				# Angriff-Animation abspielen, danach automatisch zurück auf walk
				_play_event_animation("attack_right")
				break

func _draw() -> void:
	pass


# Ermittelt die Position des NÄCHSTGELEGENEN Ziels (Player + Companion im 2P).
# Fällt auf den Haupt-Player zurück, falls nichts gefunden wird.
func _get_nearest_target_pos() -> Vector2:
	var nearest: Node2D = null
	var nearest_dist := INF
	for target in _target_players:
		if not is_instance_valid(target):
			continue
		var t: Node2D = target as Node2D
		if t == null:
			continue
		var d := global_position.distance_squared_to(t.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = t
	if nearest != null:
		return nearest.global_position
	# Fallback
	return global_position

# Spielt eine einmalige Event-Animation (z. B. "attack_right") ab und wechselt
# danach automatisch wieder auf "walk_right".
# - Guard-Flag verhindert, dass mehrere Hits parallel stapeln
# - Dauer wird aus Framezahl/Speed berechnet, damit es auch bei
#   loop = 1 korrekt zurück auf walk_right wechselt
func _play_event_animation(anim_name: String) -> void:
	if is_dying:
		return
	# Nur eine Event-Animation gleichzeitig abspielen
	if _event_animation_active:
		return

	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not sprite or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return

	_event_animation_active = true
	# flip_h NUR nicht anfassen! Die *_right-Varianten zeigen nach rechts und
	# werden von _physics_process über flip_h an die Bewegungsrichtung angepasst.
	sprite.play(anim_name)

	# Dauer der Animation in Sekunden ermitteln
	var frame_count := sprite.sprite_frames.get_frame_count(anim_name)
	var anim_speed := sprite.sprite_frames.get_animation_speed(anim_name)
	var frame_duration := 1.0
	if frame_count > 0:
		frame_duration = sprite.sprite_frames.get_frame_duration(anim_name, 0)


	var duration := float(frame_count) * frame_duration / maxf(anim_speed, 0.001)

	# Auf das Ende warten (Timer statt animation_finished, damit loop=1 auch klappt)
	await get_tree().create_timer(duration).timeout

	# Enemy könnte zwischenzeitlich gestorben sein
	if is_dying or not is_inside_tree():
		_event_animation_active = false
		return
	_event_animation_active = false

	# Zurück auf den normalen Laufzyklus (flip_h bleibt wie von _physics_process gesetzt)
	if sprite.sprite_frames.has_animation("walk_right"):
		sprite.play("walk_right")


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, ice: int = 0, freeze: float = 0.0) -> int:
	if is_dying:
		return 0

	# ── Eisschaden zusätzlich anrechnen ─────────────────────────────────────────
	var total := amount + ice
	health -= total

	# ── Freeze anwenden (Bewegung wird gestoppt, siehe _physics_process) ────────
	if freeze > 0.0:
		_freeze_timer = maxf(_freeze_timer, freeze)

	var hit_effect := HIT_EFFECT_SCENE.instantiate()
	hit_effect.global_position = global_position
	var main_scene := get_tree().get_root().get_node_or_null("Main")
	if main_scene:
		main_scene.add_child(hit_effect)
	else:
		get_parent().add_child(hit_effect)

	# Take-Damage-Animation abspielen, danach automatisch zurück auf walk
	_play_event_animation("take_damage_right")

	if health <= 0:
		die()

	# Zugesetzten Schaden zurückgeben (für Vampirismus / Lifesteal)
	return total


func die() -> void:
	if is_dying:
		return
	is_dying = true
	
	GameState.add_xp(xp_value)
	GameState.add_gold(gold_value)
	
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector2.ZERO
	
	# Korrigierter Zugriff auf den death-Node und den Sound
	var sprite := get_node_or_null("death") as AnimatedSprite2D
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.visible = true
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
