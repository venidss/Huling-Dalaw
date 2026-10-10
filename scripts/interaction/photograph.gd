extends StaticBody3D
## Photograph interactable. Shows a close-up image panel (procedurally painted) with
## caption text. May change its contents after a story flag is set — the perfect
## quiet horror beat: a family photo subtly rewritten after the player looks away.
class_name PhotographInteractable

@export var caption: String = "Lumang litrato"
@export var caption_en: String = "Old photograph"
@export var alt_caption: String = ""         # shown instead if change_flag is set
@export var alt_caption_en: String = ""
@export var change_flag: String = ""         # story flag that changes caption + visuals
@export var completes_mission: String = ""
@export var sets_flag_on_read: String = ""
@export var tone_a: Color = Color(0.75, 0.65, 0.5)
@export var tone_b: Color = Color(0.35, 0.25, 0.2)
@export var alt_tone_a: Color = Color(0.35, 0.1, 0.1)
@export var alt_tone_b: Color = Color(0.08, 0.03, 0.03)

var frame_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 0
	call_deferred("_bind_frame")
	MissionManager.flag_set.connect(_on_flag_set)

func _bind_frame() -> void:
	frame_mesh = get_node_or_null("Frame") as MeshInstance3D
	_refresh_appearance()

func _on_flag_set(flag: String, _val: Variant) -> void:
	if flag == change_flag:
		_refresh_appearance()

func _refresh_appearance() -> void:
	if frame_mesh == null:
		return
	var active_alt := change_flag != "" and MissionManager.has_flag(change_flag)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = (alt_tone_a if active_alt else tone_a).lerp((alt_tone_b if active_alt else tone_b), 0.5)
	mat.roughness = 0.85
	mat.emission_enabled = active_alt
	if active_alt:
		mat.emission = Color(0.1, 0.0, 0.0)
		mat.emission_energy_multiplier = 0.15
	frame_mesh.material_override = mat

func get_interact_label() -> String:
	if Settings.show_english_subtitles:
		return "Suriin ang litrato / Examine photograph"
	return "Suriin ang litrato"

func interact(_player: Node) -> void:
	var active_alt := change_flag != "" and MissionManager.has_flag(change_flag)
	var cap := alt_caption if (active_alt and alt_caption != "") else caption
	var cap_en := alt_caption_en if (active_alt and alt_caption_en != "") else caption_en
	for ui in get_tree().get_nodes_in_group("note_readers"):
		if ui.has_method("show_note"):
			ui.show_note("Litrato", cap, cap_en)
	if _player.has_method("set_can_move"):
		_player.set_can_move(false)
	AudioManager.play_sfx("paper_rustle.wav", -6.0)
	if sets_flag_on_read != "":
		MissionManager.set_flag(sets_flag_on_read, true)
	if completes_mission != "":
		MissionManager.complete(completes_mission)
