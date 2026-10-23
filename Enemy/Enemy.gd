extends CharacterBody2D

class_name Enemy

@export var damage: int = 10
@onready var hit_box: Area2D = get_node_or_null("HitBox")

func _ready() -> void:
	if hit_box:
		hit_box.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)