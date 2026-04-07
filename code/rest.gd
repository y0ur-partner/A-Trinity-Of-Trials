extends Control

func _ready() -> void:
	var heal_amount = int(GameManager.PlayerMaxHP * 0.3)
	GameManager.PlayerHP = min(GameManager.PlayerHP + heal_amount, GameManager.PlayerMaxHP)

	$VBoxContainer/HealLabel.text = "You rest by the fire and recover %d HP." % heal_amount
	$VBoxContainer/HPLabel.text   = "HP: %d / %d" % [GameManager.PlayerHP, GameManager.PlayerMaxHP]


func _on_continue_pressed() -> void:
	GameManager.encounter_complete()
