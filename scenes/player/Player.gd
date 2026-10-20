extends CharacterBody2D

signal died

const WEAPON_SCENE = preload("res://scenes/weapons/Weapon.tscn")

var health: int
var flash_timer := 0.0
var is_attacking := false

func _ready() -> void:
	add_to_group("player")
	health = int(GameState.stats.max_health)
	var weapon := WEAPON_SCENE.instantiate()
	add_child(weapon)

func _physics_process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	velocity = dir.normalized() * float(GameState.stats.speed) if dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	var vp := get_viewport_rect().size
	global_position = global_position.clamp(Vector2(18, 18), vp - Vector2(18, 18))

	# --- Animationen & Spiegeln steuern ---
	var anim_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite:
		# 1. Die Blickrichtung (flip_h) soll IMMER sofort aktualisiert werden, 
		# egal ob er angreift oder läuft!
		if dir.x < 0:
			anim_sprite.flip_h = true
		elif dir.x > 0:
			anim_sprite.flip_h = false

		# 2. Nur die Animation selbst (running/idle/attack) wird geschützt
		if not is_attacking:
			if dir != Vector2.ZERO:
				anim_sprite.play("running")
			else:
				anim_sprite.play("idle")
	# ---------------------------------------------

	if flash_timer > 0.0:
		flash_timer -= delta

func trigger_attack() -> void:
	var anim_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		# Wenn er bereits angreift, ignorieren wir den neuen Trigger, 
		# damit sich die Animation nicht endlos überlappt
		if is_attacking:
			return 
			
		is_attacking = true
		#anim_sprite.play("attack")
		
		await anim_sprite.animation_finished
		is_attacking = false

func _draw() -> void:
	pass

func take_damage(amount: int) -> void:
	var actual: int = max(1, amount - int(GameState.stats.armor))
	health -= actual
	GameState.emit_signal("health_changed", health, int(GameState.stats.max_health))
	flash_timer = 0.15
	if health <= 0:
		die()

func die() -> void:
	emit_signal("died")
