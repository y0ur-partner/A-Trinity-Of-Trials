extends Node2D

#currently the sprites used for the enemies are smaller, so the sprite scale is increased. This as well as all
#child nodes will need to be adjusted once we have the final sprites

#Are we really loading the entire card deck into the contents of Enemy? Yes, yes we are.
var card_data = JsonLoader.load_cards()

var max_hp = 100
var hp = 70
var block = 0
var card_ids: Array = Array() #simply used to store the card ids until they can be converted into proper cards then put into enemy_deck
var enemy_deck: Array = []
var enemy_discard: Array = []

# ----------------------------
# Boss phase system
# ----------------------------

# Fired when HP crosses 50% for the first time. UI can connect to this.
signal boss_phase_changed(new_phase: int)

var is_boss: bool = false

# Current phase: 1 = defensive (100%→50% HP), 2 = aggressive (<50% HP)
var boss_phase: int = 1

# Separate move pointers so each phase remembers where it was.
# Phase 2 pointer resets to 0 on transition.
var phase1_index: int = 0
var phase2_index: int = 0

# Accumulated damage bonus from gain_strength moves — never resets.
var damage_bonus: int = 0

# Set by combat.gd from the previous run's deck analysis.
# "none" | "attack_heavy" | "defense_heavy" | "balanced"
var boss_archetype: String = "none"

# ----------------------------
# Phase 1 move cycles
# ----------------------------

# Used when boss_archetype == "none" (first ever run).
# Per spec: can only buff itself or apply a generic weaken — no damage.
const PHASE1_FIRST_RUN: Array = [
	{"type": "gain_block",   "value": 12, "desc": "The Lich raises a barrier"},
	{"type": "heal",         "value": 15, "desc": "The Lich siphons ambient life"},
	{"type": "gain_block",   "value": 10, "desc": "The Lich hardens its form"},
	{"type": "weaken",       "value": 1,  "desc": "The Lich enfeebles your strikes"},
	{"type": "heal",         "value": 12, "desc": "The Lich draws on dark energy"},
	{"type": "gain_block",   "value": 14, "desc": "The Lich fortifies itself"},
]

# Used when a previous deck snapshot exists.
# Adds draw_penalty and gain_strength as minor targeted disruptions.
const PHASE1_WITH_SNAPSHOT: Array = [
	{"type": "gain_block",   "value": 12, "desc": "The Lich raises a barrier"},
	{"type": "heal",         "value": 15, "desc": "The Lich siphons your vitality"},
	{"type": "draw_penalty", "value": 2,  "desc": "The Lich clouds your mind"},
	{"type": "gain_block",   "value": 10, "desc": "The Lich hardens its form"},
	{"type": "gain_strength","value": 4,  "desc": "The Lich empowers itself"},
	{"type": "weaken",       "value": 2,  "desc": "The Lich enfeebles your strikes"},
]

# ----------------------------
# Phase 2 move cycle (shared regardless of archetype)
# targeted_debuff resolves at execution time based on boss_archetype.
# ----------------------------
const PHASE2_CYCLE: Array = [
	{"type": "heavy_damage",     "value": 18, "desc": "The Lich unleashes a death bolt"},
	{"type": "targeted_debuff",  "value": 0,  "desc": "The Lich reads your soul"},
	{"type": "deal_damage",      "value": 12, "desc": "The Lich strikes with bone shards"},
	{"type": "gain_strength",    "value": 6,  "desc": "The Lich surges with dark power"},
	{"type": "drain",            "value": 10, "desc": "The Lich drains your vitality"},
	{"type": "heavy_damage",     "value": 22, "desc": "The Lich delivers a killing blow"},
]

func _ready() -> void:
	init_health_bar()


func init_health_bar():
	$"EnemyDataUI/HealthBar".max_value = max_hp
	update_health_bar()

#call this whenever health is changed
func update_health_bar():
	$"EnemyDataUI/HealthBar".value = hp

func take_damage(amount):
	var remaining_damage = amount - block

	block = max(0, block - amount)

	if remaining_damage > 0:
		hp -= remaining_damage

	update_health_bar()

	# Check boss phase transition after every hit
	if is_boss and boss_phase == 1:
		_check_phase_transition()

	if hp <= 0:
		die()

func _check_phase_transition() -> void:
	if hp <= max_hp * 0.5:
		boss_phase = 2
		phase2_index = 0   # always restart phase 2 from the top
		emit_signal("boss_phase_changed", 2)
		print("BOSS PHASE TRANSITION → Phase 2 (HP: ", hp, " / ", max_hp, ")")

# Returns the next move from the active phase cycle and advances the pointer.
func get_next_boss_move() -> Dictionary:
	if boss_phase == 1:
		var cycle = PHASE1_FIRST_RUN if boss_archetype == "none" else PHASE1_WITH_SNAPSHOT
		var move = cycle[phase1_index % cycle.size()]
		phase1_index = (phase1_index + 1) % cycle.size()
		return move
	else:
		var move = PHASE2_CYCLE[phase2_index % PHASE2_CYCLE.size()]
		phase2_index = (phase2_index + 1) % PHASE2_CYCLE.size()
		return move

#Grabs the card IDs assigned to the enemy and turns them into a proper "deck"
func parse_card_ids():
	for i in len(card_ids):
		print("Parsing card ID " + str(card_ids[i]) + " of enemy...")

		#NOTE: This is essentially a mini-version of the function found in deck.gd.
		#Should the deck.gd card creation function be made global to clear up space?

		var card_data_resource = load("res://code/card_data.gd")

		var card = card_data_resource.new()
		card.type = card_data["cards"][card_ids[i]].get("type", "Utility")
		card.damage = card_data["cards"][card_ids[i]].get("damage", 0)
		card.block = card_data["cards"][card_ids[i]].get("block", 0)
		card.heal = card_data["cards"][card_ids[i]].get("heal", 0)
		card.name = card_data["cards"][card_ids[i]].get("name", "Unnamed Card")

		enemy_deck.append(card)

	print("placeholder")

#shuffles discard pile, and moves it back into the enemy deck
func shuffle_deck() -> void:
	enemy_discard.shuffle()
	enemy_deck.append_array(enemy_discard)
	enemy_discard.clear()


func gain_block(amount: int) -> void:
	block += amount
	print("Enemy gained ", amount, " block. Total block: ", block)

func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)
	print("Enemy healed ", amount, " HP. Total HP: ", hp)
	update_health_bar()

func die():
	print("Enemy defeated!")
	queue_free()
