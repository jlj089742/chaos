extends RefCounted
class_name StartRepoConfig

const CONFIG_PATH := "res://config/start_repo.json"

static func load_options() -> Array:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("StartRepoConfig: 无法打开 %s" % CONFIG_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StartRepoConfig: JSON 根节点须为对象")
		return []
	var out: Array = []
	var keys: Array = (parsed as Dictionary).keys()
	keys.sort()
	for k in keys:
		var v: Variant = (parsed as Dictionary)[k]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = v
		if not d.has("context") or not d.has("change"):
			continue
		if typeof(d["change"]) != TYPE_ARRAY:
			continue
		out.append(d)
	return out
