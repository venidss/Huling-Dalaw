extends Area3D
## Triggered when the player steps into the final altar passage area. Shows the
## ending choice dialogue; the dialogue sets GameState.chosen_ending and after the
## dialogue finishes the HUD displays the appropriate ending screen.
class_name EndingZone

var _fired: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _on_body_entered(body: Node3D) -> void:
	if _fired or not body.is_in_group("player"):
		return
	if not MissionManager.is_at_or_past("find_passage"):
		return
	_fired = true
	MissionManager.complete("find_passage")
	MissionManager.start_mission("final_truth")
	# Fade the ambient music to something more final.
	AudioManager.stop_music()
	AudioManager.play_music("final_theme.wav", 2.0)
	# Lock the player in place and start the ending choice dialogue.
	var p := body
	if p.has_method("set_can_move"):
		p.set_can_move(false)
	DialogueManager.start("ending_choice")

func _on_dialogue_finished(id: String) -> void:
	if id != "ending_choice":
		return
	# The dialogue has already set the ending via actions. Finalise the mission chain.
	MissionManager.complete("final_truth")
	MissionManager.complete("ending")
	# Hand off to the HUD to show the chosen ending.
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("show_ending"):
			hud.show_ending(GameState.chosen_ending)
