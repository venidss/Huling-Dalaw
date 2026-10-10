extends Node
## GameState autoload for DAET: ANG PAMANA.
##
## Lightweight bag of shared references and global player data (position, chosen ending).
## Scripts register the player on _ready() so systems can reach it without hard scene paths.

signal paused_changed(is_paused: bool)
signal player_registered(player: Node)
signal game_over

const ENDING_NONE := 0
const ENDING_FORGIVENESS := 1    # released the memory, Tala rests
const ENDING_BURIED := 2         # hid the truth again, cycle continues
const ENDING_LOST := 3           # the entity won

var current_player: Node3D = null
var current_level: Node = null
var is_paused: bool = false
var chosen_ending: int = ENDING_NONE

# Where the player should spawn when the gameplay scene loads from a save. If zero vector,
# the scene uses its default spawn marker.
var pending_spawn_position: Vector3 = Vector3.ZERO
var pending_spawn_yaw: float = 0.0
var has_pending_spawn: bool = false
var restored_from_save: bool = false   # true after a loaded save applied — game_controller skips its default pose

func register_player(p: Node3D) -> void:
	current_player = p
	player_registered.emit(p)
	if has_pending_spawn and p != null:
		p.global_position = pending_spawn_position
		if p.has_method("set_yaw"):
			p.set_yaw(pending_spawn_yaw)
		has_pending_spawn = false
		restored_from_save = true

func register_level(lvl: Node) -> void:
	current_level = lvl

func set_paused(v: bool) -> void:
	if is_paused == v:
		return
	is_paused = v
	get_tree().paused = v
	paused_changed.emit(v)

func serialize_player() -> Dictionary:
	if current_player == null:
		return {}
	var pos: Vector3 = current_player.global_position
	var yaw: float = 0.0
	if current_player.has_method("get_yaw"):
		yaw = current_player.get_yaw()
	return {
		"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"yaw": yaw,
	}

func restore_player(data: Dictionary) -> void:
	if data.is_empty():
		return
	var pos: Dictionary = data.get("position", {})
	pending_spawn_position = Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))
	pending_spawn_yaw = float(data.get("yaw", 0.0))
	has_pending_spawn = pending_spawn_position != Vector3.ZERO

func reset_run() -> void:
	# Called when starting a new game — clears flags & inventory.
	Inventory.clear()
	MissionManager.completed_missions.clear()
	MissionManager.story_flags.clear()
	MissionManager.journal_entries.clear()
	MissionManager.current_mission_id = MissionManager.missions[0].id
	HorrorManager.triggered_events.clear()
	chosen_ending = ENDING_NONE
	has_pending_spawn = false
