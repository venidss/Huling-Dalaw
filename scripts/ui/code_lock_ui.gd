extends Control
## 4-digit code lock UI. Hosts a visible display + number pad; sends attempts back to the
## CodeLock node that opened it.
class_name CodeLockUI

@onready var display: Label = $Panel/VBox/Display
@onready var hint_label: Label = $Panel/VBox/Hint
@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var close_btn: Button = $Panel/CloseButton
@onready var status_label: Label = $Panel/VBox/Status

var _active_lock: Node = null
var _entered: String = ""

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_close)
	for i in 10:
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(72, 72)
		b.pressed.connect(_press_digit.bind(i))
		grid.add_child(b)
	var clear_btn := Button.new()
	clear_btn.text = "C"
	clear_btn.custom_minimum_size = Vector2(72, 72)
	clear_btn.pressed.connect(_clear)
	grid.add_child(clear_btn)
	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(72, 72)
	ok_btn.pressed.connect(_submit)
	grid.add_child(ok_btn)

func open_for(lock: Node, hint_tagalog: String, hint_english: String) -> void:
	_active_lock = lock
	_entered = ""
	_refresh_display()
	hint_label.text = hint_tagalog + ("\n" + hint_english if Settings.show_english_subtitles and hint_english != "" else "")
	status_label.text = ""
	visible = true

func _press_digit(d: int) -> void:
	if _entered.length() >= 4:
		return
	_entered += str(d)
	_refresh_display()

func _clear() -> void:
	_entered = ""
	_refresh_display()
	status_label.text = ""

func _refresh_display() -> void:
	var padded := _entered.lpad(4, "_")
	display.text = padded

func _submit() -> void:
	if _active_lock == null or not is_instance_valid(_active_lock):
		_close()
		return
	if _entered.length() < 4:
		return
	var ok: bool = _active_lock.try_code(_entered)
	if ok:
		status_label.text = "Nabuksan!"
		await get_tree().create_timer(0.6).timeout
		_close()
	else:
		status_label.text = "Mali ang code."
		HorrorManager.shake_camera(0.05, 0.2)
		_entered = ""
		_refresh_display()

func _close() -> void:
	_active_lock = null
	visible = false
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(true)
