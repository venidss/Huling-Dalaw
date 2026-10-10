extends Control
## Note viewer. Shown when the player reads a letter, diary entry, or caption on an
## object. Displays Tagalog on top and optional English below.
class_name NoteViewer

@onready var title_label: Label = $Panel/VBox/Title
@onready var text_label: RichTextLabel = $Panel/VBox/Scroll/Text
@onready var text_en_label: RichTextLabel = $Panel/VBox/Scroll/TextEN
@onready var close_btn: Button = $Panel/CloseButton

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_on_close)

func show_note(title: String, tagalog: String, english: String = "") -> void:
	visible = true
	title_label.text = title
	text_label.text = tagalog
	text_en_label.text = english
	text_en_label.visible = Settings.show_english_subtitles and english != ""

func hide_note() -> void:
	visible = false

func _on_close() -> void:
	hide_note()
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(true)
