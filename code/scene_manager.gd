extends Node

# Holds a reference to the most recently loaded scene so load_room_data() can call into it
var PrimaryScene: Node = null

func change_scene(scene_path: String) -> void:
	var scene_container = get_node("/root/Main/SceneContainer")

	for child in scene_container.get_children():
		if child.scene_file_path == "res://scenes/combat.tscn" and child.has_method("combat_end"):
			child.combat_end()
		child.queue_free()

	await get_tree().process_frame

	var new_scene = load(scene_path).instantiate()
	scene_container.add_child(new_scene)
	PrimaryScene = new_scene

	# Only show the combat HUD overlay while in the combat scene
	get_node("/root/Main/UIOverlay").visible = (scene_path == "res://scenes/combat.tscn")

	print("Changed scene to:", scene_path)

# Removes all scenes from SceneContainer and hides the HUD overlay.
# Does NOT load a new scene — used when returning to the persistent map.
func clear_scenes() -> void:
	var scene_container = get_node("/root/Main/SceneContainer")
	for child in scene_container.get_children():
		if child.scene_file_path == "res://scenes/combat.tscn" and child.has_method("combat_end"):
			child.combat_end()
		child.queue_free()
	PrimaryScene = null
	get_node("/root/Main/UIOverlay").visible = false

# Passes a RoomData resource into the current scene (used by map for event/shop rooms)
func load_room_data(data: RoomData) -> void:
	if PrimaryScene != null and PrimaryScene.has_method("init_room_data"):
		PrimaryScene.init_room_data(data)
	else:
		print("SceneManager: current scene has no init_room_data method")
