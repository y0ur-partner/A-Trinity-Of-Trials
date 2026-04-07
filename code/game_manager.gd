
extends Node

# ----------------------------
# Player variables
# ----------------------------
var PlayerMaxHP: int
var PlayerHP: int
var CardsDrawnPerTurn: int
var Deck: Control = null




enum PlayerClass {
	GUNDAM,
	HEXTECHMAGE,
	CREATURE
}

# ----------------------------
# Map system variables (used by map.gd / map_node.gd / map_grid_column.gd)
# ----------------------------
var MapGridWidth: int = 8
var MapGridHeight: int = 6

enum RoomTypes {
	Combat,
	Boss,
	Event,
	Rest,
	Shop
}

# The persistent map instance. Lives under GameManager so SceneManager.change_scene()
# never destroys it. Created once per run by start_run(), freed by reset_run().
var Map: Node2D = null

# Creates the map for the current run and makes it visible.
# Call this after setup_class() — once per run.
func start_run() -> void:
	if Map != null and is_instance_valid(Map):
		Map.queue_free()
	Map = load("res://scenes/map.tscn").instantiate()
	add_child(Map)              # added under GameManager, persists across scene changes
	SceneManager.clear_scenes() # remove the class-selection scene from SceneContainer

# Called after an encounter finishes — shows the existing map without regenerating it.
func encounter_complete() -> void:
	SceneManager.clear_scenes()
	if Map != null and is_instance_valid(Map):
		Map.map_lock = false
		Map.show_map()
	else:
		push_error("GameManager.encounter_complete: Map is null")

var current_class: PlayerClass = PlayerClass.GUNDAM

# ----------------------------
# Run state
# ----------------------------
var encounters_completed: int = 0
var is_boss_fight: bool = false
const ENCOUNTERS_BEFORE_BOSS: int = 2

# Map progression — set by map.gd on first visit, persists until reset_run()
var map_floors: Array = []   # Array of floor Arrays, each floor is Array of room Dicts
var current_floor: int = 0   # Which floor the player is currently on

# ----------------------------
# Called once when the game starts or player class changes
# ----------------------------
func setup_class(player_class: PlayerClass) -> void:
	current_class = player_class

	match player_class:
		PlayerClass.GUNDAM:
			init_player_variables(120, 4)
		PlayerClass.HEXTECHMAGE:
			init_player_variables(70, 6)
		PlayerClass.CREATURE:
			init_player_variables(100, 5)

	reset_run()
	print("Class set to:", current_class, "PlayerMaxHP:", PlayerMaxHP, "PlayerHP:", PlayerHP)

# ----------------------------
# Initialize variables for the selected class
# ----------------------------
func init_player_variables(maxhp: int, cdpt: int) -> void:

	PlayerMaxHP = maxhp
	PlayerHP = maxhp
	CardsDrawnPerTurn = cdpt

	# Only create deck once
	if Deck == null:
		Deck = load("res://scenes/deck.tscn").instantiate()
		add_child(Deck)

	# Rebuild deck every time class is set
	Deck.init_cards()
	

# ----------------------------
# Resets run-specific state (called at start of every new run)
# ----------------------------
func reset_run() -> void:
	encounters_completed = 0
	is_boss_fight = false
	map_floors.clear()
	current_floor = 0
	if Map != null and is_instance_valid(Map):
		Map.queue_free()
		Map = null

# -- This felt like the most appropriate place to put this function. If it's not, we can move it elsewhere. --
#func init_combat(enemy: CombatData.Enemy) -> void:
#	print("Hi")
#	
#	#var combat_scene = get_node("/root/Main/SceneContainer")
#	
#	SceneManager.change_scene("res://scenes/combat.tscn")
#	#combat_scene.initialize_combat(CombatData.ENEMY_DETAILS[enemy].name)
