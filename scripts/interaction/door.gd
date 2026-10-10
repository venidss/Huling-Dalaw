extends StaticBody3D
## Door interactable. Supports open/closed state, locked by inventory key, mission-gated
## locks that require a specific mission to be active, and a one-way "slam" state used
## by horror events.
class_name DoorInteractable

@export var label: String = "Buksan ang pinto"
@export var label_closed: String = "Buksan ang pinto"
@export var label_open: String = "Isara ang pinto"
@export var label_locked: String = "Nakakandado"
@export var label_locked_en: String = "Locked"
@export var required_key: String = ""      # inventory item id required to unlock
@export var required_mission: String = ""   # mission id that must be current or past to allow opening
@export var auto_lock_after_open: bool = false
@export var opens_toward: Vector3 = Vector3(0, 1, 0)  # axis to rotate around
@export var open_angle_degrees: float = 85.0
@export var open_time: float = 0.6

var is_open: bool = false
var is_locked: bool = false
var _hinge: Node3D

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2 | 1  # interactable AND world so bullets/rays treat as wall
	collision_mask = 0
	# Defer so programmatically-added children (e.g., "Hinge") are present.
	call_deferred("_bind_hinge")
	# Lock if we need a key the player doesn't have yet.
	if required_key != "":
		is_locked = not Inventory.has_item(required_key)

func _bind_hinge() -> void:
	_hinge = get_node_or_null("Hinge")
	if _hinge == null:
		_hinge = self

func get_interact_label() -> String:
	if is_locked:
		return "%s / %s" % [label_locked, label_locked_en] if Settings.show_english_subtitles else label_locked
	return label_open if is_open else label_closed

func can_interact(_player: Node) -> bool:
	return true

func interact(_player: Node) -> void:
	if is_locked:
		# Try to unlock with the required key.
		if required_key != "" and Inventory.has_item(required_key):
			is_locked = false
			AudioManager.play_sfx_3d("key_unlock.wav", self)
			MissionManager.add_journal_entry("Nagbukas ang kandado.")
			# Fall through to open the door immediately for a satisfying moment.
		else:
			AudioManager.play_sfx_3d("door_locked.wav", self)
			return
	if required_mission != "" and not MissionManager.is_at_or_past(required_mission):
		# Door won't open yet — the story hasn't reached this moment.
		AudioManager.play_sfx_3d("door_locked.wav", self)
		return
	toggle()

func toggle() -> void:
	is_open = not is_open
	var target_angle := deg_to_rad(open_angle_degrees) if is_open else 0.0
	var axis := opens_toward.normalized() if opens_toward.length() > 0.01 else Vector3.UP
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation", axis * target_angle, open_time)
	AudioManager.play_sfx_3d("door_open.wav" if is_open else "door_close.wav", self)
	if is_open and auto_lock_after_open:
		await get_tree().create_timer(1.5).timeout
		is_locked = true

## Called by horror events to slam the door shut with extra oomph.
func slam_shut() -> void:
	is_open = false
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation", Vector3.ZERO, 0.15)
	AudioManager.play_sfx_3d("door_slam.wav", self, 2.0)
	HorrorManager.shake_camera(0.25, 0.3)

func force_open() -> void:
	is_open = true
	var axis := opens_toward.normalized() if opens_toward.length() > 0.01 else Vector3.UP
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation", axis * deg_to_rad(open_angle_degrees), 1.4)
	AudioManager.play_sfx_3d("door_creak.wav", self)
