extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if animated_sprite:
		animated_sprite.play("default")

func _on_animated_sprite_2d_animation_finished() -> void:
	# Sofort unsichtbar machen, damit nichts hängen bleibt
	hide()
	queue_free()
