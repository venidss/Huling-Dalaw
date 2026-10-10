extends Control
## Ending screen. Fades in a tinted background, prints the ending title and reflective
## epilogue, then offers "Main Menu".
class_name EndingScreen

@onready var background: ColorRect = $Background
@onready var title_label: Label = $CenterContainer/VBox/Title
@onready var subtitle_label: Label = $CenterContainer/VBox/Subtitle
@onready var body_label: RichTextLabel = $CenterContainer/VBox/Body
@onready var menu_btn: Button = $CenterContainer/VBox/MenuButton

const ENDINGS := {
	1: {  # ENDING_FORGIVENESS
		"title": "I. Patawad",
		"subtitle": "Forgiveness",
		"body": "Hindi ka tumakbo. Hinawakan mo ang alaala ng isang batang nawala, at tinawag ito sa pangalan: Tala.\n\nSinabi ni Lola na patawarin siya ng kanyang anak. Sinabi ni Lolo na masaya sila sa paraang hindi nila natutunan noon.\n\nPagsikat ng araw, tahimik ang bahay. Tila mas magaan ang hangin — tulad ng dapat.",
		"body_en": "You did not run. You held the memory of a lost child and spoke her name: Tala.\n\nLola asked her daughter for forgiveness. Lolo said they were loved in ways they had never learned to show.\n\nWhen the sun rose, the house was quiet. The air was lighter — as it should have been.",
		"tint": Color(0.95, 0.85, 0.6),
	},
	2: {  # ENDING_BURIED
		"title": "II. Ibinaong Pangalan",
		"subtitle": "The Name Reburied",
		"body": "Isinarado mo ang kahon muli. Hindi mo pinakinggan ang pangalan.\n\nUmalis ka ng Daet, umiiwas sa mga larawan sa pader. Si Lola at Lolo ay nagbati na parang pangkaraniwang Linggo. Hindi mo tiningnan ang ikatlong silid sa pagsasara ng pinto.\n\nSa isang gabi — ilang taon mula ngayon — gigising ka at maaalala mo ang pangalan ng isang bata. Hindi mo malalaman kung paano mo ito nalaman.",
		"body_en": "You closed the box again. You did not speak the name.\n\nYou left Daet, avoiding the photographs on the walls. Lola and Lolo waved as if it were an ordinary Sunday. You did not look at the third room as you shut the door.\n\nOne night — years from now — you will wake remembering a child's name. You will not know how you know it.",
		"tint": Color(0.4, 0.35, 0.4),
	},
	3: {  # ENDING_LOST
		"title": "III. Nawala sa Lagusan",
		"subtitle": "Lost in the Passage",
		"body": "Hindi ka nakalabas ng lagusan.\n\nSa taon-taon na susunod, aarkilahin ang bahay sa iba't ibang pamilya. Sabihin nila na nararamdaman nila kung minsan — isang matanda, isang kabataan, at isang bata — na nananatili sa likod ng altar.\n\nIkaw na iyon ngayon.",
		"body_en": "You never came out of the passage.\n\nIn the years to come, the house is rented to new families. Some say they feel it sometimes — an old man, a young one, and a child — lingering behind the altar.\n\nThat is you now.",
		"tint": Color(0.25, 0.1, 0.08),
	},
}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	menu_btn.pressed.connect(_on_menu)

func show_ending(ending_id: int) -> void:
	visible = true
	modulate.a = 0.0
	var data: Dictionary = ENDINGS.get(ending_id, ENDINGS[2])
	title_label.text = String(data.get("title", ""))
	subtitle_label.text = String(data.get("subtitle", ""))
	var body: String = String(data.get("body", ""))
	if Settings.show_english_subtitles:
		body += "\n\n[color=#9e8c7a][i]" + String(data.get("body_en", "")) + "[/i][/color]"
	body_label.text = body
	body_label.bbcode_enabled = true
	background.color = Color(0, 0, 0, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.8)
	GameState.set_paused(false)
	# Save the game at the ending so the player sees their chosen ending in Continue.
	SaveSystem.save_game()
	AudioManager.stop_ambience()
	AudioManager.play_music("ending_theme.wav", 2.0)

func _on_menu() -> void:
	SceneLoader.change_scene(SceneLoader.SCENE_MAIN_MENU)
