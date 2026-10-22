extends Area2D

# ── Bomben-Properties ──────────────────────────────────────────────────────────
@export var fuse_time: float = 3.0           # Sekunden bis zur Explosion
@export var explosion_damage: int = 80       # Schaden beim Platzen
@export var explosion_radius: float = 120.0  # Flächenschaden-Radius (Pixel)

# ── Animationen (im Inspector zuweisen) ────────────────────────────────────────
# SpriteFrames für den Idle-Zustand (Bombe pulst, bevor sie explodiert)
@export var idle_frames: SpriteFrames = null
# SpriteFrames für die Explosion
@export var explosion_frames: SpriteFrames = null

# Intern
var _fused: bool = false
var _fuse_timer := 0.0
var _pulse_timer := 0.0
var _idle_sprite: AnimatedSprite2D = null
var _explosion_sprite: AnimatedSprite2D = null
var _explosion_sound: AudioStreamPlayer2D = null

func _ready() -> void:
	add_to_group("bombs")

	# Kollision nur mit Gegnern (Layer 1)
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	# ── Kinder-Nodes finden ───────────────────────────────────────────────────
	_idle_sprite = get_node_or_null("IdleSprite") as AnimatedSprite2D
	_explosion_sprite = get_node_or_null("ExplosionSprite") as AnimatedSprite2D
	_explosion_sound = get_node_or_null("Explosion_Sound") as AudioStreamPlayer2D

	# Idle-Sprite konfigurieren
	if _idle_sprite and idle_frames:
		_idle_sprite.sprite_frames = idle_frames
		if idle_frames.has_animation("idle"):
			_idle_sprite.animation = "idle"
			_idle_sprite.play("idle")
		elif idle_frames.has_animation("default"):
			_idle_sprite.animation = "default"
			_idle_sprite.play("default")

	# Explosion-Sprite konfigurieren (initial versteckt)
	if _explosion_sprite:
		_explosion_sprite.visible = false
		if explosion_frames:
			_explosion_sprite.sprite_frames = explosion_frames
			if explosion_frames.has_animation("explosion"):
				_explosion_sprite.animation = "explosion"
			elif explosion_frames.has_animation("default"):
				_explosion_sprite.animation = "default"

	# ── Countdown starten ────────────────────────────────────────────────────
	_fuse_timer = fuse_time

func _process(delta: float) -> void:
	if _fused:
		return
	_fuse_timer -= delta

	# Puls-Effekt für den Idle-Sprite
	_pulse_timer += delta
	if _idle_sprite:
		var pulse := sin(_pulse_timer * 6.0) * 0.10 + 1.0
		_idle_sprite.scale = Vector2.ONE * pulse

	if _fuse_timer <= 0.0:
		_explode()

# ── Kollision mit Gegner -> sofortige Explosion ────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		_explode()

# ── Explosion ──────────────────────────────────────────────────────────────────
func _explode() -> void:
	_fused = true
	# Kollisionen abschalten, damit nur einmal explodiert wird
	set_deferred("monitoring", false)

	# Idle-Sprite ausblenden
	if _idle_sprite:
		_idle_sprite.visible = false

	# Explosion-Sprite einblenden und abspielen
	if _explosion_sprite:
		_explosion_sprite.visible = true
		_explosion_sprite.play()
		if _explosion_sprite.sprite_frames:
			_explosion_sprite.animation_finished.connect(func():
				if is_instance_valid(self):
					queue_free()
			)
		# Fallback: spätestens nach 1.5s entfernen
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(self):
				queue_free()
		)
	else:
		# Kein Explosion-Sprite -> kurz warten und entfernen
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(self):
			queue_free()

	# Explosion-Sound abspielen
	if _explosion_sound and _explosion_sound.stream:
		_explosion_sound.play()

	# Flächenschaden: Alle Gegner im Radius treffen
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is CharacterBody2D:
			var dist := global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				enemy.take_damage(explosion_damage)
