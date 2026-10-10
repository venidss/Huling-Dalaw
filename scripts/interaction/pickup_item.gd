extends StaticBody3D
## Pickup item interactable — adds an inventory item and optionally advances a mission.
class_name PickupItem

@export var item_id: String = ""
@export var custom_label: String = ""          # overrides inventory name if non-empty
@export var completes_mission: String = ""      # mission id to mark complete when picked up
@export var starts_dialogue: String = ""        # dialogue id to play on pickup
@export var story_flag_to_set: String = ""
@export var disappear_on_pickup: bool = true
@export var bob_offset: float = 0.0             # randomized bob so clustered items look alive

var _taken: bool = false
var _mesh: MeshInstance3D
var _base_y: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0
	_base_y = position.y
	bob_offset = randf() * TAU
	call_deferred("_bind_mesh")

func _bind_mesh() -> void:
	_mesh = get_node_or_null("Mesh") as MeshInstance3D

func _process(delta: float) -> void:
	if _mesh == null or _taken:
		return
	_mesh.position.y = sin(Time.get_ticks_msec() / 1000.0 * 2.0 + bob_offset) * 0.04
	_mesh.rotation.y += delta * 0.6

func get_interact_label() -> String:
	if custom_label != "":
		return custom_label
	var def := Inventory.get_definition(item_id)
	if def.is_empty():
		return "Kunin"
	var tag := "Kunin: %s" % String(def.get("name", ""))
	if Settings.show_english_subtitles:
		tag += " / Pick up: %s" % String(def.get("name_en", ""))
	return tag

func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	if item_id != "":
		Inventory.add_item(item_id)
	AudioManager.play_sfx("item_pickup.wav", -2.0, randf_range(0.95, 1.05))
	if story_flag_to_set != "":
		MissionManager.set_flag(story_flag_to_set, true)
	if completes_mission != "":
		MissionManager.complete(completes_mission)
	if starts_dialogue != "":
		DialogueManager.start(starts_dialogue)
	if disappear_on_pickup:
		queue_free()
