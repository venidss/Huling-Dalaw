extends Node
## Scene loader for DAET: ANG PAMANA. Provides a simple fade-and-swap transition between
## scenes with a loading screen. Keeps scene-change logic in one place so the main menu
## and in-game "continue" / "quit to menu" buttons all behave consistently.

signal transition_started
signal transition_finished

const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_GAMEPLAY := "res://scenes/gameplay.tscn"
const SCENE_CREDITS := "res://scenes/ui/credits.tscn"
const SCENE_LOADING := "res://scenes/loading_screen.tscn"

var _is_transitioning: bool = false
var _overlay: ColorRect = null

func _ready() -> void:
	# Build a top-level canvas overlay that persists through scene changes.
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

func change_scene(path: String, fade_time: float = 0.6) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()
	await _fade_to(1.0, fade_time)
	GameState.set_paused(false)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneLoader: change_scene_to_file failed with %s" % str(err))
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, fade_time)
	_is_transitioning = false
	transition_finished.emit()

func fade_in(duration: float = 0.6) -> void:
	await _fade_to(0.0, duration)

func fade_out(duration: float = 0.6) -> void:
	await _fade_to(1.0, duration)

func _fade_to(target_alpha: float, duration: float) -> void:
	if _overlay == null:
		return
	var start_alpha := _overlay.color.a
	if is_equal_approx(start_alpha, target_alpha):
		return
	var tween := create_tween()
	tween.tween_method(func(a: float):
		_overlay.color = Color(0, 0, 0, a), start_alpha, target_alpha, duration)
	await tween.finished
