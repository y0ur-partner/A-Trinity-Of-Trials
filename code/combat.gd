extends Node

#combat node holds all the related nodes necessary for the combat encounter

#variables used to set the transform for all the cards/piles
var card_width = 192
var card_height = 288
var side_margin = 32
var bottom_margin = 32
var card_y = 0

#combat state variables

var player
var enemy
var player_class = null
var player_turn = true
var max_mana = 5
var player_mana = 3

var max_hand = 6 #Temporary variable that contains how many cards the player can have in their hand!!

# Pause state
var is_paused: bool = false
var _pause_overlay: CanvasLayer = null

# Boss background tween
var _boss_bg: ColorRect = null

func _ready() -> void:
	player = $"Player"
	enemy = $"Enemy"

	player_class = GameManager.PlayerClass

	initialize_combat()
	_build_pause_menu()
	if BattleManager.current_enemy == CombatData.Enemy.BOSS:
		_setup_boss_background()


func initialize_combat() -> void:
	#Fetches enemy details from the current_enemy variable before starting combat
	#todo: run this multiple times depending on how many enemies are on the field
	var currentEnemy = BattleManager.current_enemy
	enemy.max_hp = CombatData.ENEMY_DETAILS[currentEnemy]["maxHp"]
	enemy.hp = CombatData.ENEMY_DETAILS[currentEnemy]["hp"]
	enemy.init_health_bar()

	if currentEnemy == CombatData.Enemy.BOSS:
		# Analyse the previous run once and share the result with the enemy node
		var archetype = _compute_player_archetype()
		enemy.is_boss = true
		enemy.boss_archetype = archetype
		enemy.card_ids = _get_boss_cards_for_archetype(archetype)
		# Connect the phase-change signal so external systems can hook in later
		enemy.boss_phase_changed.connect(_on_boss_phase_changed)
	else:
		enemy.card_ids = CombatData.ENEMY_DETAILS[currentEnemy]["cards"]

	print(enemy.card_ids)
	enemy.parse_card_ids() #Convert the enemy's card IDs into actual cards.

	combat_start()
	start_player_turn()
	update_mana_label()
	update_block_label()
	print(enemy)

func combat_start():
	card_y = get_tree().root.get_visible_rect().size.y - card_height - bottom_margin
	init_pile_transforms()
	for i in range(GameManager.Deck.full_deck.size()):
		$"DrawPile".card_array.append(GameManager.Deck.full_deck[i].scene.instantiate())
		$"DrawPile".card_array.back().card_data = GameManager.Deck.full_deck[i].duplicate()
	$"DrawPile".card_array.shuffle()
	$"DrawPile".display_cards()


func combat_end():
	for i in range($"DrawPile".card_array.size()):
		$"DrawPile".remove_card($"DrawPile".card_array.back())
	for i in range($"DiscardPile".card_array.size()):
		$"DiscardPile".remove_card($"DiscardPile".card_array.back())
	for i in range($"HandContainer".card_array.size()):
		$"HandContainer".remove_card($"HandContainer".card_array.back())

#sets the position and size of the draw and discard pile
func init_pile_transforms():
	$"DrawPile".set_transforms()
	$"DiscardPile".set_transforms()



# Turn System
func start_player_turn():
	player_turn = true
	player_mana = max_mana
	player.block = 0
	update_mana_label()

	# Tick down boss status effects at the start of each player turn
	if enemy != null and enemy.is_boss:
		_tick_status_effects()

	draw_cards()
	update_block_label()
	print("player turn has started")

func _tick_status_effects() -> void:
	if player.weakened_turns > 0:
		player.weakened_turns -= 1
		print("Weaken: ", player.weakened_turns, " turn(s) remaining")
	if player.draw_penalty_turns > 0:
		player.draw_penalty_turns -= 1
		print("Draw penalty: ", player.draw_penalty_turns, " turn(s) remaining")

# method to end player and enemy turns
func end_player_turn():
	if is_paused or not player_turn:
		return

	player_turn = false
	print("Player turn ended")

	enemy_turn()

# ----------------------------
# Enemy turn routing
# ----------------------------
func enemy_turn():
	print("Enemy's turn")

	if enemy.is_boss:
		_boss_turn()
	else:
		_regular_enemy_turn()

# ----------------------------
# Regular enemy turn (unchanged random logic)
# ----------------------------
func _regular_enemy_turn():
	if enemy.enemy_deck.is_empty():
		enemy.shuffle_deck()

	var enemy_card = randi_range(1, enemy.enemy_deck.size()) - 1
	print(enemy.enemy_deck.size())
	enemy_play_card(enemy.enemy_deck[enemy_card])

	#With 25% probability, the enemy will play 2 cards in one turn.
	if randf() < 0.25 and !enemy.enemy_deck.is_empty():
		enemy_play_card(enemy.enemy_deck[randi_range(1, enemy.enemy_deck.size()) - 1])

	end_enemy_turn()

# ----------------------------
# Boss turn — executes next move in the active phase cycle
# ----------------------------
func _boss_turn():
	var move = enemy.get_next_boss_move()
	print("Boss [Phase ", enemy.boss_phase, "] — ", move.get("desc", move["type"]))
	_execute_boss_move(move)
	end_enemy_turn()

func _execute_boss_move(move: Dictionary) -> void:
	match move["type"]:
		"gain_block":
			enemy.gain_block(move["value"])

		"heal":
			enemy.heal(move["value"])

		"gain_strength":
			enemy.damage_bonus += move["value"]
			print("Boss gains +", move["value"], " strength. Total bonus: ", enemy.damage_bonus)

		"weaken":
			player.weakened_turns += move["value"]
			print("Player weakened for ", player.weakened_turns, " turn(s)")

		"draw_penalty":
			player.draw_penalty_turns += move["value"]
			print("Player draw reduced for ", player.draw_penalty_turns, " turn(s)")

		"deal_damage":
			var dmg = move["value"] + enemy.damage_bonus
			player.take_damage(dmg)

		"heavy_damage":
			# Heavy damage counts as a legendary move — ignores a fixed amount of block
			var dmg = move["value"] + enemy.damage_bonus
			player.take_damage(dmg)

		"drain":
			# Deals damage and heals the boss by the same amount
			var dmg = move["value"] + enemy.damage_bonus
			var actual_damage = max(0, dmg - player.block)
			player.take_damage(dmg)
			enemy.heal(actual_damage)

		"targeted_debuff":
			_execute_targeted_debuff()

		_:
			print("Unknown boss move type: ", move["type"])

func _execute_targeted_debuff() -> void:
	match enemy.boss_archetype:
		"attack_heavy":
			# Counter an aggressive player: reduce their damage output
			player.weakened_turns += 3
			print("Boss targets offense — player weakened for 3 extra turn(s)")
		"defense_heavy":
			# Counter a passive player: disrupt their card flow
			player.draw_penalty_turns += 3
			print("Boss disrupts defense — player draw reduced for 3 extra turn(s)")
		_:  # "balanced" or "none" (first run)
			# Split debuff — moderate pressure on both axes
			player.weakened_turns += 2
			player.draw_penalty_turns += 2
			print("Boss applies split debuff — weaken 2, draw penalty 2")

# ----------------------------
# Signal handler for phase transition
# Connect more UI/VFX listeners to enemy.boss_phase_changed in the future.
# ----------------------------
func _on_boss_phase_changed(new_phase: int) -> void:
	print("=== BOSS ENTERED PHASE ", new_phase, " ===")
	# TODO: trigger UI flash, music change, screen shake, etc.

#Enemy playing a card function (used by regular enemies only)
func enemy_play_card(enemy_card):
	if not enemy.enemy_deck.is_empty():
		if enemy_card.type == "Damage":
			var damage = enemy_card.damage
			player.take_damage(damage - player.block)
		elif enemy_card.type == "Utility":
			if enemy_card.block > 0:
				enemy.gain_block(enemy_card.block)
				update_block_label()

			if enemy_card.heal > 0:
				enemy.heal(enemy_card.heal)

		enemy.enemy_deck.erase(enemy_card)
		enemy.enemy_discard.append(enemy_card)
		print("Played and moved " + enemy_card.name + " to enemy's discard pile")


func end_enemy_turn():
	start_player_turn()

# Drawing cards and class passives:
#draws cards from the draw pile at the start of every turn
# ----------------------------
# Draw cards function
# ----------------------------
func draw_cards(count = null, from_effect = false):
	if count == null:
		count = GameManager.CardsDrawnPerTurn
		# Draw penalty only applies to the regular turn-start draw, not effect draws
		if enemy != null and enemy.is_boss and player.draw_penalty_turns > 0:
			count = max(1, count - 1)

	for i in range(count):
		# Reshuffle if draw pile empty
		if $"DrawPile".card_array.size() == 0:
			reshuffle_discard_into_draw()
		if $"DrawPile".card_array.size() == 0:
			return

		var current_card = $"DrawPile".card_array.back()

		if $"HandContainer".card_array.size() < max_hand:
			$"DrawPile".remove_card(current_card)
			$"HandContainer".add_card(current_card)
			current_card.combat = self
			current_card.update_debug_label()

			# ----------------------
			# Mage passive: buffs on drawn cards from effects
			# ----------------------
			if from_effect and GameManager.current_class == GameManager.PlayerClass.HEXTECHMAGE:
				player.spell_power += 1
				print("Mage gains +1 spell power! Current:", player.spell_power)


# ----------------------------
# Play card function
# ----------------------------
func play_card(card, target):
	if is_paused or not player_turn:
		return

	if player_mana <= 0:
		print("Not enough mana")
		return

	player_mana -= 1
	update_mana_label()

	# ----------------------
	# Apply card effects
	# ----------------------
	if card.card_data.type == "Damage":
		var damage = card.card_data.damage

		# Weakened status: player deals 50% damage
		if player.weakened_turns > 0:
			damage = max(1, damage / 2)

		# Mecha passive: bonus damage based on block
		if GameManager.current_class == GameManager.PlayerClass.GUNDAM:
			damage += int(player.block * 0.5)  # 50% of current block as bonus damage

		target.take_damage(damage)

		# Alien passive: heal when dealing damage
		if GameManager.current_class == GameManager.PlayerClass.CREATURE:
			player.heal(damage)
			print("Alien heals for", damage)

		# Mage passive damage
		if GameManager.current_class == GameManager.PlayerClass.HEXTECHMAGE:
			damage = (damage + player.spell_power)
	elif card.card_data.type == "Utility":
		if card.card_data.block > 0:
			player.gain_block(card.card_data.block)
			update_block_label()

		if card.card_data.heal > 0:
			player.heal(card.card_data.heal)

		# Draw cards if card has draw_amount
		if card.card_data.draw > 0:
			# Cards drawn from this effect trigger Mage passive
			draw_cards(card.card_data.draw, true)

	# Move played card to discard
	move_to_discard(card)

	# Check victory conditions
	check_victory()

func reshuffle_discard_into_draw():
	while $"DiscardPile".card_array.size() > 0:
		var card = $"DiscardPile".card_array.back()
		$"DiscardPile".remove_card(card)
		$"DrawPile".add_card(card)

	$"DrawPile".card_array.shuffle()

func move_to_discard(card):
	$"HandContainer".remove_card(card)
	$"DiscardPile".add_card(card)


func check_victory():
	if enemy.hp <= 0:
		print("Victory!")
		_on_combat_victory()

	if GameManager.PlayerHP <= 0:
		print("Defeat!")
		_on_combat_defeat()

func _on_combat_victory() -> void:
	# Save the current deck so the boss can adapt to it next run
	SaveManager.save_run_deck(_get_current_deck_ids())

	if GameManager.is_boss_fight:
		# Boss defeated — roll credits
		SceneManager.change_scene("res://scenes/credits.tscn")
	else:
		GameManager.encounter_complete()

func _on_combat_defeat() -> void:
	# Save deck even on defeat so the boss still adapts
	SaveManager.save_run_deck(_get_current_deck_ids())
	SceneManager.change_scene("res://scenes/main_menu.tscn")

# Returns the 0-based card index for every card in the player's current deck
func _get_current_deck_ids() -> Array:
	var ids = []
	for card in GameManager.Deck.full_deck:
		ids.append(card.id)
	return ids

# ----------------------------
# Analyse the previous run's deck and return the player archetype string.
# Called once at boss initialisation so the result can be shared everywhere.
# ----------------------------
func _compute_player_archetype() -> String:
	if not SaveManager.has_previous_run():
		return "none"

	var previous_deck = SaveManager.load_previous_deck()
	var card_data_json = JsonLoader.load_cards()
	var damage_count = 0
	var defense_count = 0

	for card_id in previous_deck:
		var card_info = card_data_json["cards"][card_id]
		if card_info.get("type", "Utility") == "Damage":
			damage_count += 1
		else:
			defense_count += 1

	print("Archetype analysis — damage: ", damage_count, " | defense: ", defense_count)

	if damage_count > defense_count:
		return "attack_heavy"
	elif defense_count > damage_count:
		return "defense_heavy"
	else:
		return "balanced"

# ----------------------------
# Boss adaptive deck generation
# Reads the previous run's archetype and counters the player's strategy.
# ----------------------------
func _get_boss_cards_for_archetype(archetype: String) -> Array:
	# Card index sets (0-based array indices into cards.json)
	# Attack: 0=Laser Shot(6dmg), 3=Fireball(7dmg), 12=Slash(6dmg), 6=Bite(5dmg)
	# Defense: 1=Shield Up(5blk), 7=Hide(4blk), 2=Repair(3heal), 4=Heal Pulse(3heal)
	match archetype:
		"attack_heavy":
			# Player was offence-heavy → boss loads up on shields and heals
			print("Boss deck: defense-heavy counter")
			return [1, 1, 1, 7, 7, 7, 2, 2, 2, 4, 4, 4, 0, 3, 12, 6]
		"defense_heavy":
			# Player was passive → boss goes full aggression
			print("Boss deck: attack-heavy counter")
			return [0, 0, 0, 3, 3, 3, 12, 12, 12, 6, 6, 6, 1, 7, 2, 4]
		_:  # "balanced" or "none" (first run)
			print("Boss deck: balanced (50/50)")
			return [0, 0, 3, 3, 12, 12, 6, 6, 1, 1, 7, 7, 2, 2, 4, 4]

# ----------------------------
# Input — Space ends turn, Escape toggles pause
# _unhandled_input fires after all GUI nodes have had a chance to consume the event,
# so it works regardless of which node has keyboard focus (fixes first-turn issue).
# ----------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event.is_action_pressed("ui_accept") and not is_paused:
		end_player_turn()

# ----------------------------
# Pause
# ----------------------------
func _toggle_pause() -> void:
	is_paused = not is_paused
	if _pause_overlay:
		_pause_overlay.visible = is_paused

func _build_pause_menu() -> void:
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.layer = 10          # render above everything in the combat scene
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	# Semi-transparent backdrop
	var backdrop = ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1920, 1080)
	backdrop.color = Color(0, 0, 0, 0.65)
	_pause_overlay.add_child(backdrop)

	# Centred vbox
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(760, 340)
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_pause_overlay.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var resume_btn = Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(400, 70)
	resume_btn.add_theme_font_size_override("font_size", 32)
	resume_btn.pressed.connect(_toggle_pause)
	vbox.add_child(resume_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.custom_minimum_size = Vector2(400, 70)
	quit_btn.add_theme_font_size_override("font_size", 32)
	quit_btn.pressed.connect(_quit_to_menu_from_pause)
	vbox.add_child(quit_btn)

func _quit_to_menu_from_pause() -> void:
	is_paused = false
	GameManager.reset_run()
	SceneManager.change_scene("res://scenes/main_menu.tscn")

# ----------------------------
# Boss background — pulsing purple ↔ near-black animation
# ----------------------------
func _setup_boss_background() -> void:
	$"BackgroundTexture".visible = false

	_boss_bg = ColorRect.new()
	_boss_bg.position = Vector2.ZERO
	_boss_bg.size = Vector2(1920, 1080)
	_boss_bg.color = Color(0.35, 0.0, 0.55)
	add_child(_boss_bg)
	move_child(_boss_bg, 0)   # push behind all other nodes

	var tween = create_tween().set_loops()
	tween.tween_property(_boss_bg, "color", Color(0.07, 0.0, 0.13), 3.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_boss_bg, "color", Color(0.35, 0.0, 0.55), 3.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# updates mana in screen
func update_mana_label():
	$ManaLabel.text = "Mana " + str(player_mana)
func update_block_label():
	$BlockValue.text = "Block" + str(player.block)

#end turn
func _on_end_turn_button_pressed() -> void:
	end_player_turn()
