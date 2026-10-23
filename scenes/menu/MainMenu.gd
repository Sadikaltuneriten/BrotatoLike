extends Control

# Hauptmenü: 1 Spieler / 2 Spieler / Einstellungen / Beenden
# Setzt den Spielmodus und startet die Game-Szene.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const SETTINGS_SCENE := "res://scenes/menu/SettingsMenu.tscn"

@onready var btn_single: Button = $VBox/BtnSingle
@onready var btn_coop: Button = $VBox/BtnCoop
@onready var btn_settings: Button = $VBox/BtnSettings
@onready var btn_quit: Button = $VBox/BtnQuit
@onready var mode_label: Label = $VBox/ModeLabel


func _ready() -> void:
	# Alle Menü-Buttons verbinden
	if btn_single:
		btn_single.pressed.connect(_on_single_pressed)
	if btn_coop:
		btn_coop.pressed.connect(_on_coop_pressed)
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
	_update_mode_label()


func _update_mode_label() -> void:
	if mode_label:
		if "game_mode" in GameState:
			mode_label.text = "Auswahl: %d Spieler" % GameState.game_mode
		else:
			mode_label.text = "Auswahl: 1 Spieler"


func _on_single_pressed() -> void:
	_start_game(1)


func _on_coop_pressed() -> void:
	_start_game(2)


func _on_settings_pressed() -> void:
	# Einstellungen (noch leer) – nur wenn die Szene existiert
	if ResourceLoader.exists(SETTINGS_SCENE):
		get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


# Setzt den Modus und wechselt in die Game-Szene
func _start_game(mode: int) -> void:
	GameState.game_mode = mode
	# Bei Modus-Wechsel Stats frisch setzen
	GameState.reset()
	get_tree().change_scene_to_file(GAME_SCENE)
