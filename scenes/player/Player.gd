extends CharacterBody2D

signal died

const WEAPON_SCENE = preload("res://scenes/weapons/Weapon.tscn")

var health: int
var flash_timer := 0.0

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

	# --- NEU: Animationen & Spiegeln steuern ---
	var anim_sprite := get_node_or_null("AnimatedSprite2D") # Passe den Namen an, falls dein AnimatedSprite2D anders heißt
	if anim_sprite:
		if dir != Vector2.ZERO:
			anim_sprite.play("running")
			# Horizontal spiegeln, wenn wir nach links laufen
			if dir.x < 0:
				anim_sprite.flip_h = true
			elif dir.x > 0:
				anim_sprite.flip_h = false
			# Hinweis: Wenn dir.x == 0 (z.B. nur hoch/runter), behält er die letzte Richtung bei
		else:
			anim_sprite.play("idle")
	# ---------------------------------------------

	if flash_timer > 0.0:
		flash_timer -= delta
		# Kein queue_redraw() mehr nötig, da wir kein _draw() für den Kreis mehr nutzen

# _draw() ist jetzt leer, damit der alte Platzhalter-Kreis verschwindet
func _draw() -> void:
	pass

func take_damage(amount: int) -> void:
	var actual: int = max(1, amount - int(GameState.stats.armor))
	health -= actual
	GameState.emit_signal("health_changed", health, int(GameState.stats.max_health))
	flash_timer = 0.15
	# queue_redraw() entfernt, da das Aufleuchten jetzt über das Sprite / Shader laufen müsste (oder vorerst weggelassen wird)
	if health <= 0:
		die()

func die() -> void:
	emit_signal("died")
