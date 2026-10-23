extends Node2D

@onready var player_hp_bar = $CanvasLayer/HUD/PlayerHPBar
@onready var companion_hp_bar = $CanvasLayer/HUD/CompanionHPBar
@onready var player = $Player
@onready var companion = $Companion

func _ready():
	player.health_changed.connect(_on_player_health_changed)
	companion.health_changed.connect(_on_companion_health_changed)
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value = player.current_health
	companion_hp_bar.max_value = companion.max_health
	companion_hp_bar.value = companion.current_health

func _on_player_health_changed(new_health):
	player_hp_bar.value = new_health

func _on_companion_health_changed(new_health):
	companion_hp_bar.value = new_health

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")