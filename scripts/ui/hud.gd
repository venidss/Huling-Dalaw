extends CanvasLayer
## In-game HUD / UI manager for DAET: ANG PAMANA.
##
## Hosts the interact prompt, mission objective, stamina bar, mobile controls, dialogue box,
## note viewer, inventory panel, journal panel, pause menu, code-lock UI, and ending screen.
##
## Also hosts the horror flash/vignette layer that reacts to HorrorManager signals.
class_name GameHUD

@onready var objective_label: Label = $Top/ObjectiveBox/ObjectiveLabel
@onready var objective_sub_label: Label = $Top/ObjectiveBox/SubLabel
@onready var interact_prompt: Label = $Center/InteractPrompt
@onready var stamina_bar: ProgressBar = $BottomLeft/StaminaBar
@onready var mobile_controls: MobileControls = $MobileControls
@onready var inventory_panel: Control = $Panels/InventoryPanel
@onready var journal_panel: Control = $Panels/JournalPanel
@onready var dialogue_box: Control = $Panels/DialogueBox
@onready var note_viewer: Control = $Panels/NoteViewer
@onready var code_lock_ui: Control = $Panels/CodeLockUI
@onready var pause_menu: Control = $Panels/PauseMenu
@onready var ending_screen: Control = $Panels/EndingScreen
@onready var screen_flash: ColorRect = $Overlays/ScreenFlash
@onready var vignette: TextureRect = $Overlays/Vignette
@onready var subtitle_label: Label = $BottomCenter/SubtitleLabel

func _ready() -> void:
	add_to_group("hud")
	note_viewer.add_to_group("note_readers")
	code_lock_ui.add_to_group("code_lock_ui")
	interact_prompt.text = ""
	subtitle_label.text = ""

	MissionManager.mission_changed.connect(_on_mission_changed)
	HorrorManager.screen_flash.connect(_on_screen_flash)
	HorrorManager.camera_shake.connect(_on_camera_shake)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

	var player := GameState.current_player
	if player != null:
		_bind_player(player)
	else:
		GameState.player_registered.connect(_bind_player)

	_on_mission_changed(MissionManager.get_current_mission())

func _bind_player(p: Node) -> void:
	if p.has_signal("interactable_focused"):
		p.interactable_focused.connect(_on_focus)
		p.interactable_unfocused.connect(_on_unfocus)
	if p.has_signal("stamina_changed"):
		p.stamina_changed.connect(_on_stamina)
	else:
		# Nothing — the player may not define stamina.
		pass

func _process(_delta: float) -> void:
	# Keyboard shortcuts for the panels.
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	elif Input.is_action_just_pressed("inventory"):
		toggle_inventory()
	elif Input.is_action_just_pressed("journal"):
		toggle_journal()
	elif Input.is_action_just_pressed("dialogue_advance") and DialogueManager.is_playing():
		dialogue_box.advance()

func _on_focus(target: Node) -> void:
	if target == null:
		interact_prompt.text = ""
		return
	var label: String = ""
	if target.has_method("get_interact_label"):
		label = target.get_interact_label()
	if label != "":
		var hint := " [E]" if not Settings.is_touch_device() else ""
		interact_prompt.text = "%s%s" % [label, hint]
	else:
		interact_prompt.text = ""

func _on_unfocus() -> void:
	interact_prompt.text = ""

func _on_stamina(current: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = current
	stamina_bar.visible = current < max_val - 0.1

func _on_mission_changed(mission: Dictionary) -> void:
	if mission.is_empty():
		objective_label.text = ""
		objective_sub_label.text = ""
		return
	objective_label.text = String(mission.get("title", ""))
	if Settings.show_english_subtitles:
		objective_sub_label.text = String(mission.get("title_en", ""))
	else:
		objective_sub_label.text = String(mission.get("description", ""))

func _on_screen_flash(color: Color, duration: float) -> void:
	screen_flash.color = color
	screen_flash.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(screen_flash, "modulate:a", 0.0, duration)

func _on_camera_shake(strength: float, duration: float) -> void:
	var player := GameState.current_player
	if player == null:
		return
	var head := player.get_node_or_null("Head")
	if head == null:
		return
	var original: Vector3 = head.position
	var tween := create_tween()
	for i in 10:
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * strength * 0.08
		tween.tween_property(head, "position", original + jitter, duration / 10.0)
	tween.tween_property(head, "position", original, 0.05)

func _on_dialogue_started(_id: String) -> void:
	# Dismiss any UI that could render in front of the dialogue (note viewer, inventory,
	# etc.). The code-lock UI is also closed because scripted dialogues can fire right
	# after a code lock unlocks and spawns an item.
	note_viewer.hide()
	inventory_panel.hide()
	journal_panel.hide()
	code_lock_ui.hide()
	dialogue_box.visible = true
	# Lock player movement during dialogue for story focus.
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(false)

func _on_dialogue_finished(_id: String) -> void:
	dialogue_box.visible = false
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(true)

# --- public panel toggles ----------------------------------------------------

func toggle_pause() -> void:
	if pause_menu.visible:
		pause_menu.hide()
		GameState.set_paused(false)
	else:
		_close_all_panels()
		pause_menu.show()
		GameState.set_paused(true)

func toggle_inventory() -> void:
	if DialogueManager.is_playing():
		return
	if inventory_panel.visible:
		inventory_panel.hide()
		_resume_player()
	else:
		_close_all_panels()
		inventory_panel.show()
		_block_player()

func toggle_journal() -> void:
	if DialogueManager.is_playing():
		return
	if journal_panel.visible:
		journal_panel.hide()
		_resume_player()
	else:
		_close_all_panels()
		journal_panel.show()
		_block_player()

func _close_all_panels() -> void:
	inventory_panel.hide()
	journal_panel.hide()
	note_viewer.hide()
	code_lock_ui.hide()

func _block_player() -> void:
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(false)

func _resume_player() -> void:
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(true)

## Called by the ending controller when it's time to show the ending screen.
func show_ending(ending_id: int) -> void:
	_close_all_panels()
	ending_screen.show_ending(ending_id)

func show_subtitle(text: String, duration: float = 3.5) -> void:
	subtitle_label.text = text
	if text == "":
		return
	await get_tree().create_timer(duration).timeout
	if subtitle_label.text == text:
		subtitle_label.text = ""
