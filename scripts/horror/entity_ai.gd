extends CharacterBody3D
## Minimal, deliberate "entity" presence for DAET: ANG PAMANA.
##
## This is not a hostile pursuit AI in the horror-chase sense — it is a quiet,
## story-driven figure that only appears during specific mission beats. States:
##   DORMANT  — invisible, no behavior
##   STALK    — slowly tracks the player at a distance (used during a brief chase beat)
##   REVEAL   — stands still at a visible point as a scripted scare
##   FADE     — fades away
##
## Movement uses direct motion (not NavMesh) to stay simple and reliable in a procedural
## scene; a NavigationRegion3D could be added later.

enum State { DORMANT, STALK, REVEAL, FADE }

@export var move_speed: float = 1.4
@export var stop_distance: float = 2.0
@export var sight_distance: float = 15.0

var state: State = State.DORMANT
var _target_point: Vector3 = Vector3.ZERO
var _fade_t: float = 0.0

var mesh_root: Node3D = null

func _ready() -> void:
	visible = false
	collision_layer = 1 << 3
	collision_mask = 1  # collide with world walls so we don't glide through them
	call_deferred("_bind_visual")

func _bind_visual() -> void:
	mesh_root = get_node_or_null("Visual")

func set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.DORMANT:
			visible = false
			_fade_t = 0.0
			_set_alpha(1.0)
		State.STALK:
			visible = true
			_set_alpha(0.85)
		State.REVEAL:
			visible = true
			_set_alpha(1.0)
		State.FADE:
			_fade_t = 1.0

func _physics_process(delta: float) -> void:
	match state:
		State.STALK:
			_tick_stalk(delta)
		State.FADE:
			_fade_t = max(0.0, _fade_t - delta * 0.9)
			_set_alpha(_fade_t)
			if _fade_t <= 0.0:
				visible = false
				set_state(State.DORMANT)

func _tick_stalk(delta: float) -> void:
	var player := GameState.current_player
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()
	if dist > sight_distance:
		return
	if dist > stop_distance:
		var dir := to_player.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	# Face the player slowly.
	var target_y := atan2(to_player.x, to_player.z)
	rotation.y = lerp_angle(rotation.y, target_y, 2.0 * delta)

func teleport_to(point: Vector3, face_player: bool = true) -> void:
	global_position = point
	if face_player and GameState.current_player != null:
		var to_p: Vector3 = GameState.current_player.global_position - global_position
		rotation.y = atan2(to_p.x, to_p.z)

func _set_alpha(a: float) -> void:
	if mesh_root == null:
		return
	for c in mesh_root.get_children():
		if c is MeshInstance3D:
			var mat := c.material_override
			if mat == null:
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.03, 0.02, 0.03, a)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				c.material_override = mat
			else:
				var col: Color = mat.albedo_color
				col.a = a
				mat.albedo_color = col
