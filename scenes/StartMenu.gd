extends Control

func _on_start_button_pressed():
	GameState._log("Start button pressed.")
	GameState.start_game()