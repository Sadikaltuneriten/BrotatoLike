extends Area2D

var direction := Vector2.RIGHT
var speed := 400.0
var damage := 15
var lifetime := 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(dir: Vector2, spd: float, dmg: int) -> void:
	direction = dir
	speed = spd
	damage = dmg
	
	# + PI (180 Grad) addieren, damit die Spitze in die Flugrichtung zeigt
	rotation = direction.angle() + PI

func _process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	# (Falls du mittlerweile das AnimatedSprite2D nutzt, kannst du den draw_circle-Befehl 
	# und die Methode hier theoretisch auch komplett löschen, damit der gelbe Punkt verschwindet)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.9, 0.1))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		
		# Treffer-Sound abspielen und Kugel danach löschen
		var hit_sound := get_node_or_null("HitSound") as AudioStreamPlayer2D
		if hit_sound and hit_sound.stream:
			hide() # Kugel unsichtbar machen
			set_deferred("monitoring", false) # Kollisionen deaktivieren
			hit_sound.play()
			await hit_sound.finished
			
		queue_free()
