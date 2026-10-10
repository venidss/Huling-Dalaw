extends Node
## Dialogue manager for DAET: ANG PAMANA.
##
## Loads dialogue trees from data/dialogue/*.json and plays them line-by-line through the
## dialogue UI. Supports: speaker names, Filipino lines + English subtitles, choices with
## conditional flags, actions that set flags / add items / complete missions / trigger
## horror events, and typewriter display.

signal dialogue_started(dialogue_id: String)
signal line_shown(line: Dictionary)
signal choices_shown(choices: Array)
signal dialogue_finished(dialogue_id: String)

const DIALOGUE_DIR := "res://data/dialogue/"

var _active_dialogue_id: String = ""
var _active_tree: Dictionary = {}
var _current_node_id: String = ""
var _is_playing: bool = false

var dialogues_cache: Dictionary = {}

func _ready() -> void:
	_preload_all()

func _preload_all() -> void:
	# Scan data/dialogue/ at startup so lookups are instant.
	var dir := DirAccess.open(DIALOGUE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var id := fname.get_basename()
			var data: Variant = _load_file(DIALOGUE_DIR + fname)
			if typeof(data) == TYPE_DICTIONARY:
				dialogues_cache[id] = data
		fname = dir.get_next()
	dir.list_dir_end()

func _load_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func is_playing() -> bool:
	return _is_playing

## Start a dialogue by id (file name without extension in data/dialogue/).
func start(dialogue_id: String) -> void:
	if _is_playing:
		return
	if not dialogues_cache.has(dialogue_id):
		push_warning("DialogueManager: no dialogue '%s'" % dialogue_id)
		return
	_active_dialogue_id = dialogue_id
	_active_tree = dialogues_cache[dialogue_id]
	_current_node_id = String(_active_tree.get("start", "start"))
	_is_playing = true
	dialogue_started.emit(dialogue_id)
	_show_current()

func _show_current() -> void:
	var nodes: Dictionary = _active_tree.get("nodes", {})
	if not nodes.has(_current_node_id):
		_finish()
		return
	var node: Dictionary = nodes[_current_node_id]
	# Perform any entry actions.
	_run_actions(node.get("actions", []))

	# Choices? Show them and wait for selection.
	var choices: Array = node.get("choices", [])
	if not choices.is_empty():
		var filtered: Array = _filter_choices(choices)
		if not filtered.is_empty():
			line_shown.emit({
				"speaker": node.get("speaker", ""),
				"line": node.get("line", ""),
				"line_en": node.get("line_en", ""),
			})
			choices_shown.emit(filtered)
			return

	# Plain line — emit and wait for advance().
	line_shown.emit({
		"speaker": node.get("speaker", ""),
		"line": node.get("line", ""),
		"line_en": node.get("line_en", ""),
	})

func advance() -> void:
	if not _is_playing:
		return
	var nodes: Dictionary = _active_tree.get("nodes", {})
	if not nodes.has(_current_node_id):
		_finish()
		return
	var node: Dictionary = nodes[_current_node_id]
	# If there are visible choices, advance() does nothing — we wait for choose().
	var filtered := _filter_choices(node.get("choices", []))
	if not filtered.is_empty():
		return
	var next: String = String(node.get("next", ""))
	if next == "":
		_finish()
		return
	_current_node_id = next
	_show_current()

func choose(choice_index: int) -> void:
	if not _is_playing:
		return
	var nodes: Dictionary = _active_tree.get("nodes", {})
	if not nodes.has(_current_node_id):
		return
	var node: Dictionary = nodes[_current_node_id]
	var filtered := _filter_choices(node.get("choices", []))
	if choice_index < 0 or choice_index >= filtered.size():
		return
	var choice: Dictionary = filtered[choice_index]
	_run_actions(choice.get("actions", []))
	var next: String = String(choice.get("next", ""))
	if next == "":
		_finish()
		return
	_current_node_id = next
	_show_current()

func _filter_choices(choices: Array) -> Array:
	# Filter out choices gated by flags that aren't set.
	var result: Array = []
	for c in choices:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var requires: String = String(c.get("requires_flag", ""))
		if requires != "" and not MissionManager.has_flag(requires):
			continue
		var forbids: String = String(c.get("forbids_flag", ""))
		if forbids != "" and MissionManager.has_flag(forbids):
			continue
		result.append(c)
	return result

func _run_actions(actions: Array) -> void:
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var kind: String = String(a.get("type", ""))
		match kind:
			"set_flag":
				MissionManager.set_flag(String(a.get("flag", "")), a.get("value", true))
			"add_item":
				Inventory.add_item(String(a.get("item", "")))
			"remove_item":
				Inventory.remove_item(String(a.get("item", "")))
			"complete_mission":
				MissionManager.complete(String(a.get("mission", "")))
			"start_mission":
				MissionManager.start_mission(String(a.get("mission", "")))
			"play_sfx":
				AudioManager.play_sfx(String(a.get("sfx", "")))
			"trigger_horror":
				HorrorManager.trigger_event(String(a.get("event", "")))
			"journal":
				MissionManager.add_journal_entry(String(a.get("text", "")))
			"set_ending":
				GameState.chosen_ending = int(a.get("ending", 0))

func _finish() -> void:
	var id := _active_dialogue_id
	_is_playing = false
	_active_dialogue_id = ""
	_active_tree = {}
	_current_node_id = ""
	dialogue_finished.emit(id)
