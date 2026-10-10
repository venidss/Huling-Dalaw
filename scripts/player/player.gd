extends CharacterBody3D
## First-person player controller for DAET: ANG PAMANA.
##
## Movement: WASD / virtual joystick, sprinting with stamina, optional crouch.
## Camera: mouse look on desktop, touch-drag on mobile. Both run through the same
##         yaw/pitch state so switching input methods mid-game is seamless.
## Flashlight: toggleable spotlight on the camera.
## Interaction: short raycast from camera; the HUD displays the prompt and the "interact"
##              action calls .interact() on the target.
##
## The script accepts input values set externally (joystick_input, look_delta) so UI widgets
## can feed it directly — no polling of named Input actions is needed on mobile.

const MOUSE_SENSITIVITY_SCALE := 0.002
const TOUCH_SENSITIVITY_SCALE := 0.004
const MAX_PITCH := deg_to_rad(85.0)
const MIN_PITCH := deg_to_rad(-85.0)

@export var walk_speed: float = 2.5
@export var sprint_speed: float = 4.4
@export var crouch_speed: float = 1.3
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export var jump_velocity: float = 4.0
@export var gravity: float = 15.0
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 20.0
@export var stamina_regen: float = 15.0
@export var interact_distance: float = 2.5
@export var head_bob_amp: float = 0.025
@export var head_bob_freq: float = 8.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var stand_collider: CollisionShape3D = $StandCollider
@onready var crouch_collider: CollisionShape3D = $CrouchCollider
@onready var footstep_timer: Timer = $FootstepTimer

var yaw: float = 0.0
var pitch: float = 0.0
var stamina: float = 100.0
var is_crouching: bool = false
var is_sprinting: bool = false
var can_move: bool = true
var head_bob_t: float = 0.0

# External inputs (set by mobile controls).
var joystick_input: Vector2 = Vector2.ZERO
var pending_look_delta: Vector2 = Vector2.ZERO

# The current interactable the ray is hitting (if any).
var _current_interactable: Node = null

signal interactable_focused(target: Node)
signal interactable_unfocused
signal stamina_changed(current: float, max_value: float)

func _ready() -> void:
	add_to_group("player")
	# Register with the global state so other systems can find us.
	GameState.register_player(self)
	stamina = max_stamina
	footstep_timer.timeout.connect(_on_footstep)
	# Only skip mouse capture on actual mobile platforms. Many desktop laptops have
	# touchscreens AND a mouse — in that case we still want standard FPS controls.
	if not _is_mobile_platform():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Re-capture the mouse when the game unpauses, release it when it pauses.
	GameState.paused_changed.connect(_on_paused_changed)
	# Give the flashlight a sensible default (off until the player picks it up).
	flashlight.visible = false

func _is_mobile_platform() -> bool:
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

func _on_paused_changed(is_paused: bool) -> void:
	if _is_mobile_platform():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED

## _input runs BEFORE any Control's _gui_input and before _unhandled_input, so mouse
## motion events can't be swallowed by HUD elements (dialogue box, touch camera area,
## etc.). We use it specifically for mouse look.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not can_move:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var sens: float = Settings.camera_sensitivity * MOUSE_SENSITIVITY_SCALE
		_apply_look((event as InputEventMouseMotion).relative * sens)

func _unhandled_input(event: InputEvent) -> void:
	# Left-click anywhere in the game viewport re-captures the mouse on desktop. This
	# is a universal rescue if the user accidentally alt-tabbed or if the initial
	# capture didn't take hold on the first frame.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _is_mobile_platform() and not GameState.is_paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			# Don't fall through to interact on the same click — just capture.
			get_viewport().set_input_as_handled()
			return
	if not can_move:
		return
	if event.is_action_pressed("flashlight"):
		if Inventory.has_item("flashlight"):
			toggle_flashlight()
	elif event.is_action_pressed("interact"):
		attempt_interact()

func _apply_look(delta: Vector2) -> void:
	yaw -= delta.x
	var pitch_delta := delta.y
	if Settings.invert_y:
		pitch_delta = -pitch_delta
	pitch -= pitch_delta
	pitch = clampf(pitch, MIN_PITCH, MAX_PITCH)
	rotation.y = yaw
	head.rotation.x = pitch

## Called by the touch camera area each physics frame with pixel delta.
func apply_touch_look(pixel_delta: Vector2) -> void:
	if not can_move:
		return
	var sens: float = Settings.touch_sensitivity * TOUCH_SENSITIVITY_SCALE
	_apply_look(pixel_delta * sens)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Horizontal input
	var input_vec := _gather_movement_input()
	var target_speed := walk_speed
	is_sprinting = false
	if Input.is_action_pressed("sprint") and stamina > 0.5 and not is_crouching and input_vec.length() > 0.1:
		target_speed = sprint_speed
		is_sprinting = true
		stamina = maxf(0.0, stamina - stamina_drain * delta)
		stamina_changed.emit(stamina, max_stamina)
	else:
		if stamina < max_stamina:
			stamina = minf(max_stamina, stamina + stamina_regen * delta)
			stamina_changed.emit(stamina, max_stamina)
	if is_crouching:
		target_speed = crouch_speed

	var dir := transform.basis * Vector3(input_vec.x, 0, input_vec.y)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

	var target_velocity := dir * target_speed
	var accel := acceleration if dir.length() > 0.01 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	if can_move:
		move_and_slide()

	_update_head_bob(delta, dir.length() > 0.01)
	_update_interact_ray()
	_update_footsteps(dir.length() > 0.01, target_speed)

func _gather_movement_input() -> Vector2:
	if not can_move:
		return Vector2.ZERO
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# External joystick overrides keyboard when active to avoid conflicting direction.
	if joystick_input.length() > 0.1:
		return joystick_input
	return kb

func _update_head_bob(delta: float, moving: bool) -> void:
	if moving:
		head_bob_t += delta * head_bob_freq * (1.6 if is_sprinting else 1.0)
		var amp := head_bob_amp * (1.6 if is_sprinting else 1.0)
		head.position.y = lerpf(head.position.y, 0.65 + sin(head_bob_t) * amp, 10.0 * delta)
		head.position.x = lerpf(head.position.x, cos(head_bob_t * 0.5) * amp * 0.6, 10.0 * delta)
	else:
		head.position.y = lerpf(head.position.y, 0.65, 8.0 * delta)
		head.position.x = lerpf(head.position.x, 0.0, 8.0 * delta)

func _update_interact_ray() -> void:
	if not interact_ray.enabled:
		return
	interact_ray.force_raycast_update()
	var hit := interact_ray.get_collider()
	if hit == null:
		if _current_interactable != null:
			_current_interactable = null
			interactable_unfocused.emit()
		return
	# Walk up the parent chain until we find a node that has .interact().
	var node := hit
	while node != null and not (node.has_method("get_interact_label") or node.is_in_group("interactable")):
		node = node.get_parent()
	if node == null or node == _current_interactable:
		return
	_current_interactable = node
	interactable_focused.emit(node)

func attempt_interact() -> void:
	if _current_interactable == null:
		return
	if not is_instance_valid(_current_interactable):
		_current_interactable = null
		interactable_unfocused.emit()
		return
	if _current_interactable.has_method("interact"):
		_current_interactable.interact(self)

func get_current_interactable() -> Node:
	return _current_interactable

func toggle_flashlight() -> void:
	flashlight.visible = not flashlight.visible
	AudioManager.play_sfx("ui_click.wav", -4.0)

func set_crouch(active: bool) -> void:
	is_crouching = active
	stand_collider.disabled = active
	crouch_collider.disabled = not active
	head.position.y = 0.3 if active else 0.65

func set_can_move(v: bool) -> void:
	can_move = v
	if not v:
		velocity = Vector3.ZERO
	# Hide/show flashlight interaction when controls are locked.

func get_yaw() -> float:
	return yaw

func set_yaw(v: float) -> void:
	yaw = v
	rotation.y = yaw

# --- footsteps ---------------------------------------------------------------

func _update_footsteps(moving: bool, speed: float) -> void:
	if moving and is_on_floor():
		var interval: float
		if is_sprinting:
			interval = 0.32
		elif is_crouching:
			interval = 0.7
		else:
			interval = 0.5
		if footstep_timer.wait_time != interval:
			footstep_timer.wait_time = interval
		if footstep_timer.is_stopped():
			footstep_timer.start()
			_on_footstep()
	else:
		footstep_timer.stop()

func _on_footstep() -> void:
	var pitch_rand := randf_range(0.9, 1.1)
	AudioManager.play_sfx_3d("footstep.wav", self, -8.0 if is_crouching else -4.0, pitch_rand)
