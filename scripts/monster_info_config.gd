extends RefCounted
class_name MonsterInfoConfig

const CONFIG_PATH := "res://config/monster_info.json"

static func load_cards() -> Array:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("MonsterInfoConfig: 无法打开 %s" % CONFIG_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MonsterInfoConfig: JSON 根节点须为对象")
		return []
	var raw: Variant = (parsed as Dictionary).get("cards", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in raw:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate(true))
	return out

static func load_magic_weapons() -> Array:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("MonsterInfoConfig: 无法打开 %s" % CONFIG_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MonsterInfoConfig: JSON 根节点须为对象")
		return []
	var raw: Variant = (parsed as Dictionary).get("magic_weapon", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in raw:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate(true))
	return out
