extends RefCounted
class_name BattleRepoConfig

const CONFIG_PATH := "res://config/battle_repo.json"

static func load_table() -> Dictionary:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("BattleRepoConfig: 无法打开 %s" % CONFIG_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("BattleRepoConfig: JSON 根节点须为对象")
		return {}
	return (parsed as Dictionary).duplicate(true)


static func entries_for_year(year: int) -> Array:
	var table := load_table()
	var key := str(year)
	if not table.has(key) or typeof(table[key]) != TYPE_ARRAY:
		if table.has("1") and typeof(table["1"]) == TYPE_ARRAY:
			return table["1"] as Array
		return []
	return table[key] as Array
