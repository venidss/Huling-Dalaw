extends "res://scripts/horror/horror_event.gd"
## Door scare — makes a specific door creak open or slam shut on command.
class_name DoorScare

@export var door_path: NodePath
@export_enum("creak_open", "slam_shut") var mode: int = 0
@export var play_breath: bool = false

func _run() -> void:
	var door := get_node_or_null(door_path)
	if door == null:
		return
	match mode:
		0:
			if door.has_method("force_open"):
				door.force_open()
		1:
			if door.has_method("slam_shut"):
				door.slam_shut()
	if play_breath:
		AudioManager.play_sfx_3d("breath.wav", door, -4.0)
