extends Node

func _ready() -> void:
	var companion_script = load("res://scripts/Companion.gd")
	var companion = companion_script.new()
	
	companion.max_hp = 100.0
	companion.armor = 5.0
	companion.current_hp = companion.max_hp
	add_child(companion)
	
	if companion.current_hp != 100.0:
		push_error("Initial HP mismatch: " + str(companion.current_hp))
		get_tree().quit(1)
		return
	
	companion.take_damage(20.0)
	
	if companion.current_hp != 85.0:
		push_error("Damage calculation incorrect: " + str(companion.current_hp))
		get_tree().quit(1)
		return
		
	companion.take_damage(100.0)
	
	# Warten bis zum nächsten Frame für queue_free()
	await get_tree().process_frame
	
	if not is_instance_valid(companion) or not companion.is_queued_for_deletion():
		print("SUCCESS")
		get_tree().quit(0)
	else:
		push_error("Companion did not die correctly")
		get_tree().quit(1)
