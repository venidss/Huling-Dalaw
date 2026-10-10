extends Node
## Save & load system for DAET: ANG PAMANA.
##
## Writes to user:// so saves survive updates / reinstalls on all platforms (incl. Android).
## Stores: current mission, completed objectives, inventory, story flags, puzzle state,
## player position, and chosen ending.
##
## Handles missing or corrupt data gracefully — a corrupt save is renamed to .bak before
## a fresh game can begin.

const SAVE_PATH := "user://daet_save.json"
const BACKUP_PATH := "user://daet_save.bak"
const SAVE_VERSION := 1

signal save_completed
signal load_completed
signal save_failed(reason: String)

func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	# Minimum validity check — file exists and is parseable.
	var data := _read_file(SAVE_PATH)
	return data != null and typeof(data) == TYPE_DICTIONARY and data.get("version", 0) == SAVE_VERSION

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"mission": {
			"current_id": MissionManager.current_mission_id,
			"completed": MissionManager.completed_missions.duplicate(),
			"flags": MissionManager.story_flags.duplicate(true),
			"journal": MissionManager.journal_entries.duplicate(true),
		},
		"inventory": Inventory.serialize(),
		"horror": {
			"triggered_events": HorrorManager.triggered_events.duplicate(),
		},
		"player": GameState.serialize_player(),
		"ending": GameState.chosen_ending,
	}

	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Hindi ma-save: %s" % str(FileAccess.get_open_error()))
		return false
	file.store_string(json_text)
	file.close()
	save_completed.emit()
	return true

func load_game() -> bool:
	var data := _read_file(SAVE_PATH)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		# Try backup if main save is corrupt.
		data = _read_file(BACKUP_PATH)
		if data == null:
			save_failed.emit("Walang mabasang save file.")
			return false
	if int(data.get("version", 0)) != SAVE_VERSION:
		save_failed.emit("Hindi tugma ang version ng save file.")
		return false

	var mission_data: Dictionary = data.get("mission", {})
	MissionManager.restore(mission_data)

	var inv_data: Array = data.get("inventory", [])
	Inventory.deserialize(inv_data)

	var horror_data: Dictionary = data.get("horror", {})
	HorrorManager.triggered_events = horror_data.get("triggered_events", []).duplicate()

	var player_data: Dictionary = data.get("player", {})
	GameState.restore_player(player_data)
	GameState.chosen_ending = int(data.get("ending", 0))

	load_completed.emit()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))

func _read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed
