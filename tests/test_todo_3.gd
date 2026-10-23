extends Node

func _ready():
	call_deferred("run_test")

func run_test():
	var game_node = get_tree().root.find_child("Game", true, false)
	if not game_node:
		push_error("ERROR: Game node not found")
		return

	var companion_label = game_node.get_node_or_null("HUD/Player2HP")
	if not companion_label:
		push_error("ERROR: HUD/Player2HP Label not found")
		return

	GameState.companion_hp = 75
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if companion_label.text == "75":
		print("SUCCESS")
	else:
		push_error("ERROR: HUD label text mismatch. Expected '75', got: " + companion_label.text)
	
	get_tree().quit()
