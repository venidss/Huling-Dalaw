extends Node
## Gameplay-scene controller. Wires up systems that need runtime cross-references
## (fuse-flag gating, time-of-day shift, intro sequencing).
##
## Attached to the gameplay root. Expects the HouseBuilder as a child named "House"
## and the Player and HUD as siblings.
class_name GameController

@onready var house: Node = $House
@onready var player: Node3D = $Player
@onready var hud: Node = $HUD

var _intro_played: bool = false

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
	# Reserved — flag_set hook kept for future use.
	MissionManager.flag_set.connect(_on_flag_set)
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
	# After mission 'greet_lola' completes, Lolo becomes available and the house darkens.
	MissionManager.mission_completed.connect(_on_mission_completed)
	# Signal that the fuse box should start dark (lights off) once we reach mission "restore_power".

func _on_flag_set(_flag: String, _val: Variant) -> void:
	# Hook kept for future flag-driven lighting changes. The fuse flow is self-contained:
	# the switch script checks the "fuse_installed" flag before letting the player flip it,
	# and the switch itself turns the hall lights on. No separate reaction needed here.
	pass

func _on_mission_completed(mission: Dictionary) -> void:
	var id: String = String(mission.get("id", ""))
	match id:
		"meet_lolo":
			# Nightfall. Dim the main lights, trigger a soft audio cue, drop an object.
			_shift_to_night()
		"night_noise":
			# Hallway lights falter after the player investigates.
			for l in house.hall_lights:
				if l is Light3D:
					l.light_energy = 0.4
		"diary_puzzle":
			# The code lock gave the key_locked_room. Prompt the next step.
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
