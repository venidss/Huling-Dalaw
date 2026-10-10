extends StaticBody3D
## 4-digit code lock interactable (used for the diary puzzle locked box).
## When opened, spawns one or more items and optionally completes a mission.
class_name CodeLock

@export var code: String = "1973"
@export var hint_tagalog: String = "Isang petsang nawala sa kasaysayan."
@export var hint_english: String = "A date buried in the family's history."
@export var spawn_items: Array[String] = []
@export var completes_mission: String = ""
@export var sets_flag: String = ""
@export var requires_item: String = ""     # must have this item in inventory to use
@export var one_shot: bool = true

var _unlocked: bool = false
var _attempted_code: String = ""

signal unlocked
signal attempt_failed

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0

func get_interact_label() -> String:
	if _unlocked:
		if spawn_items.size() > 0:
			return "Kunin ang laman"
		return "Nabuksan na"
	if requires_item != "" and not Inventory.has_item(requires_item):
		return "May kailangan pa"
	if Settings.show_english_subtitles:
		return "Ilagay ang code / Enter code"
	return "Ilagay ang code"

func interact(player: Node) -> void:
	if _unlocked:
		_collect(player)
		return
	if requires_item != "" and not Inventory.has_item(requires_item):
		AudioManager.play_sfx_3d("switch_broken.wav", self)
		return
	# Open the code lock UI.
	for ui in get_tree().get_nodes_in_group("code_lock_ui"):
		if ui.has_method("open_for"):
			ui.open_for(self, hint_tagalog, hint_english)
	if player.has_method("set_can_move"):
		player.set_can_move(false)

func try_code(entered: String) -> bool:
	_attempted_code = entered
	if entered == code:
		_unlock()
		return true
	AudioManager.play_sfx_3d("switch_broken.wav", self)
	attempt_failed.emit()
	return false

func _unlock() -> void:
	_unlocked = true
	AudioManager.play_sfx_3d("key_unlock.wav", self)
	if sets_flag != "":
		MissionManager.set_flag(sets_flag, true)
	if completes_mission != "":
		MissionManager.complete(completes_mission)
	unlocked.emit()

func _collect(_player: Node) -> void:
	for item_id in spawn_items:
		Inventory.add_item(item_id)
	AudioManager.play_sfx("item_pickup.wav")
	if one_shot:
		queue_free()
