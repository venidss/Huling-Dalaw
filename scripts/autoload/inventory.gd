extends Node
## Inventory singleton for DAET: ANG PAMANA.
##
## Stores collected items with id/name/description/icon_color/category/story_relevant flag.
## Items are defined by id and looked up from an in-memory database so pickups just reference
## the id. Keys, documents and photographs are all handled through the same system.

signal item_added(item: Dictionary)
signal item_removed(item_id: String)
signal inventory_changed

const CATEGORY_KEY := "key"
const CATEGORY_DOCUMENT := "document"
const CATEGORY_PHOTO := "photograph"
const CATEGORY_QUEST := "quest"
const CATEGORY_TOOL := "tool"

# Item database. Icon color is used by the UI to represent each item without external art.
var _database: Dictionary = {
	"flashlight": {
		"name": "Lumang Flashlight",
		"name_en": "Old Flashlight",
		"description": "Luma ngunit gumagana pa. Lola gave it to you when the sun went down.",
		"category": CATEGORY_TOOL,
		"color": Color(0.9, 0.85, 0.4),
		"story_relevant": true,
	},
	"key_upstairs": {
		"name": "Susi sa Taas",
		"name_en": "Upstairs Key",
		"description": "Isang maliit na tansong susi. May nakalagay na \"T\" sa likod.",
		"category": CATEGORY_KEY,
		"color": Color(0.75, 0.55, 0.2),
		"story_relevant": true,
	},
	"key_locked_room": {
		"name": "Susi ng Nakakandadong Silid",
		"name_en": "Locked Room Key",
		"description": "Mabigat at kinakalawang. Mabigat ang pakiramdam na dinadala mo ito.",
		"category": CATEGORY_KEY,
		"color": Color(0.5, 0.35, 0.15),
		"story_relevant": true,
	},
	"key_passage": {
		"name": "Susi ng Lagusan",
		"name_en": "Passage Key",
		"description": "Hindi mukhang susi ng kahit anong pinto na nakita mo pa.",
		"category": CATEGORY_KEY,
		"color": Color(0.4, 0.3, 0.5),
		"story_relevant": true,
	},
	"diary": {
		"name": "Lumang Talaarawan",
		"name_en": "Old Diary",
		"description": "Talaarawan ni Lola. Mahirap basahin — ilan sa mga pahina ay napunit.",
		"category": CATEGORY_DOCUMENT,
		"color": Color(0.5, 0.3, 0.2),
		"story_relevant": true,
	},
	"photo_family": {
		"name": "Larawan ng Pamilya",
		"name_en": "Family Photograph",
		"description": "Lola, Lolo, at tatlong bata — ngunit alam mo lang ang dalawa sa kanila.",
		"category": CATEGORY_PHOTO,
		"color": Color(0.6, 0.5, 0.4),
		"story_relevant": true,
	},
	"photo_tala": {
		"name": "Larawan ni Tala",
		"name_en": "Photograph of Tala",
		"description": "Isang batang babae sa likod ng bahay. Nasusunog ang isang gilid ng larawan.",
		"category": CATEGORY_PHOTO,
		"color": Color(0.4, 0.3, 0.25),
		"story_relevant": true,
	},
	"letter_lolo": {
		"name": "Sulat ni Lolo",
		"name_en": "Lolo's Letter",
		"description": "Isang sulat na hindi natapos. Mabigat ang mga salita.",
		"category": CATEGORY_DOCUMENT,
		"color": Color(0.8, 0.75, 0.6),
		"story_relevant": true,
	},
	"fuse": {
		"name": "Fuse",
		"name_en": "Fuse",
		"description": "Ceramic fuse. Baka mayroon namang kulang sa fuse box.",
		"category": CATEGORY_TOOL,
		"color": Color(0.7, 0.6, 0.3),
		"story_relevant": true,
	},
	"rosary": {
		"name": "Rosaryo ni Lola",
		"name_en": "Lola's Rosary",
		"description": "Mainit sa iyong palad. May nararamdaman kang pagbati — o babala.",
		"category": CATEGORY_QUEST,
		"color": Color(0.8, 0.75, 0.9),
		"story_relevant": true,
	},
	"ember": {
		"name": "Nagbabagang Baga",
		"name_en": "Smoldering Ember",
		"description": "Umiinit pa rin — ngunit walang apoy. Nakakatakot kung paano ito nananatiling mainit.",
		"category": CATEGORY_QUEST,
		"color": Color(0.9, 0.3, 0.1),
		"story_relevant": true,
	},
}

var _items: Array[Dictionary] = []

func get_definition(item_id: String) -> Dictionary:
	return _database.get(item_id, {}).duplicate(true)

func add_item(item_id: String) -> bool:
	if not _database.has(item_id):
		push_warning("Inventory: unknown item id '%s'" % item_id)
		return false
	if has_item(item_id):
		return false  # unique items only — the design does not stack
	var def := get_definition(item_id)
	def["id"] = item_id
	_items.append(def)
	item_added.emit(def)
	inventory_changed.emit()
	return true

func remove_item(item_id: String) -> bool:
	for i in _items.size():
		if _items[i]["id"] == item_id:
			_items.remove_at(i)
			item_removed.emit(item_id)
			inventory_changed.emit()
			return true
	return false

func has_item(item_id: String) -> bool:
	for it in _items:
		if it["id"] == item_id:
			return true
	return false

func get_all() -> Array[Dictionary]:
	return _items.duplicate(true)

func clear() -> void:
	_items.clear()
	inventory_changed.emit()

func serialize() -> Array:
	var result: Array = []
	for it in _items:
		result.append(it["id"])
	return result

func deserialize(ids: Array) -> void:
	_items.clear()
	for id in ids:
		if _database.has(id):
			var def := get_definition(id)
			def["id"] = id
			_items.append(def)
	inventory_changed.emit()
