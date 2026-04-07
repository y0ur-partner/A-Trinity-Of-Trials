# Player2D.gd
extends Node2D

# Player UI and HP display
var spell_power: int = 0
var block: int = 0

# Status effects applied by the boss
var weakened_turns: int = 0      # while > 0: player deals 50% damage
var draw_penalty_turns: int = 0  # while > 0: draw 1 fewer card at turn start

func _ready() -> void:
	await get_tree().process_frame  # wait one frame for GameManager to be ready
	init_health_bar()

func init_health_bar() -> void:
	$"CharacterDataUI/HealthBar".max_value = GameManager.PlayerMaxHP
	update_health_bar()

func update_health_bar() -> void:
	$"CharacterDataUI/HealthBar".value = GameManager.PlayerHP
	$"CharacterDataUI/HPLabel".text = str(GameManager.PlayerHP) + " / " + str(GameManager.PlayerMaxHP)


func take_damage(amount: int) -> void:
	var remaining_damage = amount - block
	block = max(0, block - amount)

	if remaining_damage > 0:
		GameManager.PlayerHP -= remaining_damage
		update_health_bar()

	if GameManager.PlayerHP <= 0:
		die()

func gain_block(amount: int) -> void:
	block += amount
	print("Player gained ", amount, " block. Total block: ", block)

func heal(amount: int) -> void:
	GameManager.PlayerHP = min(GameManager.PlayerHP + amount, GameManager.PlayerMaxHP)
	update_health_bar()

func die() -> void:
	print("You have been defeated")
	# Add restart or game over logic here
