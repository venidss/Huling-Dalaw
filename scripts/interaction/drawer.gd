extends StaticBody3D
## Drawer / cabinet interactable. Opens to reveal a child spawn point where items appear.
## Can be locked, and can host a one-shot "reveal" (an item spawns inside the first time
## the player opens it).
class_name DrawerInteractable

@export var open_offset: Vector3 = Vector3(0, 0, 0.35)
@export var open_time: float = 0.4
@export var spawn_item_id: String = ""          # inventory item id to spawn inside on first open
@export var contains_label: String = ""         # optional label when something is inside
@export var completes_mission_on_find: String = ""

var is_open: bool = false
var _drawer_body: Node3D
var _closed_pos: Vector3
var _item_spawned: bool = false
var _item_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0
	call_deferred("_bind_body")

func _bind_body() -> void:
	_drawer_body = get_node_or_null("Body")
	if _drawer_body == null:
		_drawer_body = self
	_closed_pos = _drawer_body.position

func get_interact_label() -> String:
	if is_open:
		if _item_mesh != null and spawn_item_id != "":
			var def := Inventory.get_definition(spawn_item_id)
			var n := String(def.get("name", "ang laman"))
			return "Kunin: " + n
		return "Isara ang kahon"
	return "Buksan ang kahon"

func interact(_player: Node) -> void:
	if is_open and _item_mesh != null:
		# Pick up the revealed item.
		if spawn_item_id != "":
			Inventory.add_item(spawn_item_id)
			AudioManager.play_sfx("item_pickup.wav")
			if completes_mission_on_find != "":
				MissionManager.complete(completes_mission_on_find)
		_item_mesh.queue_free()
		_item_mesh = null
		return
	_toggle()

func _toggle() -> void:
	is_open = not is_open
	var target := _closed_pos + (open_offset if is_open else Vector3.ZERO)
	var tween := create_tween()
	tween.tween_property(_drawer_body, "position", target, open_time)
	AudioManager.play_sfx_3d("drawer_slide.wav", self, -3.0)
	if is_open and not _item_spawned and spawn_item_id != "":
		_spawn_contents()
		_item_spawned = true

func _spawn_contents() -> void:
	# Visual pop-in of a small cube that represents the item inside the drawer.
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.05, 0.08)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	var def := Inventory.get_definition(spawn_item_id)
	var col: Color = def.get("color", Color(0.8, 0.7, 0.4))
	mat.albedo_color = col
	mat.metallic = 0.3
	mat.roughness = 0.6
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.02, 0)
	_drawer_body.add_child(mesh)
	_item_mesh = mesh
