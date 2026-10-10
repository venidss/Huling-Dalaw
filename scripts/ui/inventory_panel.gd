extends Control
## Inventory panel UI — displays all collected items with icons (colored squares) and
## descriptions. Selecting an item shows a larger preview with its story-relevant text.
class_name InventoryPanel

@onready var list: VBoxContainer = $Panel/HBox/List
@onready var preview_title: Label = $Panel/HBox/Preview/Title
@onready var preview_desc: Label = $Panel/HBox/Preview/Description
@onready var preview_swatch: ColorRect = $Panel/HBox/Preview/Swatch
@onready var close_btn: Button = $Panel/CloseButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	Inventory.inventory_changed.connect(_refresh)
	close_btn.pressed.connect(_on_close)
	visibility_changed.connect(_on_visibility)

func _on_close() -> void:
	hide()
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("toggle_inventory") and visible:
			hud.toggle_inventory()
	# Resume the player.
	var p := GameState.current_player
	if p != null and p.has_method("set_can_move"):
		p.set_can_move(true)

func _on_visibility() -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var items := Inventory.get_all()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Walang laman ang bulsa."
		empty.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		list.add_child(empty)
		preview_title.text = ""
		preview_desc.text = ""
		preview_swatch.color = Color(0, 0, 0, 0)
		return
	for item in items:
		var btn := Button.new()
		btn.text = "   %s" % String(item.get("name", ""))
		btn.custom_minimum_size = Vector2(0, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var swatch := ColorRect.new()
		var swatch_color: Color = item.get("color", Color.WHITE)
		swatch.color = swatch_color
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.anchor_right = 0
		swatch.position = Vector2(10, 10)
		btn.add_child(swatch)
		btn.pressed.connect(func(): _show_item(item))
		list.add_child(btn)
	_show_item(items[0])

func _show_item(item: Dictionary) -> void:
	preview_title.text = String(item.get("name", ""))
	var desc := String(item.get("description", ""))
	if Settings.show_english_subtitles:
		var en := String(item.get("name_en", ""))
		if en != "":
			preview_title.text += "\n(%s)" % en
	preview_desc.text = desc
	var preview_color: Color = item.get("color", Color.WHITE)
	preview_swatch.color = preview_color
