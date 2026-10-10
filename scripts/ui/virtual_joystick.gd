extends Control
## Virtual on-screen joystick for touchscreen movement.
##
## The joystick lives in a Control rect (its "touch zone"). Touching anywhere inside the
## zone creates a knob at the touch origin and the knob tracks the finger, up to a max
## radius. The vector is exposed as a Vector2 in `output` where (x=right, y=forward).
##
## Supports multitouch: each joystick stores the touch index that currently controls it so
## the right-side camera-look area and the joystick never fight for the same finger.
class_name VirtualJoystick

signal direction_changed(dir: Vector2)

@export var max_radius: float = 90.0
@export var base_radius: float = 90.0
@export var knob_radius: float = 42.0
@export var base_color: Color = Color(1, 1, 1, 0.14)
@export var knob_color: Color = Color(1, 1, 1, 0.35)
@export var ring_color: Color = Color(1, 1, 1, 0.22)

var output: Vector2 = Vector2.ZERO
var _active_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _visible_touch: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_index == -1:
			_active_index = event.index
			_center = event.position
			_knob = event.position
			_visible_touch = true
			queue_redraw()
			accept_event()
		elif not event.pressed and event.index == _active_index:
			_active_index = -1
			output = Vector2.ZERO
			_visible_touch = false
			direction_changed.emit(output)
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_index:
		var offset: Vector2 = event.position - _center
		if offset.length() > max_radius:
			offset = offset.normalized() * max_radius
		_knob = _center + offset
		# Output matches Input.get_vector("left","right","up","down"): +x = right, +y = back
		# (dragging the finger downward on the screen moves the player backward).
		output = Vector2(offset.x / max_radius, offset.y / max_radius)
		direction_changed.emit(output)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton:
		# Desktop fallback for testing — the mouse acts as a single-finger touch.
		if event.pressed and _active_index == -1:
			_active_index = -2
			_center = event.position
			_knob = event.position
			_visible_touch = true
			queue_redraw()
		elif not event.pressed and _active_index == -2:
			_active_index = -1
			output = Vector2.ZERO
			_visible_touch = false
			direction_changed.emit(output)
			queue_redraw()
	elif event is InputEventMouseMotion and _active_index == -2:
		var offset: Vector2 = event.position - _center
		if offset.length() > max_radius:
			offset = offset.normalized() * max_radius
		_knob = _center + offset
		output = Vector2(offset.x / max_radius, offset.y / max_radius)
		direction_changed.emit(output)
		queue_redraw()

func _draw() -> void:
	# Draw an idle ring in the lower-left when nothing is being touched.
	if not _visible_touch:
		var idle_center := Vector2(base_radius + 40, size.y - base_radius - 40)
		draw_circle(idle_center, base_radius, base_color)
		draw_arc(idle_center, base_radius, 0, TAU, 48, ring_color, 2.0)
		draw_circle(idle_center, knob_radius, knob_color)
		return
	draw_circle(_center, base_radius, base_color)
	draw_arc(_center, base_radius, 0, TAU, 48, ring_color, 2.0)
	draw_circle(_knob, knob_radius, knob_color)
