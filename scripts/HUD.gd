extends CanvasLayer

@onready var player1_health = $Player1HealthBar
@onready var player2_health = $Player2HealthBar

func _ready():
	GameState._log("HUD initialized.")
	update_health()

func update_health():
	if has_node("Player2HealthBar"):
		GameState._log("Updating Player 2 Health Bar.")
		# Hier Logik zur Kopplung mit Spieler 2 Instanz einfuegen
	else:
		GameState._log("ERROR: Player 2 Health Bar node not found!")