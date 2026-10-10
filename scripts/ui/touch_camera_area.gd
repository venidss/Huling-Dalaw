extends Control
## Touch camera-look area for the right side of the screen.
## Converts drag deltas into yaw/pitch inputs for the player.
class_name TouchCameraArea

signal drag_delta(delta: Vector2)

var _active_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_index == -1:
			_active_index = event.index
			accept_event()
		elif not event.pressed and event.index == _active_index:
			_active_index = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_index:
		drag_delta.emit(event.relative)
		accept_event()
