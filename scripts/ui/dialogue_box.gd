extends Control
## Dialogue UI box. Shows speaker name, Filipino line with typewriter effect, optional
## English subtitle, and up to four choice buttons.
class_name DialogueBox

@onready var speaker_label: Label = $Panel/VBox/Speaker
@onready var line_label: RichTextLabel = $Panel/VBox/Line
@onready var en_label: Label = $Panel/VBox/EnglishLine
@onready var hint_label: Label = $Panel/VBox/AdvanceHint
@onready var choices_container: VBoxContainer = $Panel/VBox/Choices

var _typing: bool = false
var _full_text: String = ""
var _display_text: String = ""
var _type_t: float = 0.0
var _chars_per_sec: float = 32.0

func _ready() -> void:
	visible = false
	DialogueManager.line_shown.connect(_on_line)
	DialogueManager.choices_shown.connect(_on_choices)
	DialogueManager.dialogue_finished.connect(_on_finished)
	hint_label.text = "[Space] Advance / Tap"

func _on_line(line: Dictionary) -> void:
	visible = true
	speaker_label.text = String(line.get("speaker", ""))
	_full_text = String(line.get("line", ""))
	_display_text = ""
	line_label.text = ""
	_typing = true
	_type_t = 0.0
	var en: String = String(line.get("line_en", ""))
	en_label.text = en if Settings.show_english_subtitles else ""
	en_label.visible = Settings.show_english_subtitles and en != ""
	for c in choices_container.get_children():
		c.queue_free()

func _on_choices(choices: Array) -> void:
	# Make sure the preceding line finishes before showing options.
	_finish_typing()
	for i in choices.size():
		var c: Dictionary = choices[i]
		var btn := Button.new()
		var text := String(c.get("text", "..."))
		if Settings.show_english_subtitles and c.has("text_en"):
			text += "\n(%s)" % String(c["text_en"])
		btn.text = text
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(func(): _choose(i))
		choices_container.add_child(btn)
	hint_label.visible = false

func _choose(index: int) -> void:
	for c in choices_container.get_children():
		c.queue_free()
	hint_label.visible = true
	DialogueManager.choose(index)

func _on_finished(_id: String) -> void:
	visible = false
	hint_label.visible = true
	for c in choices_container.get_children():
		c.queue_free()

func _process(delta: float) -> void:
	if not _typing:
		return
	_type_t += delta * _chars_per_sec
	var target_len := mini(int(_type_t), _full_text.length())
	if target_len > _display_text.length():
		_display_text = _full_text.substr(0, target_len)
		line_label.text = _display_text
	if target_len >= _full_text.length():
		_typing = false

func _finish_typing() -> void:
	_typing = false
	_display_text = _full_text
	line_label.text = _display_text

func advance() -> void:
	if _typing:
		_finish_typing()
		return
	# Only advance if no choices are currently waiting.
	if choices_container.get_child_count() > 0:
		return
	DialogueManager.advance()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
