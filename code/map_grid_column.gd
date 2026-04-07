extends Control

#This script handles the functionality for the column scene that contains all the nodes in one column of the map grid

var column_index = 0

var map_node_scene: PackedScene = preload("res://scenes/map_node.tscn")
#used in path generation
var existing_node_flags: Array[int] = [0,0,0,0,0,0,0,0,0,0,0,0]
#holds the grid coordinate positions for all path connections in this column
var connections: Array[Vector2]
#contains all the nodes in this column
var map_nodes: Array[Control]

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

#sets the dimensions and position of the column
func init_container_transform():
	custom_minimum_size = Vector2(get_parent().column_width, get_parent().column_height)
	global_position = Vector2(custom_minimum_size.x*column_index, get_parent().column_vertical_offset)

#initializes an empty node for every row position in the column
func init_empty_nodes():
	for i in range(GameManager.MapGridHeight):
		var new_node = map_node_scene.instantiate()
		new_node.row_index = i
		new_node.position = Vector2.ZERO
		map_nodes.append(new_node)
		add_child(new_node)
		new_node.update_position()

#makes sure that the path currently being generated wont cross with another path
func check_for_crossing(current_position, target_position):
	for conn in connections:
		if (current_position < conn.x and target_position > conn.y) or (current_position > conn.x and target_position < conn.y):
			return true
	return false

#-----------------------------------Debug Functions-----------------------------------
func print_transform_data():
	print("Column index: " + str(column_index))
	print("Custom Minimum Size" + str(custom_minimum_size))
	print("Position: (" + str(position.x) + "," + str(position.y) + ")")
