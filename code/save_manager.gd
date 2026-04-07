extends Node

const SAVE_FILE = "user://run_save.json"

# Saves the player's deck (as array of card indices) after a run ends
func save_run_deck(card_ids: Array) -> void:
	var data = {"deck": card_ids}
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("SaveManager: Saved deck with ", card_ids.size(), " cards.")
	else:
		push_error("SaveManager: Could not write save file.")

# Returns the card indices from the previous run, or [] if none
func load_previous_deck() -> Array:
	if not FileAccess.file_exists(SAVE_FILE):
		return []
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		return []
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if data == null or not data.has("deck"):
		return []
	return data["deck"]

# True if a previous run's deck has been saved
func has_previous_run() -> bool:
	return FileAccess.file_exists(SAVE_FILE) and load_previous_deck().size() > 0
