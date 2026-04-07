extends Node

#main node for the game, loads on startup of the game

func _ready() -> void:
	print("Main scene loaded")
	SceneManager.change_scene("res://scenes/main_menu.tscn")
	
	#test_scene_change()

#test function for scene transitions, makes sure that combat reinitializes the draw pile properly
func test_scene_change():
	print("Changing scene in:")
	print("3")
	await get_tree().create_timer(1).timeout
	print("2")
	await get_tree().create_timer(1).timeout
	print("1")
	await get_tree().create_timer(1).timeout
	SceneManager.change_scene("res://scenes/main_menu.tscn")
	print("Changing scene in:")
	print("3")
	await get_tree().create_timer(1).timeout
	print("2")
	await get_tree().create_timer(1).timeout
	print("1")
	await get_tree().create_timer(1).timeout
	SceneManager.change_scene("res://scenes/combat.tscn")
