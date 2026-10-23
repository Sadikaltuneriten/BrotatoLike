extends SceneTree

func _init():
	print("Starting Test Runner...")
	
	# Mocking basic player setup
	var player1 = CharacterBody2D.new()
	player1.add_to_group("player")
	root.add_child(player1)
	
	var player2 = CharacterBody2D.new()
	player2.add_to_group("player")
	player2.global_position = Vector2(500, 500)
	root.add_child(player2)
	
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	root.add_child(enemy)
	
	await Engine.get_main_loop().process_frame
	
	if enemy.target_players.size() == 2:
		print("Test Passed: Multiple players detected.")
		quit(0)
	else:
		print("Test Failed: Expected 2 players, found ", enemy.target_players.size())
		quit(1)