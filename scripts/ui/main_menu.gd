extends Control
## Main menu for DAET: ANG PAMANA.
## Original atmospheric background painted in _draw() — a lonely house silhouette, flickering
## window light, and slow mist, so the project needs no external art.
class_name MainMenu

@onready var new_game_btn: Button = $CenterContainer/VBox/NewGameButton
@onready var continue_btn: Button = $CenterContainer/VBox/ContinueButton
@onready var settings_btn: Button = $CenterContainer/VBox/SettingsButton
@onready var credits_btn: Button = $CenterContainer/VBox/CreditsButton
@onready var quit_btn: Button = $CenterContainer/VBox/QuitButton
@onready var title_label: Label = $CenterContainer/VBox/Title
@onready var subtitle_label: Label = $CenterContainer/VBox/Subtitle
@onready var settings_panel: Control = $SettingsPanel
@onready var background: Control = $Background
@onready var version_label: Label = $BottomLeft/VersionLabel

func _ready() -> void:
	title_label.text = "DAET"
	subtitle_label.text = "Ang Pamana"
	version_label.text = "v0.1 — Filipino psychological horror"

	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	credits_btn.pressed.connect(_on_credits)
	quit_btn.pressed.connect(_on_quit)
	# "Continue" is only enabled when a valid save exists.
	continue_btn.disabled = not SaveSystem.has_save()
	if Settings.is_touch_device():
		quit_btn.visible = false  # Android: use system back instead.

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_music("menu_theme.wav")
	AudioManager.play_ambience("night_wind.wav")

func _on_new_game() -> void:
	GameState.reset_run()
	SaveSystem.delete_save()
	SceneLoader.change_scene(SceneLoader.SCENE_GAMEPLAY)

func _on_continue() -> void:
	if not SaveSystem.has_save():
		return
	if not SaveSystem.load_game():
		continue_btn.disabled = true
		return
	SceneLoader.change_scene(SceneLoader.SCENE_GAMEPLAY)

func _on_settings() -> void:
	settings_panel.visible = true

func _on_credits() -> void:
	SceneLoader.change_scene(SceneLoader.SCENE_CREDITS)

func _on_quit() -> void:
	get_tree().quit()
