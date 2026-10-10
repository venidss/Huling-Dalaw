extends "res://scripts/horror/horror_event.gd"
## Radio-static scare: a radio in the house crackles on by itself, plays whispers, flickers
## a nearby light, then falls silent. The radio must be a Node3D in the scene with a
## child Light3D (optional) and an AudioStreamPlayer3D (optional).
class_name RadioScare

@export var radio_path: NodePath
@export var nearby_light_path: NodePath
@export var duration: float = 3.2

func _run() -> void:
	var radio: Node3D = get_node_or_null(radio_path)
	if radio == null:
		return
	AudioManager.play_sfx_3d("radio_static.wav", radio, -1.0)
	var light: Light3D = get_node_or_null(nearby_light_path) as Light3D
	if light != null:
		# Flicker a few times.
		for i in 6:
			light.visible = i % 2 == 0
			await get_tree().create_timer(0.12).timeout
		light.visible = true
	else:
		await get_tree().create_timer(duration).timeout
	AudioManager.play_sfx_3d("whisper.wav", radio, -3.0)
