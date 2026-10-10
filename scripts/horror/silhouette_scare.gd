extends "res://scripts/horror/horror_event.gd"
## Silhouette-at-the-end-of-the-hallway scare.
## Spawns a dark figure at a target marker, holds for a moment, then dissolves away.
class_name SilhouetteScare

@export var figure_path: NodePath          # a Node3D to show
@export var hold_time: float = 1.4
@export var fade_time: float = 0.8
@export var play_whisper: bool = true
@export var trigger_shake: bool = false

func _run() -> void:
	var figure: Node3D = get_node_or_null(figure_path)
	if figure == null:
		return
	figure.visible = true
	# Reset materials to full opacity.
	_set_figure_alpha(figure, 1.0)
	if play_whisper:
		AudioManager.play_sfx_3d("whisper.wav", figure, -2.0)
	if trigger_shake:
		HorrorManager.shake_camera(0.1, 0.6)
	await get_tree().create_timer(hold_time).timeout
	# Fade away.
	var steps := 20
	for i in steps:
		var t := 1.0 - float(i + 1) / steps
		_set_figure_alpha(figure, t)
		await get_tree().create_timer(fade_time / steps).timeout
	figure.visible = false

func _set_figure_alpha(figure: Node3D, alpha: float) -> void:
	for child in figure.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var mat: Material = mesh.material_override
			if mat == null:
				var new_mat := StandardMaterial3D.new()
				new_mat.albedo_color = Color(0.02, 0.02, 0.03, alpha)
				new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh.material_override = new_mat
			elif mat is StandardMaterial3D:
				var std_mat := mat as StandardMaterial3D
				var c: Color = std_mat.albedo_color
				c.a = alpha
				std_mat.albedo_color = c
