extends StaticBody3D
## Interactable that starts a dialogue when examined.
## Can gate behind a required mission to prevent out-of-order conversations.
class_name DialogueTrigger

@export var dialogue_id: String = ""
@export var trigger_label: String = "Kausapin"
@export var trigger_label_en: String = "Talk"
@export var required_mission: String = ""
@export var one_shot: bool = false

var _played: bool = false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0

func get_interact_label() -> String:
	# Hide the prompt entirely when the player isn't allowed to talk yet. Returning ""
	# tells the HUD to show no interact text, so the NPC still exists in the world but
	# doesn't invite interaction.
	if required_mission != "" and not MissionManager.is_at_or_past(required_mission):
		return ""
	if one_shot and _played:
		return ""
	if Settings.show_english_subtitles:
		return "%s / %s" % [trigger_label, trigger_label_en]
	return trigger_label

func can_interact(_player: Node) -> bool:
	if one_shot and _played:
		return false
	if required_mission != "" and not MissionManager.is_at_or_past(required_mission):
		return false
	return true

func interact(_player: Node) -> void:
	if not can_interact(_player):
		return
	_played = true
	if dialogue_id != "":
		DialogueManager.start(dialogue_id)
