extends RefCounted
class_name EventRepoConfig

const CONFIG_PATH := "res://config/event_repo.json"

## 返回 `common` 字段下的事件表（key -> event 定义）。
## 仅包含满足基础字段要求（event/img/desc/choose）的条目。
static func load_common_events_table() -> Dictionary:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("EventRepoConfig: 无法打开 %s" % CONFIG_PATH)
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EventRepoConfig: JSON 根节点须为对象")
		return {}

	var root: Dictionary = parsed as Dictionary
	var common_any: Variant = root.get("common", {})
	if typeof(common_any) != TYPE_DICTIONARY:
		push_error("EventRepoConfig: common 字段须为对象")
		return {}

	var common: Dictionary = common_any as Dictionary
	var out: Dictionary = {}

	var keys: Array = common.keys()
	keys.sort()
	for k in keys:
		var v: Variant = common[k]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = v
		if not d.has("event") or not d.has("img") or not d.has("desc") or not d.has("choose"):
			continue
		if typeof(d.get("choose", [])) != TYPE_ARRAY:
			continue
		out[str(k)] = d.duplicate(true)

	return out

static func load_common_events() -> Array:
	var table := load_common_events_table()
	var out: Array = []
	# 保持与原先相同的“按 key 排序”的展示稳定性
	var keys := table.keys()
	keys.sort()
	for k in keys:
		var d: Variant = table[k]
		if d is Dictionary:
			# 仅允许 type=common 的事件进入“随机事件池”
			# type 字段缺失时不参与随机，避免特殊事件被抽中
			var dict := d as Dictionary
			if not dict.has("type"):
				continue
			var t: Variant = dict.get("type", "")
			if str(t) == "common":
				out.append(d)
	return out
