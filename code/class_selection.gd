extends Control

func _ready():
	print("_ready running")

# ----------------------------
# BUTTON PRESSED FUNCTIONS
# ----------------------------

func _on_gundam_pressed():
	start_game(GameManager.PlayerClass.GUNDAM)

func _on_mage_pressed():
	start_game(GameManager.PlayerClass.HEXTECHMAGE)

func _on_creature_pressed():
	start_game(GameManager.PlayerClass.CREATURE)


# ----------------------------
# START GAME
# ----------------------------

func start_game(selected_class):
	print("Selected class: ", selected_class)
	GameManager.setup_class(selected_class)
	GameManager.start_run()
