extends Control

var idleTexture: Texture2D
var hoverTexture: Texture2D

var row_index
var is_empty = true
var room_type
var room_type_rolled = false
var forward_connected_nodes: Array[Control]
var backward_connected_nodes: Array[Control]
var connecting_lines: Array[Line2D]

var is_path_option = false

#gives spacing between the connecting lines and their nodes 
var line_offset_radius = 48

signal node_clicked
#keeps track of how long the left click was held on the node to handle dragging the map when clicking on a node
var pressed_time = 0
var click_deadzone = 3

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func update_position():
	var column = get_parent()
	global_position = Vector2(column.custom_minimum_size.x*column.column_index+column.get_parent().column_width/2-size.x/2, column.get_parent().column_vertical_offset+column.get_parent().column_height/GameManager.MapGridHeight * row_index+size.y/2)

#changes the sprites to correlate to their room type
func update_sprite():
	#fades the node if it is not a valid path option
	if not is_path_option:
		$"NodeTexture".self_modulate.a = 0.50
	else:
		$"NodeTexture".self_modulate.a = 1.0
	match room_type:
		GameManager.RoomTypes.Combat:
			idleTexture = load("res://sprites/map/battle_icon.png")
			hoverTexture = load("res://sprites/map/battle_icon_hovering.png")
		GameManager.RoomTypes.Event:
			idleTexture = load("res://sprites/map/event_icon.png")
			hoverTexture = load("res://sprites/map/event_icon_hovering.png")
		GameManager.RoomTypes.Rest:
			idleTexture = load("res://sprites/map/rest_icon.png")
			hoverTexture = load("res://sprites/map/rest_icon_hovering.png")
		GameManager.RoomTypes.Shop:
			idleTexture = load("res://sprites/map/shop_icon.png")
			hoverTexture = load("res://sprites/map/shop_icon_hovering.png")
		GameManager.RoomTypes.Boss:
			idleTexture = load("res://sprites/map/battle_icon.png")
			hoverTexture = load("res://sprites/map/battle_icon_hovering.png")
	$"NodeTexture".texture = idleTexture

#renders the line between connected nodes
func create_path_line(next_node):
	var new_line = Line2D.new()
	new_line.default_color = "#75503f"
	new_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	new_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	new_line.width = 6
	#line starting point
	var p1 = Vector2($"NodeTexture".size.x/2, $"NodeTexture".size.y/2)
	#line end point
	var p2 = Vector2(next_node.global_position.x-global_position.x+$"NodeTexture".size.x/2, next_node.global_position.y-global_position.y+abs($"NodeTexture".size.y/2))
	var direction = (p2-p1).normalized()
	#offsets the start and endpoints of the line so that they are not directly next to the nodes
	p1 += direction * line_offset_radius
	p2 -= direction * line_offset_radius
	new_line.add_point(p1)
	new_line.add_point(p2)
	add_child(new_line)
	connecting_lines.append(new_line)

#returns all the nodes in every path leading to this node
func get_prev_nodes() -> Array[Control]:
	#the array that will be returned
	var prev_path: Array[Control]
	#queue that traverses the paths
	var queue = backward_connected_nodes.duplicate()
	
	while not queue.is_empty():
		var current_node = queue.front()
		#print_queue(queue, prev_path)
		#gets all the nodes connecting to the back of the node at the front of the queue
		for node in current_node.backward_connected_nodes:
			#prevents duplicate nodes in the queue
			if not node in queue:
				queue.append(node)
		#prevents duplicate nodes in the resulting array
		if not current_node in prev_path:
			prev_path.append(current_node)
		#removes the node at the front of the queue
		queue.remove_at(0)
	#print_queue(queue, prev_path)
	return prev_path
#----------------------------Input Handling Functions--------------------------------------

#changes the texture when the mouse cursor is over the node
func _on_mouse_entered():
	if $"NodeTexture".texture != hoverTexture:
		$"NodeTexture".texture = hoverTexture

#changes the texture once the mouse is no longer hovering over the node
func _on_mouse_exited():
	if $"NodeTexture".texture != idleTexture:
		$"NodeTexture".texture = idleTexture

func _gui_input(event):
	if is_path_option and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			node_clicked.emit(self)

#--------------------------------Debug Functions-------------------------------------------
func print_queue(queue, prev_path):
	print("Queue:")
	for node in queue:
		print("(" + str(node.get_parent().column_index) + "," + str(node.row_index) + ")")
	print("Prev_path:")
	for node in prev_path:
		print("(" + str(node.get_parent().column_index) + "," + str(node.row_index) + ")")

func print_grid_position():
	print("(" + str(get_parent().column_index) + "," + str(row_index) + ")")

func print_backward_connected_nodes():
	print("Current Node:")
	print_grid_position()
	print("Backward connected nodes:")
	for node in backward_connected_nodes:
		node.print_grid_position()
