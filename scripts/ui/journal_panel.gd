extends Control
## Journal panel — scrollable log of story discoveries. Players can re-read the current
## objective and anything that was previously marked.
class_name JournalPanel

@onready var current_objective: Label = $Panel/VBox/CurrentObjective
@onready var current_desc: Label = $Panel/VBox/CurrentDescription
@onready var log_container: VBoxContainer = $Panel/VBox/Scroll/LogContainer
@onready var close_btn: Button = $Panel/CloseButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	close_btn.pressed.connect(_on_close)
	MissionManager.journal_updated.connect(_refresh)
	MissionManager.mission_changed.connect(func(_m): _refresh())
	visibility_changed.connect(_on_visibility)

func _on_visibility() -> void:
	if visible:
		_refresh()

func _on_close() -> void:
	hide()
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(true)

func _refresh() -> void:
	var cur := MissionManager.get_current_mission()
	current_objective.text = String(cur.get("title", ""))
	current_desc.text = String(cur.get("description", ""))
	for c in log_container.get_children():
		c.queue_free()
	var entries := MissionManager.journal_entries
	# Show most recent first.
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var row := Label.new()
		row.text = "• %s" % String(e.get("text", ""))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.custom_minimum_size = Vector2(600, 0)
		log_container.add_child(row)
	if entries.is_empty():
		var row := Label.new()
		row.text = "Wala pang nakatala."
		log_container.add_child(row)
