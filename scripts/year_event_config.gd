extends RefCounted
class_name YearEventConfig

const CONFIG_PATH := "res://config/year_events.json"

static func load_year_events() -> Dictionary:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("YearEventConfig: 无法打开 %s" % CONFIG_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("YearEventConfig: JSON 格式无效")
		return {}
	return parsed
