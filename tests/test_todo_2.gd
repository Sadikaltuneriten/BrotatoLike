extends Node

func _ready() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var companion = Node2D.new()
	companion.set_script(load("res://tests/MockCompanion.gd"))
	add_child(companion)
	
	var enemy = Enemy.new()
	add_child(enemy)
	
	var hitbox = Area2D.new()
	hitbox.name = "HitBox"
	enemy.add_child(hitbox)
	
	# Manuelle Zuweisung der onready Variable da wir kein Szenario laden
	enemy.hit_box = hitbox
	enemy._ready()
	
	# Wir rufen _on_body_entered direkt auf, da dies das Test-Szenario ist
	enemy._on_body_entered(companion)
	
	if companion.damage_received == 10:
		print("SUCCESS")
	else:
		print("FAILURE: Companion hat keinen Schaden erhalten. Erhalten: ", companion.damage_received)
	
	enemy.queue_free()
	companion.queue_free()
	get_tree().quit()
