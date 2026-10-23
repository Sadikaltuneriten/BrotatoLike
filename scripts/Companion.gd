extends CharacterBody2D

signal died

@export var max_hp: float = 100.0
@export var armor: float = 5.0
var current_hp: float

func _init() -> void:
	current_hp = max_hp

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	var final_damage = max(1.0, amount - armor)
	current_hp -= final_damage
	
	if current_hp <= 0:
		current_hp = 0
		die()

func die() -> void:
	died.emit()
	queue_free()