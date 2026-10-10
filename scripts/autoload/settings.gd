extends Node
## Global settings autoload for DAET: ANG PAMANA.
## Persists audio volumes, camera sensitivity, and language choice to user://settings.cfg.
## All UI panels read and write through this singleton.

const SETTINGS_PATH := "user://settings.cfg"

signal settings_changed

# Audio volumes are 0.0 - 1.0; converted to decibels by AudioManager when applied to buses.
var master_volume: float = 0.9
var music_volume: float = 0.7
var ambience_volume: float = 0.85
var sfx_volume: float = 0.9

# Camera & input
var camera_sensitivity: float = 0.25  # degrees per pixel of mouse delta
var touch_sensitivity: float = 0.18   # degrees per pixel of touch drag
var invert_y: bool = false

# Display
var show_subtitles: bool = true
var show_english_subtitles: bool = true
var fps_target: int = 60

# Gameplay
var reduce_motion: bool = false       # less camera shake / less screen flash for comfort
var show_mobile_controls: bool = true # auto-detected on mobile but overridable

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# First run — save defaults so subsequent launches are consistent.
		save_settings()
		return

	master_volume = clampf(cfg.get_value("audio", "master", master_volume), 0.0, 1.0)
	music_volume = clampf(cfg.get_value("audio", "music", music_volume), 0.0, 1.0)
	ambience_volume = clampf(cfg.get_value("audio", "ambience", ambience_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)

	camera_sensitivity = clampf(cfg.get_value("input", "camera_sensitivity", camera_sensitivity), 0.02, 1.5)
	touch_sensitivity = clampf(cfg.get_value("input", "touch_sensitivity", touch_sensitivity), 0.02, 1.0)
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))

	show_subtitles = bool(cfg.get_value("display", "subtitles", show_subtitles))
	show_english_subtitles = bool(cfg.get_value("display", "english_subtitles", show_english_subtitles))
	fps_target = int(cfg.get_value("display", "fps_target", fps_target))

	reduce_motion = bool(cfg.get_value("gameplay", "reduce_motion", reduce_motion))
	show_mobile_controls = bool(cfg.get_value("gameplay", "show_mobile_controls", show_mobile_controls))

	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.set_value("audio", "sfx", sfx_volume)

	cfg.set_value("input", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("input", "touch_sensitivity", touch_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)

	cfg.set_value("display", "subtitles", show_subtitles)
	cfg.set_value("display", "english_subtitles", show_english_subtitles)
	cfg.set_value("display", "fps_target", fps_target)

	cfg.set_value("gameplay", "reduce_motion", reduce_motion)
	cfg.set_value("gameplay", "show_mobile_controls", show_mobile_controls)

	cfg.save(SETTINGS_PATH)
	settings_changed.emit()

## Returns true if we should assume a touch device (Android/iOS or desktop with touch flag).
func is_touch_device() -> bool:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	return DisplayServer.is_touchscreen_available()
