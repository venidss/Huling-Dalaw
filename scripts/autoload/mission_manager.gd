extends Node
## Mission / objective manager for DAET: ANG PAMANA.
##
## Drives the story: each mission has an id, a title and description (in Filipino, with
## optional English subtitle), and an advance_signal that marks completion. Puzzles, doors,
## dialogue triggers and pickup items all call MissionManager.complete() to advance.
##
## Also stores global story flags that gate horror events and dialogue branches, and
## maintains a journal the player can re-read.

signal mission_started(mission: Dictionary)
signal mission_completed(mission: Dictionary)
signal mission_changed(mission: Dictionary)
signal flag_set(flag: String, value: Variant)
signal journal_updated

# Ordered list of missions. Each one declares the condition to complete it (just an id).
var missions: Array[Dictionary] = [
	{
		"id": "arrive",
		"title": "Pagbisita sa Daet",
		"title_en": "Arrive at Daet",
		"description": "Dumaan sa gate at lumapit sa harapan ng lumang bahay.",
	},
	{
		"id": "greet_lola",
		"title": "Kausapin si Lola",
		"title_en": "Talk to Lola",
		"description": "Sinalubong ka ni Lola sa harap ng pinto. Lumapit at kausapin siya.",
	},
	{
		"id": "explore_living_room",
		"title": "Suriin ang Sala",
		"title_en": "Explore the Sala",
		"description": "Pumasok sa sala. Tingnan ang mga lumang litrato sa pader.",
	},
	{
		"id": "meet_lolo",
		"title": "Kausapin si Lolo",
		"title_en": "Talk to Lolo",
		"description": "Hanapin si Lolo sa dining room at kausapin siya.",
	},
	{
		"id": "night_noise",
		"title": "May Narinig na Kalampag",
		"title_en": "A Noise in the House",
		"description": "May kalampag na narinig sa pasilyo. Suriin kung ano iyon.",
	},
	{
		"id": "find_diary",
		"title": "Hanapin ang Talaarawan",
		"title_en": "Find the Diary",
		"description": "May dapat na talaarawan si Lola. Hanapin ito sa kanyang silid.",
	},
	{
		"id": "diary_puzzle",
		"title": "Buksan ang Kahon sa Altar",
		"title_en": "Unlock the Prayer Box",
		"description": "May nakakandadong kahon sa harap ng altar. Ang code ay nasa talaarawan.",
	},
	{
		"id": "enter_locked_room",
		"title": "Pasukin ang Nakakandadong Silid",
		"title_en": "Enter the Locked Room",
		"description": "Mayroon ka na ngayong susi. Buksan ang pintuan sa pasilyo.",
	},
	{
		"id": "restore_power",
		"title": "Ibalik ang Kuryente",
		"title_en": "Restore the Power",
		"description": "Patay ang ilaw sa pasilyo. May fuse box sa gitna ng dingding. Hanapin ang fuse.",
	},
	{
		"id": "evade_entity",
		"title": "Lumingon ka. Umiwas.",
		"title_en": "Look Behind You. Move.",
		"description": "May isang bagay sa pasilyo. Magtago sa altar room.",
	},
	{
		"id": "find_passage",
		"title": "Hanapin ang Lagusan",
		"title_en": "Find the Hidden Passage",
		"description": "May isang lagusan sa likod ng altar. Hanapin ang susi sa cabinet malapit sa altar.",
	},
	{
		"id": "final_truth",
		"title": "Harapin ang Katotohanan",
		"title_en": "Face the Truth",
		"description": "Isang alaala. Isang pangalan. Isang pagpipilian.",
	},
	{
		"id": "ending",
		"title": "Pagtatapos",
		"title_en": "Ending",
		"description": "",
	},
]

var current_mission_id: String = ""
var completed_missions: Array[String] = []
var story_flags: Dictionary = {}
var journal_entries: Array[Dictionary] = []

func _ready() -> void:
	# Start the mission chain fresh. New Game sets current to first; loaded saves override.
	if current_mission_id == "":
		current_mission_id = missions[0].id

func get_current_mission() -> Dictionary:
	for m in missions:
		if m.id == current_mission_id:
			return m
	return {}

func get_mission(id: String) -> Dictionary:
	for m in missions:
		if m.id == id:
			return m
	return {}

func start_mission(id: String) -> void:
	var m := get_mission(id)
	if m.is_empty():
		return
	var already_current := current_mission_id == id
	current_mission_id = id
	mission_started.emit(m)
	mission_changed.emit(m)
	if not already_current:
		add_journal_entry("Bagong misyon: " + m.title)

func complete(id: String) -> void:
	# Only accept completion for the current mission to prevent skipping steps.
	if id != current_mission_id:
		return
	if completed_missions.has(id):
		return
	var m := get_mission(id)
	completed_missions.append(id)
	mission_completed.emit(m)
	add_journal_entry("Natapos: " + m.title)
	_advance_from(id)

func _advance_from(id: String) -> void:
	# Advance to the next mission in the ordered list, UNLESS a handler of mission_completed
	# already advanced us further.
	var from_idx := _index_of(id)
	var cur_idx := _index_of(current_mission_id)
	if cur_idx > from_idx:
		return
	if from_idx < 0 or from_idx >= missions.size() - 1:
		return
	var next: Dictionary = missions[from_idx + 1]
	start_mission(next.id)

func _index_of(id: String) -> int:
	for i in missions.size():
		if missions[i].id == id:
			return i
	return -1

func is_completed(id: String) -> bool:
	return completed_missions.has(id)

func is_at_or_past(id: String) -> bool:
	# Useful for gating: has the player reached a mission (completed or current)?
	var target := _index_of(id)
	var current := _index_of(current_mission_id)
	if target < 0 or current < 0:
		return false
	return current >= target or completed_missions.has(id)

# --- story flags -------------------------------------------------------------

func set_flag(flag: String, value: Variant = true) -> void:
	story_flags[flag] = value
	flag_set.emit(flag, value)

func get_flag(flag: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag, default_value)

func has_flag(flag: String) -> bool:
	return story_flags.has(flag) and bool(story_flags[flag])

# --- journal -----------------------------------------------------------------

func add_journal_entry(text: String) -> void:
	journal_entries.append({
		"time": Time.get_time_string_from_system(),
		"text": text,
	})
	journal_updated.emit()

# --- save/load support --------------------------------------------------------

func restore(data: Dictionary) -> void:
	current_mission_id = data.get("current_id", missions[0].id)
	var completed_raw: Array = data.get("completed", [])
	completed_missions.clear()
	for c in completed_raw:
		completed_missions.append(String(c))
	story_flags = data.get("flags", {}).duplicate(true)
	var journal_raw: Array = data.get("journal", [])
	journal_entries.clear()
	for j in journal_raw:
		if typeof(j) == TYPE_DICTIONARY:
			journal_entries.append(j.duplicate(true))
	var m := get_current_mission()
	if not m.is_empty():
		mission_changed.emit(m)
	journal_updated.emit()
