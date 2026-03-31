extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"
const DEFAULT_SAVE := {
	"year": 1,
	"gold": 200,
	"role": "Wizard",
	# 玩家牌库（允许重复卡，数组内存放 card_id）
	"player_deck": [],
	# 用于兼容旧存档：旧存档会触发首次初始化逻辑
	"deck_initialized": false,
	"max_health": 50,
	"health": 50,
	"max_mana": 36,
	"mana": 36,
	"max_action": 3,
	"action": 3,
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
	if not data.has("role"):
		data["role"] = DEFAULT_SAVE["role"]

	if not data.has("player_deck") or typeof(data["player_deck"]) != TYPE_ARRAY:
		data["player_deck"] = []
	if not data.has("deck_initialized") or typeof(data["deck_initialized"]) != TYPE_BOOL:
		data["deck_initialized"] = false

	if not data.has("max_health"):
		data["max_health"] = DEFAULT_SAVE["max_health"]
	if not data.has("health"):
		data["health"] = DEFAULT_SAVE["health"]

	if not data.has("max_mana"):
		data["max_mana"] = DEFAULT_SAVE["max_mana"]
	if not data.has("mana"):
		data["mana"] = DEFAULT_SAVE["mana"]

	if not data.has("max_action"):
		data["max_action"] = DEFAULT_SAVE["max_action"]
	if not data.has("action"):
		data["action"] = DEFAULT_SAVE["action"]

	if not data.has("interaction_spots") or typeof(data["interaction_spots"]) != TYPE_ARRAY:
		data["interaction_spots"] = []

	return data

static func write_fresh_save() -> bool:
	return save_game(DEFAULT_SAVE.duplicate(true))

static func fresh_save_for_role(role: String) -> Dictionary:
	# Only Wizard is implemented right now.
	# Other roles are placeholders until their initial stats/background assets exist.
	var out := DEFAULT_SAVE.duplicate(true)
	out["role"] = role
	match role:
		"Wizard":
			# 言灵初始牌库：5张id1，5张id2，3张id3，2张id4（允许重复卡）
			out["player_deck"] = [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4]
			out["deck_initialized"] = true
			out["max_health"] = 50
			out["health"] = 50
			out["max_mana"] = 36
			out["mana"] = 36
			out["max_action"] = 3
			out["action"] = 3
		_:
			out["player_deck"] = []
			out["deck_initialized"] = true
			# Keep default Wizard stats for now.
			out["max_health"] = 50
			out["health"] = 50
			out["max_mana"] = 36
			out["mana"] = 36
			out["max_action"] = 3
			out["action"] = 3
	return out

static func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
