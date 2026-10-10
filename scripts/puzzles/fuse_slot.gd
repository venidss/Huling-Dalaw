extends StaticBody3D
## A single fuse slot that accepts the "fuse" inventory item once.
## When the slot is filled, calls MissionManager.set_flag(fill_flag). The fuse-box
## light switch checks for that flag before letting the player flip the main switch.
class_name FuseSlot

@export var fill_flag: String = "fuse_installed"
@export var completes_mission: String = ""

var _filled: bool = false
var fuse_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0
	call_deferred("_bind_mesh")

func _bind_mesh() -> void:
	fuse_mesh = get_node_or_null("FuseMesh") as MeshInstance3D
	if fuse_mesh:
		fuse_mesh.visible = _filled

func get_interact_label() -> String:
	if _filled:
		return "May nakalagay nang fuse"
	if not Inventory.has_item("fuse"):
		return "Walang fuse"
	if Settings.show_english_subtitles:
		return "Ilagay ang fuse / Install fuse"
	return "Ilagay ang fuse"

func interact(_player: Node) -> void:
	if _filled:
		return
	if not Inventory.has_item("fuse"):
		AudioManager.play_sfx_3d("switch_broken.wav", self)
		return
	_filled = true
	Inventory.remove_item("fuse")
	if fuse_mesh:
		fuse_mesh.visible = true
	AudioManager.play_sfx_3d("switch_flip.wav", self)
	if fill_flag != "":
		MissionManager.set_flag(fill_flag, true)
	if completes_mission != "":
		MissionManager.complete(completes_mission)
