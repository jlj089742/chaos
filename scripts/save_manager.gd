extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"
const DEFAULT_SAVE := {
	"year": 1,
	"gold": 1000,
	"health": 50,
	"interaction_spots": []
}

static func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return DEFAULT_SAVE.duplicate(true)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return DEFAULT_SAVE.duplicate(true)

	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return DEFAULT_SAVE.duplicate(true)

	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return DEFAULT_SAVE.duplicate(true)

	var data: Dictionary = parsed
	if not data.has("year"):
		data["year"] = DEFAULT_SAVE["year"]
	if not data.has("gold"):
		data["gold"] = DEFAULT_SAVE["gold"]
	if not data.has("health"):
		data["health"] = DEFAULT_SAVE["health"]
	if not data.has("interaction_spots") or typeof(data["interaction_spots"]) != TYPE_ARRAY:
		data["interaction_spots"] = []

	return data

static func write_fresh_save() -> bool:
	return save_game(DEFAULT_SAVE.duplicate(true))

static func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
