extends Node2D

#this script handles the randomized map generation

#variables and arrays that store the scenes and nodes for path generation
var map_grid_column: PackedScene = preload("res://scenes/map_grid_column.tscn")
var map_node: PackedScene = preload("res://scenes/map_node.tscn")
var map_grid_columns: Array[Control]
var boss_node
var map_texture: TextureRect

var column_width
var column_height
var column_vertical_offset

#flag that prevents user from moving to a new room before finishing the current encounter
var map_lock = false

var used_combat_encounters: Dictionary
var used_event_encounters: Dictionary

func _ready() -> void:
	randomize()
	map_texture = $"TextureRect"
	#sets the dimensions of the columns
	column_width = (map_texture.size.x-319)/GameManager.MapGridWidth
	column_height = 704
	column_vertical_offset = 192

	init_map_grid_columns()
	init_node_paths()
	clear_empty_nodes()
	roll_room_types()
	generate_boss_node()

#--------------------------------------
# This function initializes the columns
# for the node generation grid
#--------------------------------------
func init_map_grid_columns():
	for i in range(GameManager.MapGridWidth):
		var new_column = map_grid_column.instantiate()
		new_column.column_index = i
		map_grid_columns.append(new_column)
		add_child(new_column)
		new_column.init_container_transform()
		new_column.init_empty_nodes()

#----------------------------------------------------------------
# This function randomly generates the paths for the current run.
# Generates the paths one at a time, ensuring all map nodes are
# within the grid and the paths do not cross
#----------------------------------------------------------------
func init_node_paths():
	for i in range(6):
		var start_pos = randi() % GameManager.MapGridHeight
		if i == 1 and map_grid_columns[0].existing_node_flags[start_pos] == 1:
			while map_grid_columns[0].existing_node_flags[start_pos] != 1:
				start_pos = randi() % GameManager.MapGridHeight
		var current_node = map_grid_columns[0].map_nodes[start_pos]
		current_node.is_empty = false
		current_node.is_path_option = true
		for j in range(1,GameManager.MapGridWidth):
			var next_position = randi() % 3 + (current_node.row_index-1)
			while(map_grid_columns[j-1].check_for_crossing(current_node.row_index, next_position)):
				next_position = randi() % 3 + (current_node.row_index-1)
			next_position = clamp(next_position, 0, GameManager.MapGridHeight-1)

			var next_node = map_grid_columns[j].map_nodes[next_position]
			map_grid_columns[j].existing_node_flags[next_position] = 1
			if not next_node in current_node.forward_connected_nodes:
				current_node.forward_connected_nodes.append(next_node)
			current_node.create_path_line(next_node)
			map_grid_columns[j-1].connections.append(Vector2(current_node.row_index, next_position))

			next_node.backward_connected_nodes.append(current_node)
			next_node.is_empty = false
			current_node = next_node

#-------------------------------------------------
# This function rolls the room types for each node
# using weights and specific generation rules
#-------------------------------------------------
func roll_room_types():
	var room_weights = {
			GameManager.RoomTypes.Combat: 50,
			GameManager.RoomTypes.Event: 35,
			GameManager.RoomTypes.Rest: 25,
			GameManager.RoomTypes.Shop: 20
		}
	for column in map_grid_columns:
		for node in column.map_nodes:
			var previous_nodes = node.get_prev_nodes()
			if not node.room_type_rolled:
				if node.get_parent().column_index == 0:
					node.room_type = GameManager.RoomTypes.Combat
				else:
					var weights = room_weights.duplicate()
					adjust_weights(node, previous_nodes, weights)
					node.room_type = roll_room(weights)
				node.room_type_rolled = true
				node.update_sprite()

#------------------------------------------------------------
# This function adjusts the room weights for the current node
#------------------------------------------------------------
func adjust_weights(node, previous_nodes, weights):
	if not previous_nodes.is_empty():
		if type_in_last_n_rooms(node, previous_nodes, GameManager.RoomTypes.Combat, 1):
			weights[GameManager.RoomTypes.Combat] *= 0.3
		if type_in_last_n_rooms(node, previous_nodes, GameManager.RoomTypes.Event, 1):
			weights[GameManager.RoomTypes.Event] *= 0.3
		if type_in_last_n_rooms(node, previous_nodes, GameManager.RoomTypes.Shop, 3):
			weights[GameManager.RoomTypes.Shop] = 0
		if type_in_last_n_rooms(node, previous_nodes, GameManager.RoomTypes.Rest, 3):
			weights[GameManager.RoomTypes.Rest] = 0

func type_in_last_n_rooms(node, previous_nodes, type:GameManager.RoomTypes, n):
	var index = 0
	while index < previous_nodes.size() and node.get_parent().column_index - previous_nodes[index].get_parent().column_index <= n:
		if previous_nodes[index].room_type == type:
			return true
		index += 1
	return false

func roll_room(weights):
	var total = 0
	for value in weights.values():
		total += value
	var roll = randi_range(0, total-1)
	var cumulative = 0
	for key in weights.keys():
		cumulative += weights[key]
		if roll < cumulative:
			return key

#----------------------------------------------------------
# Clears empty nodes and connects node_clicked signals
#----------------------------------------------------------
func clear_empty_nodes():
	for column in map_grid_columns:
		for i in range(column.map_nodes.size()-1, -1, -1):
			if column.map_nodes[i].is_empty:
				var deleting_node = column.map_nodes[i]
				column.map_nodes.erase(deleting_node)
				deleting_node.queue_free()
			else:
				column.map_nodes[i].node_clicked.connect(_on_map_node_clicked)

#--------------------------------------------------------
# Generates the boss node at the end of the map
#--------------------------------------------------------
func generate_boss_node():
	boss_node = map_node.instantiate()
	boss_node.global_position = Vector2(2650, map_texture.size.y/2-boss_node.size.y/2)
	boss_node.row_index = GameManager.MapGridHeight/2
	boss_node.room_type = GameManager.RoomTypes.Boss
	boss_node.update_sprite()
	add_child(boss_node)
	boss_node.node_clicked.connect(_on_map_node_clicked)
	for node in map_grid_columns.back().map_nodes:
		node.forward_connected_nodes.append(boss_node)
		node.create_path_line(boss_node)

#-----------------------------------------------------------
# Called when a valid map node is clicked.
# Integrates with BattleManager for combat/boss rooms,
# and with SceneManager for rest/shop/event rooms.
#-----------------------------------------------------------
func _on_map_node_clicked(node: Control):
	if map_lock:
		return

	update_path_options(node)
	map_lock = true
	hide_map()

	match node.room_type:
		GameManager.RoomTypes.Combat:
			var room_data = roll_combat_encounter()
			var enemy = _enemy_from_room_data(room_data)
			BattleManager.start_battle(enemy)

		GameManager.RoomTypes.Boss:
			BattleManager.start_boss_fight()

		GameManager.RoomTypes.Rest:
			SceneManager.change_scene("res://scenes/rest.tscn")

		GameManager.RoomTypes.Shop:
			# Shop not yet implemented — return to map
			GameManager.encounter_complete()

		GameManager.RoomTypes.Event:
			# Events not yet implemented — return to map
			GameManager.encounter_complete()

# Maps the enemies string array from a CombatData resource to a CombatData.Enemy enum value.
func _enemy_from_room_data(room_data) -> CombatData.Enemy:
	if room_data == null or room_data.enemies.is_empty():
		return CombatData.Enemy.GOBLIN
	var name_lower = room_data.enemies[0].to_lower()
	if "skeleton" in name_lower:
		return CombatData.Enemy.SKELETON
	return CombatData.Enemy.GOBLIN

#------------------------------------------------
# Rolls a weighted combat encounter from .tres files
#------------------------------------------------
func roll_combat_encounter():
	var combat_encounter_variations = get_all_room_variation_tres(GameManager.RoomTypes.Combat)
	if combat_encounter_variations:
		var total = 0
		for variation in combat_encounter_variations:
			if variation.id in used_combat_encounters:
				variation.gen_weight /= used_combat_encounters[variation.id]
			total += variation.gen_weight
		var roll = randi_range(0, total-1)
		var cumulative = 0
		for variation in combat_encounter_variations:
			cumulative += variation.gen_weight
			if roll < cumulative:
				if variation.id in used_combat_encounters:
					used_combat_encounters[variation.id] += 1
				else:
					used_combat_encounters[variation.id] = 2
				return variation
	else:
		print("Error: Failed to load combat_data resources")
	return null

func roll_event_variation():
	var event_variations = get_all_room_variation_tres(GameManager.RoomTypes.Event)
	if event_variations:
		var total = 0
		for variation in event_variations:
			if variation.id in used_event_encounters:
				variation.gen_weight /= used_event_encounters[variation.id]
			total += variation.gen_weight
		var roll = randi_range(0, total-1)
		var cumulative = 0
		for variation in event_variations:
			cumulative += variation.gen_weight
			if roll < cumulative:
				if variation.id in used_event_encounters:
					used_event_encounters[variation.id] += 1
				else:
					used_event_encounters[variation.id] = 2
				return variation
	else:
		print("Error: Failed to load event resources")
	return null

#-----------------------------------------------------
# Loads all RoomData .tres files for a given room type
#-----------------------------------------------------
func get_all_room_variation_tres(room_type: GameManager.RoomTypes):
	var path = "res://code/rooms/"
	match room_type:
		GameManager.RoomTypes.Combat:
			path += "combat"
		GameManager.RoomTypes.Event:
			path += "event"

	var dir_access = DirAccess.open(path)
	var resources: Array[Resource]
	if dir_access:
		var file_list = dir_access.get_files()
		for file in file_list:
			file = path + "/" + file
			var resource: Resource = ResourceLoader.load(file)
			if resource:
				resources.append(resource)
		return resources
	else:
		print("Error: Could not open path: ", path)
		return null

#----------------------------------------------------
# Updates path options after the player selects a node
#----------------------------------------------------
func update_path_options(current_node):
	if not current_node.room_type == GameManager.RoomTypes.Boss:
		for node in current_node.get_parent().map_nodes:
			node.is_path_option = false
			node.update_sprite()
		for node in current_node.forward_connected_nodes:
			node.is_path_option = true
			node.update_sprite()

func hide_map():
	hide()
	$"MapCamera".enabled = false

func show_map():
	show()
	$"MapCamera".enabled = true
