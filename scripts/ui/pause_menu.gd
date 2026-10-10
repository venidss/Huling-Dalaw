extends Control
## In-game pause menu. Nodes are built in code for simplicity so the layout is predictable.
class_name PauseMenu

@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var save_btn: Button = $Panel/VBox/SaveButton
@onready var settings_btn: Button = $Panel/VBox/SettingsButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton
@onready var settings_panel: Control = $SettingsPanel
@onready var save_status: Label = $Panel/VBox/StatusLabel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # still works while paused
	resume_btn.pressed.connect(_on_resume)
	save_btn.pressed.connect(_on_save)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	SaveSystem.save_completed.connect(_on_save_completed)
	SaveSystem.save_failed.connect(_on_save_failed)

func _on_resume() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("toggle_pause"):
			hud.toggle_pause()

func _on_save() -> void:
	save_status.text = "Nag-sa-save..."
	SaveSystem.save_game()

func _on_save_completed() -> void:
	save_status.text = "Na-save! / Saved!"

func _on_save_failed(reason: String) -> void:
	save_status.text = "Error: " + reason

func _on_settings() -> void:
	settings_panel.visible = true

func _on_quit() -> void:
	GameState.set_paused(false)
	SceneLoader.change_scene(SceneLoader.SCENE_MAIN_MENU)
