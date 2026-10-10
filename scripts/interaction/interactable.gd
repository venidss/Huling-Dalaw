extends StaticBody3D
## Base class for every interactable in DAET: ANG PAMANA.
##
## Subclasses override interact() and optionally get_interact_label(). The player's
## raycast climbs the parent chain until it finds a node in group "interactable",
## so interactable scenes should add themselves to that group in _ready().
class_name Interactable

@export var label: String = "Suriin"
@export var label_en: String = "Examine"
@export var disabled: bool = false
@export var one_shot: bool = false

var _used: bool = false

func _ready() -> void:
	add_to_group("interactable")
	# Place on the "Interactable" physics layer so the player's ray detects us.
	collision_layer = 1 << 2  # layer 3
	collision_mask = 0

func get_interact_label() -> String:
	if Settings.show_english_subtitles and label_en != "":
		return "%s / %s" % [label, label_en]
	return label

func can_interact(_player: Node) -> bool:
	return not disabled and not (_used and one_shot)

func interact(player: Node) -> void:
	if not can_interact(player):
		return
	_used = true
	_on_interact(player)

## Override in subclass.
func _on_interact(_player: Node) -> void:
	pass
