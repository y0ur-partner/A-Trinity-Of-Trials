extends Control

func _ready() -> void:
	pass

func _on_main_menu_button_pressed() -> void:
	GameManager.reset_run()
	SceneManager.change_scene("res://scenes/main_menu.tscn")
