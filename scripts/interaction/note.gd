extends StaticBody3D
## Readable note / letter / document interactable.
## When interacted with, pauses movement and shows the note content on screen until dismissed.
class_name ReadableNote

@export_multiline var tagalog_text: String = ""
@export_multiline var english_text: String = ""
@export var title: String = "Lumang Sulat"
@export var completes_mission: String = ""
@export var story_flag_to_set: String = ""
@export var adds_item: String = ""          # optional — e.g. picking up a letter adds "letter_lolo"

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0

func get_interact_label() -> String:
	if Settings.show_english_subtitles:
		return "Basahin / Read"
	return "Basahin"

func interact(player: Node) -> void:
	# The HUD listens for this via group "note_readers" — any UI control that implements
	# .show_note(title, tagalog, english) and .hide_note() will react.
	for ui in get_tree().get_nodes_in_group("note_readers"):
		if ui.has_method("show_note"):
			ui.show_note(title, tagalog_text, english_text)
	if "set_can_move" in player:
		player.set_can_move(false)
	AudioManager.play_sfx("paper_rustle.wav", -4.0)
	if adds_item != "":
		Inventory.add_item(adds_item)
	if story_flag_to_set != "":
		MissionManager.set_flag(story_flag_to_set, true)
	if completes_mission != "":
		MissionManager.complete(completes_mission)
