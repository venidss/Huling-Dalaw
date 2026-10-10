extends Node3D
## Base class for horror events in DAET: ANG PAMANA.
##
## Each event registers itself with HorrorManager under a unique id. HorrorManager handles
## one-shot/cooldown logic — subclasses only need to implement trigger().
class_name HorrorEvent

@export var event_id: String = ""
@export var one_shot: bool = true
@export var cooldown: float = 0.0
@export var required_mission: String = ""   # mission that must be reached for this to arm
@export var required_flag: String = ""

func _ready() -> void:
	if event_id == "":
		event_id = name
	HorrorManager.register_event(event_id, self)

func _exit_tree() -> void:
	HorrorManager.unregister_event(event_id)

func trigger() -> void:
	if required_mission != "" and not MissionManager.is_at_or_past(required_mission):
		return
	if required_flag != "" and not MissionManager.has_flag(required_flag):
		return
	_run()

## Subclasses override.
func _run() -> void:
	pass
