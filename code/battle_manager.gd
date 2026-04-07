extends Node

#current enemy global to be passed to combat.gd. This was the easiest way to do this, and I'm aware there are probably better ways to do so
#Currently only holds one enemy. Will allow for up to 4 once basic combat is done
var current_enemy: CombatData.Enemy

#Initialize a battle
func start_battle(enemy: CombatData.Enemy):
	current_enemy = enemy
	GameManager.is_boss_fight = false
	print(CombatData.ENEMY_DETAILS[enemy]["name"])
	SceneManager.change_scene("res://scenes/combat.tscn")

# Starts the boss fight at the end of the run
func start_boss_fight():
	current_enemy = CombatData.Enemy.BOSS
	GameManager.is_boss_fight = true
	print("Boss fight starting: ", CombatData.ENEMY_DETAILS[CombatData.Enemy.BOSS]["name"])
	SceneManager.change_scene("res://scenes/combat.tscn")
