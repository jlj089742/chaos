extends RefCounted
class_name EventRepoConfig

const CONFIG_PATH := "res://config/event_repo.json"

static func load_common_events() -> Array:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("EventRepoConfig: 无法打开 %s" % CONFIG_PATH)
		return []
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EventRepoConfig: JSON 根节点须为对象")
		return []

	var root: Dictionary = parsed as Dictionary
	var common_any: Variant = root.get("common", {})
	if typeof(common_any) != TYPE_DICTIONARY:
		push_error("EventRepoConfig: common 字段须为对象")
		return []

	var common: Dictionary = common_any as Dictionary
	var keys: Array = common.keys()
	keys.sort()

	var out: Array = []
	for k in keys:
		var v: Variant = common[k]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = v
		if not d.has("event") or not d.has("img") or not d.has("desc") or not d.has("choose"):
			continue
		if typeof(d.get("choose", [])) != TYPE_ARRAY:
			continue
		out.append(d)
	return out
