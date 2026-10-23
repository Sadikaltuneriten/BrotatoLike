extends Node2D

# ── Companion-Properties ───────────────────────────────────────────────────────
@export var follow_speed: float = 1.0       # Wie schnell die Figur folgt
@export var offset: Vector2 = Vector2(40.0, -80.0)  # Rechts oben vom Spieler
@export var anim_speed_scale: float = 1.0      # Geschwindigkeitsfaktor der Animation
@export var wander_radius: float = 300.0        # Wie weit sie herumschlendert
@export var wander_pause: float = 1.5          # Pause zwischen Wander-Zielen (Sekunden)
@export var move_speed: float = 300.0          # Bewegungsgeschwindigkeit im 2-Spieler-Modus

# Nahkampf-Properties ──────────────────────────────────────────────────────────
@export var melee_range: float = 200.0        # Reichweite des Hiebs
@export var melee_damage: int = 30            # Schaden pro Hieb
@export var melee_cooldown: float = 0.6       # Abklingzeit zwischen Angriffen
@export var melee_arc: float = 6.28           # Bogen in Radians (6.28 = voller Kreis)
@export var debug_draw: bool = false           # Reichweiten-Bogen einzeichnen

var _anim_sprite: AnimatedSprite2D = null
var _player: Node2D = null
var _current_dir := Vector2.ZERO

# Wander-State
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer := 1.0
var _is_wandering := false

# Melee-State
var is_attacking := false
var _attack_cooldown := 0.0
var _attack_direction := Vector2.ZERO

func _ready() -> void:
	add_to_group("companion")
	_anim_sprite = get_node_or_null("CompanionSprite") as AnimatedSprite2D
	# Nahkampf-Werte aus den Companion-Stats ableiten (erweiterbar)
	var cs: Dictionary = GameState.companion_stats
	melee_range = float(cs.range)
	melee_damage = int(cs.damage * cs.damage_mult)
	melee_cooldown = 1.0 / maxf(cs.attack_speed, 0.01)
	# speed_scale sofort setzen
	if _anim_sprite:
		_anim_sprite.speed_scale = anim_speed_scale

func setup(player_ref: Node2D) -> void:
	_player = player_ref
	if _player:
		global_position = _player.global_position + offset

func _physics_process(delta: float) -> void:
	# ── Modus-Zweig: 2 Spieler = hand­gesteuert (WASD), 1 Spieler = KI ───────────
	if GameState.is_coop():
		_move_coop()
		# Cooldown, Angriff und Animation wie üblich
		_process_attack_and_anim()
		return

	# ── 1-Spieler-Modus: bestehende KI-Logik ────────────────────────────────────
	if not _player or not is_instance_valid(_player):
		return

	# ── Prüfen ob der Spieler sich bewegt ──────────────────────────────────────
	var player_moving := false
	if _player is CharacterBody2D:
		player_moving = abs(_player.velocity.x) > 1.0 or abs(_player.velocity.y) > 1.0

	# ── Wander-Logik ───────────────────────────────────────────────────────────
	if not player_moving:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			var angle := randf() * TAU
			var dist := randf_range(wander_radius * 0.3, wander_radius)
			_wander_target = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
			_wander_timer = wander_pause + randf_range(0.0, 1.5)
			_is_wandering = true
	else:
		_is_wandering = false

	# Zielposition berechnen
	var target_pos: Vector2
	if _is_wandering:
		target_pos = _wander_target
		if global_position.distance_to(target_pos) < 5.0:
			_is_wandering = false
			_wander_timer = wander_pause
	else:
		target_pos = _player.global_position + offset

	# ── Bewegung (immer, auch während Angriff) ──────────────────────────────────
	var to_target := target_pos - global_position
	var dist := to_target.length()

	if dist > 2.0:
		_current_dir = to_target.normalized()
		global_position = global_position.lerp(target_pos, 0.15)
	else:
		_current_dir = Vector2.ZERO

	# ── Angriff & Animation ─────────────────────────────────────────────────────
	_process_attack_and_anim()


# ── 2-Spieler-Bewegung (WASD direkt über Physical-Keys, ohne InputAction) ─────
func _move_coop() -> void:
	var dx := 0.0
	var dy := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		dy -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dy += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dx -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dx += 1.0

	var dir := Vector2(dx, dy)
	if dir != Vector2.ZERO:
		_current_dir = dir.normalized()
		global_position += _current_dir * move_speed * get_physics_process_delta_time()
	else:
		_current_dir = Vector2.ZERO

	# Im 2P-Modus: Grenzen am Viewport (damit man nicht rausgeht)
	var vp := get_viewport_rect().size
	global_position = global_position.clamp(Vector2(18, 18), vp - Vector2(18, 18))


# ── Gemeinsamer Angriff & Animation (für 1P und 2P) ────────────────────────────
func _process_attack_and_anim() -> void:
	# Cooldown in beiden Modi herunterzählen
	if _attack_cooldown > 0.0:
		_attack_cooldown -= get_physics_process_delta_time()

	# ── Automatischer Nahkampf-Angriff (bester Gegner in Reichweite) ────────────
	if not is_attacking and _attack_cooldown <= 0.0:
		var target: Node2D = _find_nearest_enemy()
		if target:
			var attack_dir: Vector2 = (target.global_position - global_position).normalized()
			_start_attack(attack_dir)

	# ── Animation steuern ───────────────────────────────────────────────────────
	if _anim_sprite and _anim_sprite.sprite_frames:
		# Angriff-Animation hat Vorrang
		if not is_attacking:
			var target_anim := ""
			if _current_dir != Vector2.ZERO:
				if _current_dir.y < -0.1:
					target_anim = "running_back" if _anim_sprite.sprite_frames.has_animation("running_back") else "running"
				elif _current_dir.y > 0.1:
					target_anim = "walking_front" if _anim_sprite.sprite_frames.has_animation("walking_front") else "running"
				else:
					target_anim = "running"
			else:
				target_anim = "idle"

			# Flip bei linke Bewegung
			_anim_sprite.flip_h = _current_dir.x < -0.05

			# Animation nur wechseln, wenn nötig
			if _anim_sprite.sprite_frames.has_animation(target_anim):
				if _anim_sprite.get_animation() != target_anim or not _anim_sprite.is_playing():
					_anim_sprite.play(target_anim)
					_anim_sprite.speed_scale = anim_speed_scale

# ── Nächsten Gegner finden ─────────────────────────────────────────────────────
func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var e: Node2D = enemy as Node2D
		if e == null:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e

	if nearest and global_position.distance_to(nearest.global_position) <= melee_range:
		return nearest
	return null

# ── Angriff starten ────────────────────────────────────────────────────────────
func _start_attack(dir: Vector2) -> void:
	if is_attacking or _attack_cooldown > 0.0:
		return

	is_attacking = true
	_attack_cooldown = melee_cooldown
	_attack_direction = dir if dir != Vector2.ZERO else Vector2(1.0, 0.0)

	# ── Richtungs-Animation auswählen (nur wenn Sprite vorhanden) ──────────────
	if _anim_sprite and _anim_sprite.sprite_frames:
		var anim_name := ""
		var flip := false

		if _attack_direction.y < -0.1:
			anim_name = "attack_back"
			flip = false
		elif _attack_direction.y > 0.1:
			anim_name = "attack_front"
			flip = false
		elif _attack_direction.x != 0.0:
			anim_name = "attack_right"
			flip = _attack_direction.x < 0.0

		# Fallback
		if anim_name == "":
			anim_name = "attack_front"

		# Animation abspielen
		if _anim_sprite.sprite_frames.has_animation(anim_name):
			_anim_sprite.flip_h = flip
			_anim_sprite.play(anim_name)
			_anim_sprite.speed_scale = anim_speed_scale

	# Debug
	queue_redraw()

	# ── Schaden ausüben ────────────────────────────────────────────────────────
	_perform_melee_damage()

	# Warten bis die Attacke vorbei ist
	await get_tree().create_timer(melee_cooldown).timeout
	is_attacking = false
	queue_redraw()

# ── Schaden ausüben ────────────────────────────────────────────────────────────
func _perform_melee_damage() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var attack_angle := _attack_direction.angle()

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var e: Node2D = enemy as Node2D
		if e == null:
			continue
		var rel := e.global_position - global_position
		var dist := rel.length()

		if dist > melee_range:
			continue

		# Bogen checken
		var enemy_angle := rel.angle()
		var angle_diff := fmod(absf(enemy_angle - attack_angle) + TAU, TAU)
		if angle_diff > PI:
			angle_diff = TAU - angle_diff
		if angle_diff > melee_arc / 2.0:
			continue

		# Schaden (Companion nutzt eigene Eis/Freeze-Stats)
		var cs: Dictionary = GameState.companion_stats
		var ice := int(cs.ice_damage)
		var freeze := float(cs.freeze_duration)
		enemy.take_damage(melee_damage, global_position, ice, freeze)

# ── Debug-Zeichnen ─────────────────────────────────────────────────────────────
func _draw() -> void:
	if not debug_draw or not is_attacking:
		return

	var attack_angle := _attack_direction.angle()
	var start_angle := attack_angle - melee_arc / 2.0
	var end_angle := attack_angle + melee_arc / 2.0

	var steps := 30
	var points: Array = []
	for i in range(steps + 1):
		var t := i / float(steps)
		var angle := start_angle + (end_angle - start_angle) * t
		var point := Vector2(cos(angle), sin(angle)) * melee_range
		points.append(point)

	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(0.5, 1.0, 0.5, 0.5), 3.0)

	draw_circle(Vector2.ZERO, 5.0, Color(0.5, 1.0, 0.5, 0.3))
