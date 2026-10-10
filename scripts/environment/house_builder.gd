extends Node3D
## Procedural builder for the Filipino ancestral house in DAET: ANG PAMANA.
##
## Generates the entire interior & exterior at runtime: walls, floors, ceiling, doors,
## furniture (via code-authored meshes), windows, lights, atmospheric emitters, and
## placed interactables. Keeps the on-disk scene small, mobile-friendly, and makes it
## easy to tweak layout.
##
## Layout (viewed top-down, +Z = south toward player entrance):
##
##   -8m          0            8m         16m   (X)
##   +----------------------------------+       <- back wall  (Z = -8)
##   |          |            |          |
##   |  Lolo's  |  Altar     |  Storage |
##   |  room    |  room      |          |
##   |  (locked)|            |          |
##   +----------+------------+----------+       (Z = -2)
##   |          |                        |
##   |  Lola's  |   Hallway              |
##   |  room    |                        |
##   |          |                        |
##   +----------+------------------------+      (Z = 4)
##   |          |            |           |
##   |          |  Dining /  |           |
##   |  Sala    |  Kitchen   |  Side     |
##   | (living) |            |  porch    |
##   |          |            |           |
##   +----------+------------+-----------+      (Z = 10)
##               (front door at X ~= 4)
##                     |
##                front yard
##                     |
##                [gate]  (Z = 20)
##
## The script keeps references to key nodes (doors, lights, altar area, triggers) so other
## systems — horror events, mission triggers — can be wired up by node path at the end.

const WALL_HEIGHT := 2.7
const WALL_THICKNESS := 0.14
const FLOOR_LEVEL := 0.0

# Preloaded shared materials — created once in _build_materials().
var _mat_wall_interior: StandardMaterial3D
var _mat_wall_exterior: StandardMaterial3D
var _mat_wood_floor: StandardMaterial3D
var _mat_wood_dark: StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_grass: StandardMaterial3D
var _mat_dirt: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_fabric: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_concrete: StandardMaterial3D
var _mat_altar: StandardMaterial3D
var _mat_paper: StandardMaterial3D

# References to spawned nodes other systems may need to find.
var front_door_ref: Node3D
var upstairs_door_ref: Node3D   # kept symbolic — we use "bedroom door" to lola's room
var locked_room_door_ref: Node3D
var altar_passage_door_ref: Node3D
var fuse_box_switch_ref: Node3D
var fuse_slot_ref: Node3D
var hall_lights: Array[Light3D] = []
var kitchen_lights: Array[Light3D] = []
var altar_lights: Array[Light3D] = []
var player_spawn_marker: Marker3D
var entity_spawn_hall: Marker3D
var entity_spawn_altar: Marker3D

func _ready() -> void:
	_build_materials()
	_build_terrain()
	_build_house()
	_build_rooms()
	_build_furniture()
	_build_interactables_and_lights()
	_build_horror_events()
	_build_mission_triggers()
	_build_ambience()

# ---------------------------------------------------------------------------- #
#  Materials                                                                   #
# ---------------------------------------------------------------------------- #

func _build_materials() -> void:
	_mat_wall_interior = _make_mat(Color(0.78, 0.72, 0.58), 0.95, 0.0)
	_mat_wall_exterior = _make_mat(Color(0.58, 0.5, 0.42), 0.9, 0.0)
	_mat_wood_floor = _make_mat(Color(0.42, 0.25, 0.15), 0.75, 0.1)
	_mat_wood_dark = _make_mat(Color(0.22, 0.14, 0.08), 0.7, 0.1)
	_mat_ceiling = _make_mat(Color(0.65, 0.6, 0.5), 0.95, 0.0)
	_mat_grass = _make_mat(Color(0.18, 0.3, 0.14), 1.0, 0.0)
	_mat_dirt = _make_mat(Color(0.3, 0.22, 0.14), 0.95, 0.0)
	_mat_metal = _make_mat(Color(0.3, 0.3, 0.33), 0.4, 0.7)
	_mat_fabric = _make_mat(Color(0.55, 0.35, 0.25), 0.98, 0.0)
	_mat_glass = _make_mat(Color(0.6, 0.72, 0.78, 0.5), 0.1, 0.1)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_concrete = _make_mat(Color(0.45, 0.42, 0.4), 0.98, 0.0)
	_mat_altar = _make_mat(Color(0.3, 0.2, 0.12), 0.6, 0.15)
	_mat_altar.emission_enabled = true
	_mat_altar.emission = Color(0.6, 0.3, 0.1)
	_mat_altar.emission_energy_multiplier = 0.1
	_mat_paper = _make_mat(Color(0.85, 0.82, 0.72), 0.95, 0.0)

func _make_mat(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	# Keep two-sided off and shading set to default for mobile perf.
	return m

# ---------------------------------------------------------------------------- #
#  Terrain / exterior                                                          #
# ---------------------------------------------------------------------------- #

func _build_terrain() -> void:
	# Big grass plane under everything.
	var ground := _make_box(Vector3(80, 0.4, 80), _mat_grass)
	ground.position = Vector3(4, -0.2, 6)
	add_child(ground)
	_add_floor_collider(Vector3(80, 0.4, 80), Vector3(4, -0.2, 6))

	# Dirt path to the front door.
	var path := _make_box(Vector3(2.4, 0.05, 10.0), _mat_dirt)
	path.position = Vector3(4, 0.01, 15.5)
	add_child(path)

	# Gate: two posts + horizontal plank.
	for x in [2.6, 5.4]:
		var post := _make_box(Vector3(0.2, 2.0, 0.2), _mat_wood_dark)
		post.position = Vector3(x, 1.0, 20.0)
		add_child(post)
	var plank := _make_box(Vector3(3.0, 0.14, 0.08), _mat_wood_dark)
	plank.position = Vector3(4, 1.7, 20.0)
	add_child(plank)
	# Perimeter fence posts (visuals) along both sides of the plot.
	for z in range(-10, 22, 2):
		var post := _make_box(Vector3(0.1, 1.2, 0.1), _mat_wood_dark)
		post.position = Vector3(-6.0, 0.6, z)
		add_child(post)
		var post2 := _make_box(Vector3(0.1, 1.2, 0.1), _mat_wood_dark)
		post2.position = Vector3(14.0, 0.6, z)
		add_child(post2)
	# Invisible solid walls between the fence posts — keeps the player on the plot and
	# forces them to go through the house (and the altar passage) to reach the back area.
	_add_static_collider_box(Vector3(0.2, 2.4, 34.0), Vector3(-6.0, 1.2, 4.0))
	_add_static_collider_box(Vector3(0.2, 2.4, 34.0), Vector3(14.0, 1.2, 4.0))
	# Back fence at Z = -13 so the small "behind the house" area where the altar passage
	# exits is also enclosed. The ending zone sits inside this enclosed back area.
	_add_static_collider_box(Vector3(20.4, 2.4, 0.2), Vector3(4.0, 1.2, -13.0))

	# Yard decoration: scattered plants (simple cones/bushes).
	for pt in [Vector2(-2, 15), Vector2(0.5, 18), Vector2(8, 14), Vector2(11, 17), Vector2(-3, 19)]:
		var bush := _make_cone(0.5, 0.7, Color(0.14, 0.26, 0.12))
		bush.position = Vector3(pt.x, 0.35, pt.y)
		add_child(bush)
	# A single old mango tree near the gate.
	_add_tree(Vector3(-3.5, 0, 16))

# ---------------------------------------------------------------------------- #
#  Core house                                                                  #
# ---------------------------------------------------------------------------- #

func _build_house() -> void:
	# Overall footprint: X: -8 to 14, Z: -8 to 10. Walls thickness along their width.
	# Floors inside the house (raised 0.25m to feel like a bahay na bato on stilts).
	var floor_level := 0.25

	# Floor: single wood plank slab for the whole interior.
	var floor_mesh := _make_box(Vector3(22, 0.1, 18), _mat_wood_floor)
	floor_mesh.position = Vector3(3, floor_level - 0.05, 1)
	add_child(floor_mesh)
	_add_floor_collider(Vector3(22, 0.1, 18), Vector3(3, floor_level - 0.05, 1))

	# Base stilts/skirt (visual only).
	var skirt := _make_box(Vector3(22.3, 0.3, 18.3), _mat_concrete)
	skirt.position = Vector3(3, floor_level - 0.2, 1)
	add_child(skirt)

	# Ceiling (hidden to the player from below).
	var ceiling := _make_box(Vector3(22, 0.1, 18), _mat_ceiling)
	ceiling.position = Vector3(3, floor_level + WALL_HEIGHT - 0.05, 1)
	add_child(ceiling)

	# Exterior walls (with door opening in the front).
	# Front wall: Z = 10. Opening at X ~= 4 (width 1.2m) for front door.
	_add_wall(Vector3(-8, floor_level, 10), Vector3(3.4, floor_level + WALL_HEIGHT, 10 + WALL_THICKNESS), true)
	_add_wall(Vector3(4.6, floor_level, 10), Vector3(14, floor_level + WALL_HEIGHT, 10 + WALL_THICKNESS), true)
	# Lintel above front door
	_add_wall(Vector3(3.4, floor_level + 2.2, 10), Vector3(4.6, floor_level + WALL_HEIGHT, 10 + WALL_THICKNESS), true)
	# Back wall with the altar's hidden-passage opening between X = -3.6 and -2.4.
	_add_wall(Vector3(-8, floor_level, -8), Vector3(-3.6, floor_level + WALL_HEIGHT, -8 + WALL_THICKNESS), true)
	_add_wall(Vector3(-2.4, floor_level, -8), Vector3(14, floor_level + WALL_HEIGHT, -8 + WALL_THICKNESS), true)
	# Lintel above the hidden doorway so it looks continuous when the door is closed.
	_add_wall(Vector3(-3.6, floor_level + 2.1, -8), Vector3(-2.4, floor_level + WALL_HEIGHT, -8 + WALL_THICKNESS), true)
	# Left wall
	_add_wall(Vector3(-8, floor_level, -8), Vector3(-8 + WALL_THICKNESS, floor_level + WALL_HEIGHT, 10), true)
	# Right wall with one window opening.
	_add_wall(Vector3(14 - WALL_THICKNESS, floor_level, -8), Vector3(14, floor_level + WALL_HEIGHT, 2), true)
	_add_wall(Vector3(14 - WALL_THICKNESS, floor_level + 1.6, 2), Vector3(14, floor_level + WALL_HEIGHT, 4), true)   # top of window
	_add_wall(Vector3(14 - WALL_THICKNESS, floor_level, 2), Vector3(14, floor_level + 0.9, 4), true)                 # sill
	_add_wall(Vector3(14 - WALL_THICKNESS, floor_level, 4), Vector3(14, floor_level + WALL_HEIGHT, 10), true)
	# Glass window pane
	var window_pane := _make_box(Vector3(0.04, 0.7, 2.0), _mat_glass)
	window_pane.position = Vector3(14 - WALL_THICKNESS * 0.5, floor_level + 1.25, 3)
	add_child(window_pane)

	# Front porch roof overhang.
	var porch := _make_box(Vector3(6.0, 0.08, 1.6), _mat_wood_dark)
	porch.position = Vector3(4, floor_level + WALL_HEIGHT + 0.2, 11.6)
	add_child(porch)
	# Porch posts.
	for x in [1.2, 6.8]:
		var post := _make_box(Vector3(0.14, floor_level + WALL_HEIGHT + 0.2, 0.14), _mat_wood_dark)
		post.position = Vector3(x, (floor_level + WALL_HEIGHT + 0.2) / 2.0, 12.4)
		add_child(post)
	# Small front step.
	var step := _make_box(Vector3(1.8, 0.25, 0.6), _mat_concrete)
	step.position = Vector3(4, floor_level - 0.1, 10.6)
	add_child(step)

	# Roof (large peaked prism).
	_add_roof(floor_level + WALL_HEIGHT)

func _add_roof(base_y: float) -> void:
	# Two sloped planes meeting at a ridge above X = 3.
	var r_mat := _mat_wood_dark
	var left := MeshInstance3D.new()
	left.mesh = _make_quad_mesh(
		Vector3(-9, base_y, -9),
		Vector3(-9, base_y, 11),
		Vector3(3, base_y + 2.4, 11),
		Vector3(3, base_y + 2.4, -9)
	)
	left.material_override = r_mat
	add_child(left)
	var right := MeshInstance3D.new()
	right.mesh = _make_quad_mesh(
		Vector3(3, base_y + 2.4, -9),
		Vector3(3, base_y + 2.4, 11),
		Vector3(15, base_y, 11),
		Vector3(15, base_y, -9)
	)
	right.material_override = r_mat
	add_child(right)

# Interior wall segments.
func _build_rooms() -> void:
	var y0 := 0.25
	# Vertical interior wall at X=0 (separates west rooms from hallway) with doorways.
	# Lola's room door at Z=6-7.
	_add_wall(Vector3(0, y0, -8), Vector3(0 + WALL_THICKNESS, y0 + WALL_HEIGHT, 6), false)
	_add_wall(Vector3(0, y0, 7.2), Vector3(0 + WALL_THICKNESS, y0 + WALL_HEIGHT, 10), false)
	_add_wall(Vector3(0, y0 + 2.1, 6), Vector3(0 + WALL_THICKNESS, y0 + WALL_HEIGHT, 7.2), false)   # lintel

	# Vertical wall at X=8 (separates center from east storage/dining).
	_add_wall(Vector3(8, y0, -8), Vector3(8 + WALL_THICKNESS, y0 + WALL_HEIGHT, 2), false)
	_add_wall(Vector3(8, y0, 3.2), Vector3(8 + WALL_THICKNESS, y0 + WALL_HEIGHT, 10), false)   # doorway into dining at Z=2-3.2
	_add_wall(Vector3(8, y0 + 2.1, 2), Vector3(8 + WALL_THICKNESS, y0 + WALL_HEIGHT, 3.2), false)   # lintel

	# Horizontal wall at Z=4 (separates sala/dining from hallway/altar area), long span.
	# Two openings: X=-2 to -0.6 (sala <-> lola's room) and X=3 to 4.5 (dining <-> hallway main).
	_add_wall(Vector3(-8, y0, 4), Vector3(-2, y0 + WALL_HEIGHT, 4 + WALL_THICKNESS), false)
	_add_wall(Vector3(-0.6, y0, 4), Vector3(3, y0 + WALL_HEIGHT, 4 + WALL_THICKNESS), false)
	_add_wall(Vector3(4.5, y0, 4), Vector3(14, y0 + WALL_HEIGHT, 4 + WALL_THICKNESS), false)
	_add_wall(Vector3(-2, y0 + 2.1, 4), Vector3(-0.6, y0 + WALL_HEIGHT, 4 + WALL_THICKNESS), false)
	_add_wall(Vector3(3, y0 + 2.1, 4), Vector3(4.5, y0 + WALL_HEIGHT, 4 + WALL_THICKNESS), false)

	# Horizontal wall at Z=-2 (separates altar/upper rooms from lola/center hallway).
	# Opening at X= -1 to 0 for altar entrance.
	_add_wall(Vector3(-8, y0, -2), Vector3(-1, y0 + WALL_HEIGHT, -2 + WALL_THICKNESS), false)
	_add_wall(Vector3(0, y0, -2), Vector3(5, y0 + WALL_HEIGHT, -2 + WALL_THICKNESS), false)
	_add_wall(Vector3(6, y0, -2), Vector3(14, y0 + WALL_HEIGHT, -2 + WALL_THICKNESS), false)
	# Doorway for locked family room between x=5 and 6.
	_add_wall(Vector3(5, y0 + 2.1, -2), Vector3(6, y0 + WALL_HEIGHT, -2 + WALL_THICKNESS), false)
	# Doorway for altar between X= -1 to 0.
	_add_wall(Vector3(-1, y0 + 2.1, -2), Vector3(0, y0 + WALL_HEIGHT, -2 + WALL_THICKNESS), false)

	# Doors: front door, lola's door, locked family room, altar.
	front_door_ref = _add_door(Vector3(4, y0, 10 + WALL_THICKNESS / 2.0), 0.0, 1.2, "")
	upstairs_door_ref = _add_door(Vector3(0 + WALL_THICKNESS / 2.0, y0, 6.6), 90.0, 1.2, "")
	locked_room_door_ref = _add_door_locked(Vector3(5.5, y0, -2 + WALL_THICKNESS / 2.0), 0.0, 1.0, "key_locked_room", "find_locked_key")
	# Altar entry has no physical door (open archway) but we'll put the hidden passage door inside the altar room later.

# ---------------------------------------------------------------------------- #
#  Furniture & props                                                           #
# ---------------------------------------------------------------------------- #

func _build_furniture() -> void:
	# ===== Sala (living room): X -8 to 0, Z 4 to 10 =====
	# Couch (foam-looking box with armrests)
	_make_couch(Vector3(-6, 0.25, 7), 90.0)
	# Coffee table in front of couch
	_add_table(Vector3(-4.2, 0.25, 7), Vector3(1.4, 0.5, 0.9))
	# Old TV cabinet with CRT TV
	_add_tv_cabinet(Vector3(-1, 0.25, 7))
	# Bookshelf
	_add_bookshelf(Vector3(-7.6, 0.25, 4.6))
	# Capiz lamp hanging in center
	# (handled by lights)

	# ===== Dining / Kitchen: X 0 to 8, Z 4 to 10 =====
	# Dining table + chairs
	_add_dining_set(Vector3(2, 0.25, 7))
	# Kitchen counter along back wall (toward Z=4)
	_add_kitchen_counter(Vector3(6, 0.25, 4.9))
	# Old refrigerator
	_add_fridge(Vector3(7.4, 0.25, 5.0))
	# Stovetop (visual)
	_add_stove(Vector3(5, 0.25, 4.6))

	# ===== Hallway: X 0 to 8, Z -2 to 4 =====
	# Family photos on the wall at Z=-2 side (west wall of hallway, X ~= 0).
	for i in 3:
		var photo := _add_photo_frame(Vector3(0 + WALL_THICKNESS + 0.03, 0.25 + 1.6, 0.5 + i * 1.3), -90.0, 0.6, 0.4)
		photo.caption = ["Lola at Lolo, kasal 1962", "Lolo Berto, mangingisda 1955", "Pamilya, Pasko 1970"][i]
		photo.caption_en = ["Lola and Lolo, wedding 1962", "Lolo Berto, fisherman 1955", "Family, Christmas 1970"][i]
	# A rug.
	_add_rug(Vector3(4, 0.26, 1))

	# ===== Lola's bedroom: X -8 to 0, Z -2 to 4 =====
	# Bed
	_add_bed(Vector3(-6, 0.25, 1))
	# Night stand (has the diary sitting on it — see below)
	_add_nightstand(Vector3(-6, 0.25, -1))
	# Lola's diary on the nightstand — readable; reading it adds the "diary" item
	# and completes find_diary. The entries name the year 1973.
	_add_diary_note(Vector3(-6, 0.9, -1))
	# Empty wardrobe/dresser nearby.
	_add_dresser_with_item(Vector3(-2, 0.25, -1.4), "", "")

	# ===== Lolo's locked family room: X 0 to 8, Z -8 to -2 =====
	# Writing desk
	_add_desk(Vector3(2, 0.25, -6))
	# Chair
	_add_chair(Vector3(2, 0.25, -5.2))
	# Dusty bookshelf
	_add_bookshelf(Vector3(0.6, 0.25, -7.6))
	# A hidden letter from Lolo stashed on the desk — the room's final piece of context.
	_add_lolos_letter(Vector3(2, 0.76, -6.2))
	# Photograph on the back wall (changes after the player sets a flag).
	var locked_photo := _add_photo_frame(Vector3(2, 0.25 + 1.6, -8 + WALL_THICKNESS * 0.6), 0.0, 0.6, 0.4)
	locked_photo.caption = "Si Tala, 1972."
	locked_photo.caption_en = "Tala, 1972."
	locked_photo.alt_caption = "Si Tala, 1972. Nawala siya pagkatapos ng ilang buwan."
	locked_photo.alt_caption_en = "Tala, 1972. She disappeared a few months later."
	locked_photo.change_flag = "learned_about_tala"

	# ===== Storage: X 8 to 14, Z -8 to -2 =====
	# Dust-covered boxes.
	for i in 5:
		var b := _make_box(Vector3(0.5, 0.5, 0.5), _mat_wood_dark)
		b.position = Vector3(9 + i, 0.5, -5 - (i * 0.4))
		add_child(b)
	# A single fuse hidden among the boxes.
	_add_fuse_pickup(Vector3(13, 0.9, -4))

	# ===== Altar room: X -8 to 5, Z -8 to -2 =====
	# Altar table along the back wall
	_add_altar(Vector3(-3, 0.25, -7.4))
	# Rosary on the altar (pickup — gives story context, maybe needed late)
	_add_rosary_pickup(Vector3(-3, 0.25 + 1.1, -7.4))
	# Prayer box with the code lock — code 1973 (the year of the storm). Opening it gives
	# the family photo of Tala + the key to the locked room.
	_add_code_lock_box(Vector3(-3, 0.25 + 0.95, -7.3))
	# Behind the altar: the hidden passage door (reveals after find_passage mission).
	altar_passage_door_ref = _add_door_locked(
		Vector3(-3, 0.25, -8 + WALL_THICKNESS / 2.0),
		180.0, 1.1, "key_passage", "find_passage"
	)
	# The passage key is tucked into a small cabinet near the altar — only accessible
	# after the player has at least entered the locked room (knowledge threshold).
	_add_dresser_with_item(Vector3(-6, 0.25, -6.6), "key_passage", "")

	# ===== Hallway fuse box =====
	_add_fuse_box(Vector3(8 - 0.03, 0.25 + 1.4, 0.5))

func _add_door(pos: Vector3, rot_y_deg: float, width: float, required_key: String) -> Node3D:
	var door_root := Node3D.new()
	door_root.position = pos
	door_root.rotation.y = deg_to_rad(rot_y_deg)
	# Build the body + hinge + slab subtree detached, then attach at the end so the
	# door script's _ready sees its "Hinge" child via get_node_or_null().
	var body := StaticBody3D.new()
	body.set_script(load("res://scripts/interaction/door.gd"))
	body.name = "DoorBody"
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-width / 2.0, 0, 0)
	body.add_child(hinge)
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 2.1, 0.06)
	slab.mesh = box
	slab.material_override = _mat_wood_dark
	slab.position = Vector3(width / 2.0, 1.05, 0)
	hinge.add_child(slab)
	var col := CollisionShape3D.new()
	var box_sh := BoxShape3D.new()
	box_sh.size = Vector3(width, 2.1, 0.06)
	col.shape = box_sh
	col.position = Vector3(width / 2.0, 1.05, 0)
	hinge.add_child(col)
	body.set("required_key", required_key)
	body.set("opens_toward", Vector3(0, 1, 0))
	body.set("open_angle_degrees", 85.0)
	door_root.add_child(body)
	add_child(door_root)
	return body

func _add_door_locked(pos: Vector3, rot_y_deg: float, width: float, required_key: String, required_mission: String) -> Node3D:
	var body := _add_door(pos, rot_y_deg, width, required_key)
	body.set("required_mission", required_mission)
	return body

# ---------------------------------------------------------------------------- #
#  Furniture builders — each is small on purpose; readability > elegance.      #
# ---------------------------------------------------------------------------- #

func _make_couch(center: Vector3, rot_y_deg: float) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = deg_to_rad(rot_y_deg)
	add_child(root)
	var base := _make_box(Vector3(2.0, 0.5, 0.9), _mat_fabric)
	base.position = Vector3(0, 0.25, 0)
	root.add_child(base)
	var back := _make_box(Vector3(2.0, 0.7, 0.2), _mat_fabric)
	back.position = Vector3(0, 0.75, -0.4)
	root.add_child(back)
	for xo in [-0.95, 0.95]:
		var arm := _make_box(Vector3(0.15, 0.6, 0.9), _mat_fabric)
		arm.position = Vector3(xo, 0.5, 0)
		root.add_child(arm)
	# Static collider for the couch base.
	_add_static_collider_box(Vector3(2.0, 1.1, 0.9), center + Vector3(0, 0.55, 0), rot_y_deg)

func _add_table(center: Vector3, size: Vector3) -> void:
	var top := _make_box(Vector3(size.x, 0.06, size.z), _mat_wood_dark)
	top.position = center + Vector3(0, size.y, 0)
	add_child(top)
	for xo in [-size.x / 2.0 + 0.1, size.x / 2.0 - 0.1]:
		for zo in [-size.z / 2.0 + 0.1, size.z / 2.0 - 0.1]:
			var leg := _make_box(Vector3(0.08, size.y, 0.08), _mat_wood_dark)
			leg.position = center + Vector3(xo, size.y / 2.0, zo)
			add_child(leg)
	_add_static_collider_box(Vector3(size.x, size.y, size.z), center + Vector3(0, size.y / 2.0, 0))

func _add_tv_cabinet(center: Vector3) -> void:
	var cab := _make_box(Vector3(1.2, 0.9, 0.5), _mat_wood_dark)
	cab.position = center + Vector3(0, 0.45, 0)
	add_child(cab)
	_add_static_collider_box(Vector3(1.2, 0.9, 0.5), center + Vector3(0, 0.45, 0))
	# CRT TV on top
	var tv := _make_box(Vector3(0.7, 0.55, 0.55), _mat_wood_dark)
	tv.position = center + Vector3(0, 1.2, 0)
	add_child(tv)
	# Screen face (slight dark reflective quad)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.02, 0.03, 0.05)
	screen_mat.roughness = 0.1
	screen_mat.metallic = 0.1
	var screen := _make_box(Vector3(0.6, 0.42, 0.02), screen_mat)
	screen.position = center + Vector3(0, 1.22, 0.28)
	add_child(screen)
	# Antenna (two thin boxes).
	for i in 2:
		var ant := _make_box(Vector3(0.02, 0.6, 0.02), _mat_metal)
		ant.position = center + Vector3(-0.15 + i * 0.3, 1.75, -0.1)
		ant.rotation.z = deg_to_rad(-20 if i == 0 else 20)
		add_child(ant)

func _add_bookshelf(center: Vector3) -> void:
	var shelf := _make_box(Vector3(1.4, 1.9, 0.3), _mat_wood_dark)
	shelf.position = center + Vector3(0, 0.95, 0)
	add_child(shelf)
	_add_static_collider_box(Vector3(1.4, 1.9, 0.3), center + Vector3(0, 0.95, 0))
	# Row of "books" (colored boxes).
	var colors := [Color(0.5, 0.2, 0.1), Color(0.3, 0.2, 0.15), Color(0.2, 0.15, 0.1), Color(0.4, 0.3, 0.2), Color(0.55, 0.4, 0.25)]
	for row in 3:
		var y := 0.3 + row * 0.55
		for i in 6:
			var book := _make_box(Vector3(0.1, 0.4, 0.22), _make_mat(colors[(i + row) % colors.size()], 0.95, 0.0))
			book.position = center + Vector3(-0.6 + i * 0.21, y, 0)
			add_child(book)

func _add_dining_set(center: Vector3) -> void:
	_add_table(center, Vector3(1.8, 0.75, 1.0))
	# Four chairs around the table.
	var offsets := [
		[Vector3(0.7, 0, 0.65), 180.0],
		[Vector3(-0.7, 0, 0.65), 180.0],
		[Vector3(0.7, 0, -0.65), 0.0],
		[Vector3(-0.7, 0, -0.65), 0.0],
	]
	for pair in offsets:
		_add_chair(center + pair[0], pair[1])

func _add_chair(pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(rot_y_deg)
	add_child(root)
	var seat := _make_box(Vector3(0.4, 0.08, 0.4), _mat_wood_dark)
	seat.position = Vector3(0, 0.5, 0)
	root.add_child(seat)
	var back := _make_box(Vector3(0.4, 0.6, 0.06), _mat_wood_dark)
	back.position = Vector3(0, 0.8, 0.18)
	root.add_child(back)
	for xo in [-0.17, 0.17]:
		for zo in [-0.17, 0.17]:
			var leg := _make_box(Vector3(0.05, 0.5, 0.05), _mat_wood_dark)
			leg.position = Vector3(xo, 0.25, zo)
			root.add_child(leg)
	_add_static_collider_box(Vector3(0.4, 0.9, 0.4), pos + Vector3(0, 0.45, 0), rot_y_deg)

func _add_kitchen_counter(center: Vector3) -> void:
	var counter := _make_box(Vector3(3.0, 0.9, 0.6), _mat_wood_dark)
	counter.position = center + Vector3(0, 0.45, 0)
	add_child(counter)
	_add_static_collider_box(Vector3(3.0, 0.9, 0.6), center + Vector3(0, 0.45, 0))
	# Sink (dark inset).
	var sink := _make_box(Vector3(0.6, 0.15, 0.4), _make_mat(Color(0.2, 0.22, 0.22), 0.3, 0.5))
	sink.position = center + Vector3(-0.6, 0.92, 0)
	add_child(sink)

func _add_fridge(center: Vector3) -> void:
	var body := _make_box(Vector3(0.75, 1.7, 0.7), _make_mat(Color(0.85, 0.85, 0.82), 0.4, 0.1))
	body.position = center + Vector3(0, 0.85, 0)
	add_child(body)
	_add_static_collider_box(Vector3(0.75, 1.7, 0.7), center + Vector3(0, 0.85, 0))
	# Handle.
	var handle := _make_box(Vector3(0.04, 0.5, 0.04), _mat_metal)
	handle.position = center + Vector3(0.3, 1.0, 0.37)
	add_child(handle)

func _add_stove(center: Vector3) -> void:
	var body := _make_box(Vector3(0.7, 0.85, 0.6), _make_mat(Color(0.5, 0.48, 0.46), 0.4, 0.4))
	body.position = center + Vector3(0, 0.42, 0)
	add_child(body)
	_add_static_collider_box(Vector3(0.7, 0.85, 0.6), center + Vector3(0, 0.42, 0))

func _add_rug(center: Vector3) -> void:
	var rug := _make_box(Vector3(2.4, 0.03, 1.6), _make_mat(Color(0.45, 0.25, 0.2), 0.95, 0.0))
	rug.position = center
	add_child(rug)

func _add_bed(center: Vector3) -> void:
	var frame := _make_box(Vector3(1.4, 0.35, 2.0), _mat_wood_dark)
	frame.position = center + Vector3(0, 0.18, 0)
	add_child(frame)
	_add_static_collider_box(Vector3(1.4, 0.35, 2.0), center + Vector3(0, 0.18, 0))
	var mattress := _make_box(Vector3(1.3, 0.2, 1.9), _make_mat(Color(0.9, 0.85, 0.78), 0.95, 0.0))
	mattress.position = center + Vector3(0, 0.45, 0)
	add_child(mattress)
	var pillow := _make_box(Vector3(1.1, 0.1, 0.3), _make_mat(Color(0.95, 0.9, 0.82), 0.95, 0.0))
	pillow.position = center + Vector3(0, 0.6, -0.75)
	add_child(pillow)
	# Headboard
	var head := _make_box(Vector3(1.4, 0.9, 0.08), _mat_wood_dark)
	head.position = center + Vector3(0, 0.7, -1.0)
	add_child(head)

func _add_nightstand(pos: Vector3) -> void:
	var body := _make_box(Vector3(0.5, 0.6, 0.4), _mat_wood_dark)
	body.position = pos + Vector3(0, 0.3, 0)
	add_child(body)
	_add_static_collider_box(Vector3(0.5, 0.6, 0.4), pos + Vector3(0, 0.3, 0))
	# A small reading lamp.
	var lamp_base := _make_box(Vector3(0.12, 0.08, 0.12), _mat_metal)
	lamp_base.position = pos + Vector3(0, 0.64, 0)
	add_child(lamp_base)
	var shade := _make_cone(0.18, 0.22, Color(0.85, 0.78, 0.4))
	shade.position = pos + Vector3(0, 0.84, 0)
	add_child(shade)

func _add_dresser_with_item(center: Vector3, spawn_item: String, completes_mission_on_find: String) -> void:
	# Drawer interactable the player can open — contents revealed on open.
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/interaction/drawer.gd"))
	root.name = "Dresser_" + spawn_item
	root.position = center
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# Dresser frame
	var frame := _make_box(Vector3(1.0, 1.0, 0.5), _mat_wood_dark)
	frame.position = Vector3(0, 0.5, 0)
	body.add_child(frame)
	# Handle
	var handle := _make_box(Vector3(0.2, 0.03, 0.03), _mat_metal)
	handle.position = Vector3(0, 0.5, 0.27)
	body.add_child(handle)
	# Collider on root (not inside body) so the drawer slides visually but collider stays put.
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 0.5)
	col.shape = bs
	col.position = Vector3(0, 0.5, 0)
	root.add_child(col)
	# Configure contents BEFORE entering the tree so _ready sees them.
	root.set("spawn_item_id", spawn_item)
	root.set("open_offset", Vector3(0, 0, 0.3))
	root.set("completes_mission_on_find", completes_mission_on_find)
	# Now attach to the world so _ready fires with the full subtree in place.
	add_child(root)

func _add_photo_frame(pos: Vector3, rot_y_deg: float, width: float, height: float) -> Node:
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/interaction/photograph.gd"))
	root.name = "Photograph"
	root.position = pos
	root.rotation.y = deg_to_rad(rot_y_deg)
	# Frame
	var frame := _make_box(Vector3(width + 0.04, height + 0.04, 0.04), _mat_wood_dark)
	frame.name = "Frame"
	frame.position = Vector3(0, 0, 0)
	root.add_child(frame)
	# Collider so the raycast hits it
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width + 0.04, height + 0.04, 0.05)
	col.shape = bs
	root.add_child(col)
	add_child(root)
	return root

func _add_desk(center: Vector3) -> void:
	var top := _make_box(Vector3(1.4, 0.06, 0.7), _mat_wood_dark)
	top.position = center + Vector3(0, 0.75, 0)
	add_child(top)
	for xo in [-0.6, 0.6]:
		var leg := _make_box(Vector3(0.08, 0.75, 0.5), _mat_wood_dark)
		leg.position = center + Vector3(xo, 0.37, 0)
		add_child(leg)
	_add_static_collider_box(Vector3(1.4, 0.8, 0.7), center + Vector3(0, 0.4, 0))

func _add_altar(center: Vector3) -> void:
	# Low altar table + a few religious items.
	var table := _make_box(Vector3(2.2, 0.85, 0.7), _mat_altar)
	table.position = center + Vector3(0, 0.42, 0)
	add_child(table)
	_add_static_collider_box(Vector3(2.2, 0.85, 0.7), center + Vector3(0, 0.42, 0))
	# Candles (two cylinders with warm light).
	for xo in [-0.6, 0.6]:
		var candle := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.04
		cyl.height = 0.22
		candle.mesh = cyl
		candle.material_override = _make_mat(Color(0.95, 0.88, 0.72), 0.9, 0.0)
		candle.position = center + Vector3(xo, 0.95, 0.1)
		add_child(candle)
		var flame_light := OmniLight3D.new()
		flame_light.omni_range = 2.2
		flame_light.light_color = Color(1.0, 0.6, 0.25)
		flame_light.light_energy = 0.9
		flame_light.position = center + Vector3(xo, 1.1, 0.1)
		add_child(flame_light)
		altar_lights.append(flame_light)
	# Central crucifix-like upright.
	var upright := _make_box(Vector3(0.06, 0.5, 0.06), _mat_wood_dark)
	upright.position = center + Vector3(0, 1.15, 0)
	add_child(upright)
	var cross := _make_box(Vector3(0.3, 0.06, 0.06), _mat_wood_dark)
	cross.position = center + Vector3(0, 1.25, 0)
	add_child(cross)

func _add_rosary_pickup(pos: Vector3) -> void:
	var item := StaticBody3D.new()
	item.set_script(load("res://scripts/interaction/pickup_item.gd"))
	item.name = "RosaryPickup"
	item.position = pos
	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	mesh.mesh = sph
	mesh.material_override = _make_mat(Color(0.9, 0.85, 0.95), 0.5, 0.2)
	mesh.name = "Mesh"
	item.add_child(mesh)
	var col := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.1
	col.shape = ss
	item.add_child(col)
	item.set("item_id", "rosary")
	add_child(item)

func _add_fuse_pickup(pos: Vector3) -> void:
	var item := StaticBody3D.new()
	item.set_script(load("res://scripts/interaction/pickup_item.gd"))
	item.name = "FusePickup"
	item.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 0.14)
	mesh.mesh = box
	mesh.material_override = _make_mat(Color(0.75, 0.6, 0.3), 0.6, 0.4)
	mesh.name = "Mesh"
	item.add_child(mesh)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.14, 0.14, 0.18)
	col.shape = bs
	item.add_child(col)
	item.set("item_id", "fuse")
	add_child(item)

func _add_fuse_box(pos: Vector3) -> void:
	# Visual box on the wall + two interactables: fuse slot and the switch.
	var housing := _make_box(Vector3(0.4, 0.5, 0.08), _make_mat(Color(0.5, 0.47, 0.42), 0.6, 0.3))
	housing.position = pos
	add_child(housing)
	# Fuse slot (StaticBody3D w/ fuse_slot script).
	fuse_slot_ref = StaticBody3D.new()
	fuse_slot_ref.set_script(load("res://scripts/puzzles/fuse_slot.gd"))
	fuse_slot_ref.name = "FuseSlot"
	fuse_slot_ref.position = pos + Vector3(0, 0.08, -0.03)
	var fs_col := CollisionShape3D.new()
	var fs_bs := BoxShape3D.new()
	fs_bs.size = Vector3(0.15, 0.18, 0.1)
	fs_col.shape = fs_bs
	fuse_slot_ref.add_child(fs_col)
	# Fuse mesh (hidden until installed)
	var fuse_mesh := _make_box(Vector3(0.08, 0.1, 0.08), _make_mat(Color(0.75, 0.6, 0.3), 0.6, 0.4))
	fuse_mesh.name = "FuseMesh"
	fuse_slot_ref.add_child(fuse_mesh)
	add_child(fuse_slot_ref)
	# Switch (StaticBody3D w/ light_switch script)
	fuse_box_switch_ref = StaticBody3D.new()
	fuse_box_switch_ref.set_script(load("res://scripts/interaction/light_switch.gd"))
	fuse_box_switch_ref.name = "FuseBoxSwitch"
	fuse_box_switch_ref.position = pos + Vector3(0, -0.1, -0.03)
	var sw_col := CollisionShape3D.new()
	var sw_bs := BoxShape3D.new()
	sw_bs.size = Vector3(0.15, 0.18, 0.1)
	sw_col.shape = sw_bs
	fuse_box_switch_ref.add_child(sw_col)
	# Switch toggle lever (visual).
	var lever := _make_box(Vector3(0.04, 0.08, 0.02), _mat_metal)
	lever.position = Vector3(0, 0, 0.05)
	fuse_box_switch_ref.add_child(lever)
	add_child(fuse_box_switch_ref)
	# Hooks: switch requires story flag "fuse_installed" (sets completes_mission to "restore_power").
	fuse_box_switch_ref.set("required_item", "")
	fuse_box_switch_ref.set("required_flag", "fuse_installed")
	fuse_box_switch_ref.set("start_on", false)
	fuse_box_switch_ref.set("completes_mission", "restore_power")

func _add_code_lock_box(pos: Vector3) -> void:
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/puzzles/code_lock.gd"))
	root.name = "CodeLockBox"
	root.position = pos
	var mesh := _make_box(Vector3(0.35, 0.18, 0.28), _mat_wood_dark)
	root.add_child(mesh)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.4, 0.22, 0.32)
	col.shape = bs
	root.add_child(col)
	root.set("code", "1973")
	root.set("hint_tagalog", "Petsa sa likod ng talaarawan — ang taon ng unos.")
	root.set("hint_english", "A date from the diary — the year of the storm.")
	root.set("requires_item", "diary")
	root.set("spawn_items", ["photo_tala", "key_locked_room"] as Array[String])
	root.set("completes_mission", "diary_puzzle")
	add_child(root)

func _add_diary_note(pos: Vector3) -> void:
	# A readable "note" that is also the diary pickup — reading it shows the entries,
	# adds the "diary" inventory item, and completes find_diary.
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/interaction/note.gd"))
	root.name = "DiaryNote"
	root.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.04, 0.3)
	mesh.mesh = box
	mesh.material_override = _mat_wood_dark
	root.add_child(mesh)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.26, 0.07, 0.34)
	col.shape = bs
	root.add_child(col)
	root.set("title", "Talaarawan ni Lola Pacita")
	root.set("tagalog_text", "17 Hunyo 1972 — Nilipad ni Tala ang kuwintas sa dagat. Umiyak siya. Hinawakan ko siya hanggang sa katahimikan.\n\n3 Agosto 1973 — Dumating ang unos. Ang pinakamalaking tagagamot sa buong Daet. Hindi na siya umuwi.\n\n4 Agosto 1973 — Hinanap namin siya. Hindi namin siya nahanap.\n\n(Pangalawang pahina — nasasagad: '1973. 1973. 1973.' sinulat nang paulit-ulit).")
	root.set("english_text", "17 June 1972 — Tala threw her necklace into the sea. She cried. I held her until she went quiet.\n\n3 August 1973 — The storm came. The biggest in all of Daet. She did not come home.\n\n4 August 1973 — We looked. We did not find her.\n\n(Second page, well-worn: '1973. 1973. 1973.' written over and over).")
	root.set("adds_item", "diary")
	root.set("completes_mission", "find_diary")
	add_child(root)

func _add_lolos_letter(pos: Vector3) -> void:
	# A rolled note on the desk.
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/interaction/note.gd"))
	root.name = "LolosLetter"
	root.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.02, 0.22)
	mesh.mesh = box
	mesh.material_override = _mat_paper
	root.add_child(mesh)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.35, 0.05, 0.25)
	col.shape = bs
	root.add_child(col)
	root.set("title", "Sulat ni Lolo")
	root.set("tagalog_text", "Kung mababasa mo ito, apo, ibig sabihin napunta ka na sa kuwartong ito.\n\nMay kapatid ang iyong Ina. Tala ang kanyang pangalan. Nawala siya sa isang gabi noong 1973. Hindi namin siya natagpuan. Ang sabi namin sa iyong Ina, nakalimutan. Ang sabi namin sa iyong Lola, ito ang pinakamahusay. Hindi iyon tama.\n\nMay kahon sa aking mesa. Ang code ay ang taon ng unos. Buksan mo lang kung handa kang malaman.")
	root.set("english_text", "If you are reading this, child, it means you have come to this room.\n\nYour mother had a sister. Her name was Tala. She disappeared one night in 1973. We never found her. We told your mother to forget. We told your lola it was best. It was not right.\n\nThere is a box on my desk. The code is the year of the storm. Open it only if you are ready to know.")
	root.set("adds_item", "letter_lolo")
	root.set("story_flag_to_set", "learned_about_tala")
	add_child(root)

# ---------------------------------------------------------------------------- #
#  Lights, interactables, horror events, mission triggers                      #
# ---------------------------------------------------------------------------- #

func _build_interactables_and_lights() -> void:
	# Hallway ceiling lights.
	for z_pos in [-5.0, 0.0, 3.0]:
		var lite := OmniLight3D.new()
		lite.omni_range = 5.5
		lite.light_color = Color(1.0, 0.85, 0.65)
		lite.light_energy = 0.9
		lite.position = Vector3(4, 0.25 + WALL_HEIGHT - 0.5, z_pos)
		add_child(lite)
		hall_lights.append(lite)

	# Kitchen light (brighter).
	var klite := OmniLight3D.new()
	klite.omni_range = 6.0
	klite.light_color = Color(1.0, 0.88, 0.68)
	klite.light_energy = 1.1
	klite.position = Vector3(4, 0.25 + WALL_HEIGHT - 0.4, 7)
	add_child(klite)
	kitchen_lights.append(klite)

	# Sala light.
	var slite := OmniLight3D.new()
	slite.omni_range = 5.5
	slite.light_color = Color(1.0, 0.82, 0.58)
	slite.light_energy = 0.8
	slite.position = Vector3(-4, 0.25 + WALL_HEIGHT - 0.4, 7)
	add_child(slite)
	kitchen_lights.append(slite)

	# Moonlight directional (outside, slightly cool).
	var dir_light := DirectionalLight3D.new()
	dir_light.light_color = Color(0.65, 0.75, 0.9)
	dir_light.light_energy = 0.3
	dir_light.rotation = Vector3(deg_to_rad(-55), deg_to_rad(30), 0)
	dir_light.shadow_enabled = false  # mobile — rely on baked-feel and omni shadows
	add_child(dir_light)

	# Connect fuse-box switch to the hallway lights (which start off; see _apply_lights).
	if fuse_box_switch_ref != null:
		# Set NodePath array to hall lights.
		var paths: Array[NodePath] = []
		for l in hall_lights:
			paths.append(fuse_box_switch_ref.get_path_to(l))
		fuse_box_switch_ref.set("light_paths", paths)
		# Store a story-flag requirement so the switch is "dead" until fuse_installed is set.
		# We handle this through required_item="" + a listener: see MissionManager.flag_set in game_controller.gd.

	# Player spawn marker at the gate.
	player_spawn_marker = Marker3D.new()
	player_spawn_marker.name = "PlayerSpawn"
	player_spawn_marker.position = Vector3(4, 1.4, 18.5)
	add_child(player_spawn_marker)

	# Entity spawn points.
	entity_spawn_hall = Marker3D.new()
	entity_spawn_hall.name = "EntitySpawnHall"
	entity_spawn_hall.position = Vector3(4, 0.25, -1.5)
	add_child(entity_spawn_hall)
	entity_spawn_altar = Marker3D.new()
	entity_spawn_altar.name = "EntitySpawnAltar"
	entity_spawn_altar.position = Vector3(-3, 0.25, -7.0)
	add_child(entity_spawn_altar)

	# A simple WorldEnvironment with fog for atmosphere.
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color(0.03, 0.03, 0.06)
	proc.sky_horizon_color = Color(0.05, 0.05, 0.08)
	proc.ground_bottom_color = Color(0.01, 0.01, 0.02)
	proc.ground_horizon_color = Color(0.05, 0.05, 0.08)
	proc.sun_angle_max = 20.0
	sky.sky_material = proc
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_density = 0.03
	env.fog_light_color = Color(0.08, 0.08, 0.12)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	env_node.environment = env
	add_child(env_node)

func _build_horror_events() -> void:
	# 1) Silhouette at end of hallway.
	var silhouette := _make_entity_figure(Vector3(4, 0.25, -1.5))
	silhouette.visible = false
	silhouette.name = "Silhouette"
	add_child(silhouette)
	var sil_scare := Node3D.new()
	sil_scare.set_script(load("res://scripts/horror/silhouette_scare.gd"))
	sil_scare.name = "SilhouetteScare"
	add_child(sil_scare)
	sil_scare.set("event_id", "hallway_silhouette")
	sil_scare.set("figure_path", sil_scare.get_path_to(silhouette))
	sil_scare.set("required_mission", "night_noise")

	# 2) Door creak scare — the locked room door creaks after night_noise.
	var door_scare := Node3D.new()
	door_scare.set_script(load("res://scripts/horror/door_scare.gd"))
	door_scare.name = "LockedRoomCreak"
	add_child(door_scare)
	door_scare.set("event_id", "locked_room_creak")
	door_scare.set("door_path", door_scare.get_path_to(locked_room_door_ref))
	door_scare.set("mode", 0)   # creak_open
	door_scare.set("required_mission", "night_noise")

	# 3) Radio static — kitchen area.
	var radio_mesh := _make_box(Vector3(0.3, 0.2, 0.2), _mat_wood_dark)
	radio_mesh.position = Vector3(5, 1.3, 5.0)
	radio_mesh.name = "Radio"
	add_child(radio_mesh)
	var radio_scare := Node3D.new()
	radio_scare.set_script(load("res://scripts/horror/radio_scare.gd"))
	radio_scare.name = "KitchenRadioScare"
	add_child(radio_scare)
	radio_scare.set("event_id", "kitchen_radio")
	radio_scare.set("radio_path", radio_scare.get_path_to(radio_mesh))
	radio_scare.set("nearby_light_path", radio_scare.get_path_to(kitchen_lights[0]))
	radio_scare.set("required_mission", "find_diary")

func _build_mission_triggers() -> void:
	# Entering the yard — completes "arrive".
	_add_mission_trigger(
		Vector3(4, 1.0, 13),
		Vector3(5, 2.0, 2),
		"arrive", "", "", "", ""
	)
	# Entering the sala — completes "explore_living_room" if the player has at least greeted Lola.
	_add_mission_trigger(
		Vector3(-4, 1.0, 7),
		Vector3(6, 2.0, 4),
		"explore_living_room", "", "", "greet_lola", ""
	)
	# NPCs: Lola (always available), Lolo (only after exploring the sala).
	_add_lola_npc()
	_add_lolo_npc()
	# Entering the hallway during night_noise — completes the mission and fires a silhouette.
	_add_mission_trigger(
		Vector3(4, 1.0, 1),
		Vector3(2, 2.0, 4),
		"night_noise", "", "", "night_noise", "hallway_silhouette"
	)
	# Entering the locked room — completes "enter_locked_room".
	_add_mission_trigger(
		Vector3(2.5, 1.0, -5),
		Vector3(5, 2.0, 5),
		"enter_locked_room", "", "entered_locked_room", "", ""
	)
	# Entering the altar area — triggers the mandatory final beat.
	_add_mission_trigger(
		Vector3(-3, 1.0, -5),
		Vector3(10, 2.0, 6),
		"", "", "entered_altar", "find_passage", ""
	)
	# Behind the altar — the ending controller takes over when the player walks
	# through the passage door.
	_add_ending_zone(Vector3(-3, 1.0, -10.0), Vector3(3, 2.5, 3))

func _add_mission_trigger(center: Vector3, size: Vector3, completes_mission: String, starts_mission: String, sets_flag: String, requires_mission: String, trigger_horror: String) -> void:
	var area := Area3D.new()
	area.set_script(load("res://scripts/missions/mission_trigger.gd"))
	area.name = "MissionTrigger_" + str(completes_mission + sets_flag + trigger_horror)
	area.position = center
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	area.add_child(col)
	area.collision_layer = 1 << 4
	area.collision_mask = 1 << 1  # player layer
	add_child(area)
	area.set("completes_mission", completes_mission)
	area.set("starts_mission", starts_mission)
	area.set("sets_flag", sets_flag)
	area.set("requires_mission", requires_mission)
	area.set("trigger_horror", trigger_horror)

func _add_ending_zone(center: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.set_script(load("res://scripts/missions/ending_zone.gd"))
	area.name = "EndingZone"
	area.position = center
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.shape = bs
	area.add_child(col)
	area.collision_layer = 1 << 4
	area.collision_mask = 1 << 1
	add_child(area)

# ---------------------------------------------------------------------------- #
#  NPCs                                                                        #
# ---------------------------------------------------------------------------- #

func _add_lola_npc() -> void:
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/interaction/dialogue_trigger.gd"))
	root.name = "LolaNPC"
	# Standing on the front porch so the apo can greet her the moment they arrive.
	root.position = Vector3(2.5, 0.25, 11.5)
	root.rotation.y = deg_to_rad(180)   # facing the player as they approach
	# Visuals: body + head.
	_add_simple_person(root, Color(0.3, 0.25, 0.3), Color(0.85, 0.72, 0.6))
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.3
	cs.height = 1.6
	col.shape = cs
	col.position = Vector3(0, 0.85, 0)
	root.add_child(col)
	root.set("dialogue_id", "lola_intro")
	root.set("trigger_label", "Kausapin si Lola")
	root.set("trigger_label_en", "Talk to Lola")
	add_child(root)

func _add_lolo_npc() -> void:
	var root := StaticBody3D.new()
	root.set_script(load("res://scripts/interaction/dialogue_trigger.gd"))
	root.name = "LoloNPC"
	root.position = Vector3(2, 0.25, 8)
	_add_simple_person(root, Color(0.35, 0.3, 0.22), Color(0.7, 0.55, 0.4))
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.3
	cs.height = 1.65
	col.shape = cs
	col.position = Vector3(0, 0.87, 0)
	root.add_child(col)
	root.set("dialogue_id", "lolo_intro")
	root.set("trigger_label", "Kausapin si Lolo")
	root.set("trigger_label_en", "Talk to Lolo")
	root.set("required_mission", "explore_living_room")
	add_child(root)

func _add_simple_person(root: Node3D, shirt_color: Color, skin_color: Color) -> void:
	# Low-poly figure — torso, legs, arms, head.
	var torso := _make_box(Vector3(0.5, 0.7, 0.3), _make_mat(shirt_color, 0.95, 0.0))
	torso.position = Vector3(0, 1.0, 0)
	root.add_child(torso)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.14
	sph.height = 0.28
	head.mesh = sph
	head.material_override = _make_mat(skin_color, 0.95, 0.0)
	head.position = Vector3(0, 1.55, 0)
	root.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_sph := SphereMesh.new()
	hair_sph.radius = 0.145
	hair_sph.height = 0.1
	hair.mesh = hair_sph
	hair.material_override = _make_mat(Color(0.85, 0.85, 0.9), 0.95, 0.0)
	hair.position = Vector3(0, 1.65, -0.02)
	root.add_child(hair)
	# Legs
	for xo in [-0.1, 0.1]:
		var leg := _make_box(Vector3(0.14, 0.65, 0.2), _make_mat(Color(0.18, 0.18, 0.22), 0.95, 0.0))
		leg.position = Vector3(xo, 0.33, 0)
		root.add_child(leg)
	# Arms
	for xo in [-0.3, 0.3]:
		var arm := _make_box(Vector3(0.1, 0.6, 0.2), _make_mat(shirt_color, 0.95, 0.0))
		arm.position = Vector3(xo, 1.0, 0.0)
		root.add_child(arm)

func _make_entity_figure(pos: Vector3) -> Node3D:
	# A tall, dark figure — used for silhouette scares.
	var root := Node3D.new()
	root.name = "EntityFigure"
	root.position = pos
	var torso := _make_box(Vector3(0.5, 1.1, 0.3), _make_mat(Color(0.02, 0.02, 0.03), 0.98, 0.0))
	torso.position = Vector3(0, 1.1, 0)
	root.add_child(torso)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.32
	head.mesh = sph
	head.material_override = _make_mat(Color(0.03, 0.03, 0.04), 0.98, 0.0)
	head.position = Vector3(0, 1.78, 0)
	root.add_child(head)
	return root

# ---------------------------------------------------------------------------- #
#  Ambient / final touches                                                     #
# ---------------------------------------------------------------------------- #

func _build_ambience() -> void:
	# Dust particles throughout the house (one large GPUParticles).
	var dust := GPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 10.0
	dust.one_shot = false
	dust.preprocess = 5.0
	dust.position = Vector3(4, 1.8, 1)
	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.gravity = Vector3(0, -0.03, 0)
	proc_mat.initial_velocity_min = 0.0
	proc_mat.initial_velocity_max = 0.1
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = Vector3(10, 2, 8)
	proc_mat.scale_min = 0.3
	proc_mat.scale_max = 1.2
	proc_mat.color = Color(0.8, 0.75, 0.6, 0.2)
	dust.process_material = proc_mat
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(0.02, 0.02)
	var dust_vis_mat := StandardMaterial3D.new()
	dust_vis_mat.albedo_color = Color(0.9, 0.85, 0.7, 0.35)
	dust_vis_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_vis_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_vis_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust_mesh.material = dust_vis_mat
	dust.draw_pass_1 = dust_mesh
	add_child(dust)

# ---------------------------------------------------------------------------- #
#  Primitives / helpers                                                        #
# ---------------------------------------------------------------------------- #

func _make_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	return m

func _make_cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	m.mesh = cone
	m.material_override = _make_mat(color, 0.95, 0.0)
	return m

func _make_quad_mesh(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> ArrayMesh:
	# Builds a flat quad as two triangles — used for the roof planes.
	var vertices := PackedVector3Array([a, b, c, a, c, d])
	var normal := (b - a).cross(c - a).normalized()
	var normals := PackedVector3Array([normal, normal, normal, normal, normal, normal])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _add_wall(a: Vector3, b: Vector3, exterior: bool) -> void:
	# Build a box between the two corners.
	var size := Vector3(absf(b.x - a.x), absf(b.y - a.y), absf(b.z - a.z))
	size.x = maxf(size.x, WALL_THICKNESS)
	size.y = maxf(size.y, 0.05)
	size.z = maxf(size.z, WALL_THICKNESS)
	var center := (a + b) * 0.5
	var mat: StandardMaterial3D = _mat_wall_exterior if exterior else _mat_wall_interior
	var wall := _make_box(size, mat)
	wall.position = center
	add_child(wall)
	_add_static_collider_box(size, center)

func _add_static_collider_box(size: Vector3, center: Vector3, rot_y_deg: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	body.rotation.y = deg_to_rad(rot_y_deg)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	add_child(body)

func _add_floor_collider(size: Vector3, center: Vector3) -> void:
	_add_static_collider_box(size, center)

func _add_tree(pos: Vector3) -> void:
	var trunk := _make_box(Vector3(0.3, 2.4, 0.3), _mat_wood_dark)
	trunk.position = pos + Vector3(0, 1.2, 0)
	add_child(trunk)
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.3
	sph.height = 2.6
	canopy.mesh = sph
	canopy.material_override = _make_mat(Color(0.12, 0.22, 0.1), 0.95, 0.0)
	canopy.position = pos + Vector3(0, 3.2, 0)
	add_child(canopy)
	_add_static_collider_box(Vector3(0.4, 2.4, 0.4), pos + Vector3(0, 1.2, 0))
