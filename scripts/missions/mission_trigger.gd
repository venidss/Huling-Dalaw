extends Area3D
## Mission trigger area. When the player enters, optionally completes a mission or sets
## a story flag. Used for "walk to location" style objectives.
##
## Also re-checks conditions on mission changes so a trigger whose conditions came true
## while the player was already standing inside fires correctly.
class_name MissionTrigger

@export var completes_mission: String = ""
@export var starts_mission: String = ""
@export var sets_flag: String = ""
@export var requires_mission: String = ""   # only fires when this mission is current/past
@export var one_shot: bool = true
@export var play_sfx: String = ""
@export var start_dialogue: String = ""
@export var trigger_horror: String = ""

var _used: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	MissionManager.mission_changed.connect(_on_mission_changed)
	MissionManager.flag_set.connect(_on_flag_set)

func _on_mission_changed(_m: Dictionary) -> void:
	_recheck()

func _on_flag_set(_f: String, _v: Variant) -> void:
	_recheck()

func _recheck() -> void:
	if one_shot and _used:
		return
	# If the player is standing inside this area and conditions are now met, fire.
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			_try_fire(b)
			return

func _on_body_entered(body: Node3D) -> void:
	if one_shot and _used:
		return
	if not body.is_in_group("player"):
		return
	_try_fire(body)

func _try_fire(body: Node3D) -> void:
	if requires_mission != "" and not MissionManager.is_at_or_past(requires_mission):
		return
	_used = true
	if play_sfx != "":
		AudioManager.play_sfx(play_sfx)
	if sets_flag != "":
		MissionManager.set_flag(sets_flag, true)
	if completes_mission != "":
		MissionManager.complete(completes_mission)
	if starts_mission != "":
		MissionManager.start_mission(starts_mission)
	if trigger_horror != "":
		HorrorManager.trigger_event(trigger_horror)
	if start_dialogue != "":
		DialogueManager.start(start_dialogue)
