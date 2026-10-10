extends StaticBody3D
## Light-switch interactable. Toggles a list of light nodes (by NodePath relative to this
## node's parent chain). Can be gated by a required inventory item (e.g. a fuse). Used by
## both ordinary room switches and the fuse-box electrical puzzle.
class_name LightSwitch

@export var light_paths: Array[NodePath] = []
@export var start_on: bool = true
@export var required_item: String = ""        # if set, must be in inventory to flip the switch
@export var required_flag: String = ""        # if set, a story flag that must be true to flip
@export var consumes_item: bool = false       # if true, remove the required item after use
@export var completes_mission: String = ""    # mission to complete on successful flip
@export var story_flag_to_set: String = ""

var is_on: bool = true

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0
	is_on = start_on
	_apply()

func get_interact_label() -> String:
	if required_item != "" and not Inventory.has_item(required_item):
		return "Sira ang switch"
	if required_flag != "" and not MissionManager.has_flag(required_flag):
		return "Sira ang switch"
	return "Patayin ang ilaw" if is_on else "Buksan ang ilaw"

func interact(_player: Node) -> void:
	if required_item != "" and not Inventory.has_item(required_item):
		AudioManager.play_sfx_3d("switch_broken.wav", self)
		MissionManager.add_journal_entry("Kailangan ng isang bagay para gumana ang switch.")
		return
	if required_flag != "" and not MissionManager.has_flag(required_flag):
		AudioManager.play_sfx_3d("switch_broken.wav", self)
		MissionManager.add_journal_entry("May nasira sa daloy ng kuryente.")
		return
	is_on = not is_on
	AudioManager.play_sfx_3d("switch_flip.wav", self)
	_apply()
	if is_on:
		if consumes_item and required_item != "":
			Inventory.remove_item(required_item)
		if story_flag_to_set != "":
			MissionManager.set_flag(story_flag_to_set, true)
		if completes_mission != "":
			MissionManager.complete(completes_mission)

func _apply() -> void:
	for p in light_paths:
		var light := get_node_or_null(p)
		if light is Light3D:
			light.visible = is_on
