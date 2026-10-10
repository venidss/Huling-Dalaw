extends Node
## Horror event manager for DAET: ANG PAMANA.
##
## Owns registration + firing of horror events. Each scare registers itself with a unique id;
## code or triggers call trigger_event(id). The manager enforces one-shot semantics for
## story events and cooldowns for repeating ambient scares.
##
## Scares *gameplay-respond* to the current mission and story flags — they are not random
## noise. HorrorEvent subclasses implement the actual visual/audio behavior.

signal event_triggered(id: String)
signal screen_flash(color: Color, duration: float)
signal camera_shake(strength: float, duration: float)

var _events: Dictionary = {}       # id -> HorrorEvent node reference
var triggered_events: Array = []    # ids of events that have fired (persisted)
var _cooldowns: Dictionary = {}     # id -> absolute time it can trigger again

func register_event(id: String, event: Node) -> void:
	_events[id] = event

func unregister_event(id: String) -> void:
	_events.erase(id)

func is_triggered(id: String) -> bool:
	return triggered_events.has(id)

func trigger_event(id: String) -> bool:
	# Returns true if the event actually fired.
	if not _events.has(id):
		return false
	var node: Node = _events[id]
	if not is_instance_valid(node):
		_events.erase(id)
		return false

	var is_once: bool = node.get("one_shot") if "one_shot" in node else true
	if is_once and triggered_events.has(id):
		return false

	var cooldown: float = node.get("cooldown") if "cooldown" in node else 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if _cooldowns.has(id) and now < _cooldowns[id]:
		return false
	if cooldown > 0.0:
		_cooldowns[id] = now + cooldown

	if is_once:
		triggered_events.append(id)

	event_triggered.emit(id)
	if node.has_method("trigger"):
		node.trigger()
	return true

## For code that wants to force a flash — HUD listens via screen_flash signal.
func flash_screen(color: Color = Color(0, 0, 0, 0.6), duration: float = 0.25) -> void:
	if Settings.reduce_motion:
		color.a *= 0.4
		duration *= 0.6
	screen_flash.emit(color, duration)

func shake_camera(strength: float = 0.3, duration: float = 0.4) -> void:
	if Settings.reduce_motion:
		strength *= 0.3
	camera_shake.emit(strength, duration)
