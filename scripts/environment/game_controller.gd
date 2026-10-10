extends Node
## Gameplay-scene controller. Wires up systems that need runtime cross-references
## (fuse-flag gating, time-of-day shift, intro sequencing, scripted story beats).
##
## Attached to the gameplay root. Expects the HouseBuilder as a child named "House"
## and the Player and HUD as siblings.
class_name GameController

@onready var house: Node = $House
@onready var player: Node3D = $Player
@onready var hud: Node = $HUD

# One-shot guards for scripted dialogue beats.
var _dinner_played: bool = false
var _tala_whisper_played: bool = false
var _lolo_truth_played: bool = false
var _lola_confrontation_played: bool = false
var _lolo_passage_played: bool = false

func _ready() -> void:
	# Register this scene as the "current level" so other systems can find us.
	GameState.register_level(self)
	# Fade in from black.
	await get_tree().process_frame
	SceneLoader.fade_in(1.0)
	# The player.tscn default transform already places them at the gate; a loaded save's
	# pending_spawn is applied by GameState.register_player() before we run here. So we
	# only orient them if this is a fresh game.
	if not GameState.restored_from_save and player.has_method("set_yaw"):
		player.set_yaw(deg_to_rad(180))
	GameState.restored_from_save = false  # reset for next transition
	# Hook mission + inventory + dialogue signals so we can insert scripted scene beats.
	MissionManager.flag_set.connect(_on_flag_set)
	MissionManager.mission_completed.connect(_on_mission_completed)
	Inventory.item_added.connect(_on_item_added)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	# Start the opening ambience.
	AudioManager.play_ambience("night_insects.wav")
	AudioManager.play_ambience("night_wind.wav", 1)
	AudioManager.play_music("ambient_drone.wav")
	# Opening journal entry.
	MissionManager.add_journal_entry("Umaga pa noong dumating ka. Ngayon ay gabi na.")
	# Kick off the first mission after a short delay so the HUD is bound.
	await get_tree().create_timer(0.6).timeout
	if MissionManager.current_mission_id == "" or MissionManager.current_mission_id == MissionManager.missions[0].id:
		MissionManager.start_mission("arrive")

func _on_flag_set(flag: String, _val: Variant) -> void:
	# When the player sets 'learned_about_tala' (by reading Lolo's letter), queue the
	# Lolo truth scene — Lolo appears nearby a moment later.
	if flag == "learned_about_tala" and not _lolo_truth_played:
		_lolo_truth_played = true
		await get_tree().create_timer(1.0).timeout
		if not DialogueManager.is_playing():
			DialogueManager.start("lolo_truth")

func _on_item_added(item: Dictionary) -> void:
	var id := String(item.get("id", ""))
	# Picking up the diary triggers Tala's first whisper after a long enough delay for
	# the player to have likely closed the note viewer first.
	if id == "diary" and not _tala_whisper_played:
		_tala_whisper_played = true
		await get_tree().create_timer(3.0).timeout
		HorrorManager.flash_screen(Color(0.05, 0.0, 0.0, 0.3), 0.6)
		HorrorManager.shake_camera(0.08, 0.4)
		DialogueManager.start("tala_whisper")
	# Picking up the locked-room key: Lola intercepts the player with the confrontation
	# dialogue (unless they already heard it).
	elif id == "key_locked_room" and not _lola_confrontation_played:
		_lola_confrontation_played = true
		await get_tree().create_timer(1.5).timeout
		DialogueManager.start("lola_confrontation")
	# Picking up the passage key: Lolo appears at the altar for his final words.
	elif id == "key_passage" and not _lolo_passage_played:
		_lolo_passage_played = true
		await get_tree().create_timer(1.0).timeout
		DialogueManager.start("lolo_passage")

func _on_dialogue_finished(id: String) -> void:
	# After the Lolo intro, play the dinner scene before nightfall logic kicks in.
	if id == "lolo_intro" and not _dinner_played:
		_dinner_played = true
		await get_tree().create_timer(0.4).timeout
		DialogueManager.start("dinner_scene")
	# After dinner, actually shift to night and progress.
	elif id == "dinner_scene":
		# meet_lolo is already completed by lolo_intro; _shift_to_night was deferred.
		_shift_to_night()

func _on_mission_completed(mission: Dictionary) -> void:
	var id: String = String(mission.get("id", ""))
	match id:
		"meet_lolo":
			# Don't shift to night immediately — wait for dinner_scene to finish via
			# _on_dialogue_finished. The dinner is triggered by lolo_intro finishing.
			pass
		"night_noise":
			# Hallway lights falter after the player investigates.
			for l in house.hall_lights:
				if l is Light3D:
					l.light_energy = 0.4
		"diary_puzzle":
			# The code lock gave the key_locked_room (and the Lola confrontation will
			# play from _on_item_added when that key is added to the inventory).
			if hud.has_method("show_subtitle"):
				hud.show_subtitle("May susi ka na. Buksan ang nakakandadong silid.")
		"enter_locked_room":
			# Dim hallway completely — fuse "trip".
			for l in house.hall_lights:
				if l is Light3D:
					l.visible = false
			# "restore_power" starts automatically on the auto-advance.
		"restore_power":
			# Something stirs now that the lights are back. A stinger, a slam, a shake.
			AudioManager.play_sfx("door_slam.wav", 1.0)
			HorrorManager.shake_camera(0.3, 0.5)
			HorrorManager.flash_screen(Color(0.1, 0.0, 0.0, 0.4), 0.4)
			AudioManager.play_sfx("whisper.wav", -2.0)
			await get_tree().create_timer(5.0).timeout
			if MissionManager.current_mission_id == "evade_entity":
				MissionManager.complete("evade_entity")

func _shift_to_night() -> void:
	# Scale down the kitchen & sala lights, give the whole scene a cooler tint.
	for l in house.kitchen_lights:
		if l is Light3D:
			l.light_energy = 0.5
			l.light_color = Color(0.9, 0.75, 0.55)
	AudioManager.play_sfx("heartbeat.wav", -6.0)
	# Drop a "something fell" cue after a beat.
	await get_tree().create_timer(1.4).timeout
	AudioManager.play_sfx("object_fall.wav", 0.0)
	await get_tree().create_timer(0.6).timeout
	AudioManager.play_sfx("whisper.wav", -4.0)
	# night_noise mission is already current (auto-advance after meet_lolo).
	if hud.has_method("show_subtitle"):
		hud.show_subtitle("May narinig ka sa pasilyo.")

func _notification(what: int) -> void:
	# Handle Android focus loss (and desktop window focus loss) by showing the pause menu.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not GameState.is_paused:
			if hud != null and hud.has_method("toggle_pause"):
				hud.toggle_pause()
