extends Node

@onready var player_hp_label = $HUD/Player1HP
@onready var companion_hp_label = $HUD/Player2HP

func _ready():
	GameState.player_hp_changed.connect(_on_player_hp_changed)
	GameState.companion_hp_changed.connect(_on_companion_hp_changed)
	
	if player_hp_label:
		player_hp_label.text = str(GameState.player_hp)
	if companion_hp_label:
		companion_hp_label.text = str(GameState.companion_hp)

func _on_player_hp_changed(new_hp: int):
	if player_hp_label:
		player_hp_label.text = str(new_hp)

func _on_companion_hp_changed(new_hp: int):
	if companion_hp_label:
		companion_hp_label.text = str(new_hp)