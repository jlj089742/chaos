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


## `battle_repo.json` 根下按指定 key 取战斗条目数组。
## 例如事件战斗可用 key 为 `"event01"`。
static func entries_for_key(key: String) -> Array:
	var table := load_table()
	var k := str(key)
	if not table.has(k):
		return []
	if typeof(table[k]) != TYPE_ARRAY:
		return []
	return table[k] as Array


## `battle_repo.json` 根下 `"boss"` 数组，供 Boss 交互点开战使用（与普通关卡年份池无关）。
static func boss_entries() -> Array:
	var table := load_table()
	if not table.has("boss") or typeof(table["boss"]) != TYPE_ARRAY:
		return []
	return table["boss"] as Array
