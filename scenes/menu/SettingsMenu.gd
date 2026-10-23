extends Control

# Einstellungen (noch leer – Platzhalter für spätere Optionen)
const MAIN_MENU_SCENE := "res://scenes/menu/MainMenu.tscn"

@onready var btn_back: Button = $VBox/BtnBack


func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
