extends RoomData
class_name CombatData

@export var enemies: Array[String]
@export var max_gold: int = 12
@export var min_gold: int = 8

enum Enemy {
	GOBLIN,
	SKELETON,
	BOSS
}

#---NOTICE---
# When adding new enemies, ensure all fields are valid or problems may occur!!
# Refer to cards.json when deciding what cards you would like to give to an enemy. 

const ENEMY_DETAILS : Dictionary = {
	Enemy.GOBLIN: {
		"name": "Goblin",
		"hp": 70,
		"maxHp": 100,
		"cards": [12, 12, 12, 13, 13, 13, 8, 8],
		"sprite": "res://assets/Monsters/goblin_1.png"
	}, 
	Enemy.SKELETON: {
		"name": "Skeleton",
		"hp": 70,
		"maxHp": 100,
		"cards": [7, 7, 7, 7],
		"sprite": "res://assets/Monsters/skeleton_1.png"
	},
	# Boss cards are overridden at runtime by combat.gd based on the previous run's deck.
	# The cards array here is the default 50/50 fallback used on the first encounter.
	Enemy.BOSS: {
		"name": "The Lich",
		"hp": 250,
		"maxHp": 250,
		"cards": [0, 0, 3, 3, 12, 12, 6, 6, 1, 1, 7, 7, 2, 2, 4, 4],
		"sprite": "res://assets/Monsters/lich.png"
	}
}
