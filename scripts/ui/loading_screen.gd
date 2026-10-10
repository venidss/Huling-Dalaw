extends Control
## Loading screen between scene transitions. Shows a simple dark panel with a line.
class_name LoadingScreen

@onready var line: Label = $CenterContainer/VBox/HintLabel

const HINTS := [
	"Sabi ni Lola, huwag kang lalabas sa gabi.",
	"Lola said, don't go outside at night.",
	"Mga alaala ay hindi natatago sa kaha. Lumalabas sila.",
	"Memories don't stay in boxes. They surface.",
	"Pakinggan ang kahoy. Ito ang unang magsasabi sa iyo.",
	"Listen to the wood. It will tell you first.",
	"Ang isang pangalan na hindi nabanggit sa 20 taon ay hindi tahimik — nagtatago lamang ito.",
]

func _ready() -> void:
	line.text = HINTS[randi() % HINTS.size()]
