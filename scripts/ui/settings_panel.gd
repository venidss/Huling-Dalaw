extends Control
## Settings panel — audio volumes, camera/touch sensitivity, subtitles, reduce motion.
## Reads/writes through the Settings autoload so changes persist to user://settings.cfg.
class_name SettingsPanel

@onready var master_slider: HSlider = $Panel/VBox/Audio/MasterSlider
@onready var music_slider: HSlider = $Panel/VBox/Audio/MusicSlider
@onready var ambience_slider: HSlider = $Panel/VBox/Audio/AmbienceSlider
@onready var sfx_slider: HSlider = $Panel/VBox/Audio/SFXSlider
@onready var mouse_slider: HSlider = $Panel/VBox/Input/MouseSensSlider
@onready var touch_slider: HSlider = $Panel/VBox/Input/TouchSensSlider
@onready var invert_y: CheckButton = $Panel/VBox/Input/InvertY
@onready var subtitles_box: CheckButton = $Panel/VBox/Display/Subtitles
@onready var english_box: CheckButton = $Panel/VBox/Display/EnglishSubtitles
@onready var reduce_motion_box: CheckButton = $Panel/VBox/Display/ReduceMotion
@onready var mobile_controls_box: CheckButton = $Panel/VBox/Display/MobileControls
@onready var close_btn: Button = $Panel/CloseButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	close_btn.pressed.connect(_on_close)
	master_slider.value_changed.connect(_on_master)
	music_slider.value_changed.connect(_on_music)
	ambience_slider.value_changed.connect(_on_ambience)
	sfx_slider.value_changed.connect(_on_sfx)
	mouse_slider.value_changed.connect(_on_mouse_sens)
	touch_slider.value_changed.connect(_on_touch_sens)
	invert_y.toggled.connect(_on_invert_y)
	subtitles_box.toggled.connect(_on_subtitles)
	english_box.toggled.connect(_on_english)
	reduce_motion_box.toggled.connect(_on_reduce_motion)
	mobile_controls_box.toggled.connect(_on_mobile_controls)
	visibility_changed.connect(_load_values)
	_load_values()

func _on_close() -> void:
	visible = false

func _on_master(v: float) -> void:
	Settings.master_volume = v
	_apply()

func _on_music(v: float) -> void:
	Settings.music_volume = v
	_apply()

func _on_ambience(v: float) -> void:
	Settings.ambience_volume = v
	_apply()

func _on_sfx(v: float) -> void:
	Settings.sfx_volume = v
	_apply()

func _on_mouse_sens(v: float) -> void:
	Settings.camera_sensitivity = v
	_apply()

func _on_touch_sens(v: float) -> void:
	Settings.touch_sensitivity = v
	_apply()

func _on_invert_y(v: bool) -> void:
	Settings.invert_y = v
	_apply()

func _on_subtitles(v: bool) -> void:
	Settings.show_subtitles = v
	_apply()

func _on_english(v: bool) -> void:
	Settings.show_english_subtitles = v
	_apply()

func _on_reduce_motion(v: bool) -> void:
	Settings.reduce_motion = v
	_apply()

func _on_mobile_controls(v: bool) -> void:
	Settings.show_mobile_controls = v
	_apply()

func _load_values() -> void:
	master_slider.value = Settings.master_volume
	music_slider.value = Settings.music_volume
	ambience_slider.value = Settings.ambience_volume
	sfx_slider.value = Settings.sfx_volume
	mouse_slider.value = Settings.camera_sensitivity
	touch_slider.value = Settings.touch_sensitivity
	invert_y.button_pressed = Settings.invert_y
	subtitles_box.button_pressed = Settings.show_subtitles
	english_box.button_pressed = Settings.show_english_subtitles
	reduce_motion_box.button_pressed = Settings.reduce_motion
	mobile_controls_box.button_pressed = Settings.show_mobile_controls

func _apply() -> void:
	Settings.save_settings()
