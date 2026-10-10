extends Control
## Credits screen. Scrolls automatically; tap/click/press Esc to go back.
class_name CreditsScreen

@onready var back_btn: Button = $Panel/BackButton
@onready var scroll: ScrollContainer = $Panel/Scroll
@onready var content: VBoxContainer = $Panel/Scroll/Content

const CREDITS: Array[Dictionary] = [
	{"section": "DAET: ANG PAMANA"},
	{"section": "Isang Filipino Psychological Horror"},
	{"section": "Niyari sa Godot 4.x"},
	{"spacer": true},
	{"line": "Konsepto, Disenyo, Code:"},
	{"line": "— Isang unti-unting pamana."},
	{"spacer": true},
	{"line": "Audio: Procedural synthesis"},
	{"line": "Lahat ng tunog ay ginawa sa pure Python wave synthesis"},
	{"spacer": true},
	{"line": "Mga tunog ng gabi: Daet, Camarines Norte (inspirasyon)"},
	{"line": "Mga alaala ng probinsiya"},
	{"spacer": true},
	{"line": "Para sa mga nagmamahal sa kanilang mga lolo at lola."},
	{"line": "Para sa mga pamilya na walang nagsasabi ng totoo."},
	{"spacer": true},
	{"section": "Salamat"},
]

func _ready() -> void:
	back_btn.pressed.connect(_back)
	for row in CREDITS:
		if row.has("section"):
			var l := Label.new()
			l.text = row["section"]
			l.add_theme_font_size_override("font_size", 28)
			l.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(l)
		elif row.has("line"):
			var l := Label.new()
			l.text = row["line"]
			l.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(l)
		elif row.has("spacer"):
			var r := Control.new()
			r.custom_minimum_size = Vector2(0, 24)
			content.add_child(r)

func _process(delta: float) -> void:
	scroll.scroll_vertical += int(20 * delta)
	if scroll.scroll_vertical >= content.size.y - scroll.size.y:
		scroll.scroll_vertical = content.size.y - int(scroll.size.y)

func _back() -> void:
	SceneLoader.change_scene(SceneLoader.SCENE_MAIN_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_back()
