extends Control
## Mobile touchscreen HUD controls:
##  - Virtual joystick (lower-left)
##  - Camera-drag area (right half)
##  - Interact button, Flashlight button, Sprint button, Crouch button
##  - Inventory, Journal, Pause buttons (top row)
##
## Everything communicates with the player and the main HUD via signals / direct calls.
## The HUD attaches the player reference in _ready through GameState.
class_name MobileControls

@onready var joystick: DaetJoystick = $Joystick
@onready var camera_area: TouchCameraArea = $CameraArea
@onready var btn_interact: Button = $BottomRight/InteractButton
@onready var btn_flashlight: Button = $BottomRight/FlashlightButton
@onready var btn_sprint: Button = $BottomRight/SprintButton
@onready var btn_crouch: Button = $BottomRight/CrouchButton
@onready var btn_inventory: Button = $TopRight/InventoryButton
@onready var btn_journal: Button = $TopRight/JournalButton
@onready var btn_pause: Button = $TopRight/PauseButton

var _player: Node3D = null
var _sprint_held: bool = false

func _ready() -> void:
	visible = Settings.show_mobile_controls or Settings.is_touch_device()
	joystick.direction_changed.connect(_on_joystick)
	camera_area.drag_delta.connect(_on_camera_drag)

	btn_interact.pressed.connect(_on_interact)
	btn_flashlight.pressed.connect(_on_flashlight)
	btn_sprint.button_down.connect(_on_sprint_down)
	btn_sprint.button_up.connect(_on_sprint_up)
	btn_crouch.toggled.connect(_on_crouch_toggled)
	btn_inventory.pressed.connect(_on_inventory)
	btn_journal.pressed.connect(_on_journal)
	btn_pause.pressed.connect(_on_pause)

	Settings.settings_changed.connect(_refresh_visibility)
	GameState.player_registered.connect(_on_player)
	if GameState.current_player != null:
		_on_player(GameState.current_player)

func _refresh_visibility() -> void:
	visible = Settings.show_mobile_controls or Settings.is_touch_device()

func _on_player(p: Node3D) -> void:
	_player = p

func _on_joystick(dir: Vector2) -> void:
	if _player != null:
		_player.joystick_input = dir

func _on_camera_drag(delta: Vector2) -> void:
	if _player != null and _player.has_method("apply_touch_look"):
		_player.apply_touch_look(delta)

func _on_interact() -> void:
	# While a dialogue is playing, the Interact button advances the dialogue (the
	# player would expect "tap to continue" and the interact prompt is hidden anyway).
	if DialogueManager.is_playing():
		for hud in get_tree().get_nodes_in_group("hud"):
			var dlg := hud.get_node_or_null("Panels/DialogueBox")
			if dlg != null and dlg.has_method("advance"):
				dlg.advance()
				return
	# Only trigger a world interaction if the player is free to act (no modal note / UI).
	if _player == null:
		return
	if "can_move" in _player and not _player.can_move:
		return
	if _player.has_method("attempt_interact"):
		_player.attempt_interact()

func _on_flashlight() -> void:
	if _player != null and _player.has_method("toggle_flashlight") and Inventory.has_item("flashlight"):
		_player.toggle_flashlight()

func _on_sprint_down() -> void:
	_sprint_held = true
	Input.action_press("sprint")

func _on_sprint_up() -> void:
	_sprint_held = false
	Input.action_release("sprint")

func _on_crouch_toggled(pressed: bool) -> void:
	if _player != null and _player.has_method("set_crouch"):
		_player.set_crouch(pressed)

func _on_inventory() -> void:
	for ui in get_tree().get_nodes_in_group("hud"):
		if ui.has_method("toggle_inventory"):
			ui.toggle_inventory()

func _on_journal() -> void:
	for ui in get_tree().get_nodes_in_group("hud"):
		if ui.has_method("toggle_journal"):
			ui.toggle_journal()

func _on_pause() -> void:
	for ui in get_tree().get_nodes_in_group("hud"):
		if ui.has_method("toggle_pause"):
			ui.toggle_pause()
