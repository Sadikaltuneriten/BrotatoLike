extends AnimatedSprite2D

func _ready() -> void:
	play("default")

func _on_animated_sprite_2d_animation_finished() -> void:
	# Sofort unsichtbar machen, damit nichts hängen bleibt
	hide()
	queue_free()
