extends RefCounted
class_name ShopListConfig

const CONFIG_PATH := "res://config/shop_list.json"

static func load_items() -> Array:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("ShopListConfig: 无法打开 %s" % CONFIG_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ShopListConfig: JSON 根节点须为对象")
		return []
	var out: Array = []
	var keys: Array = (parsed as Dictionary).keys()
	keys.sort_custom(_shop_key_less)
	for k in keys:
		var v: Variant = (parsed as Dictionary)[k]
		if typeof(v) != TYPE_DICTIONARY:
			continue
		out.append((v as Dictionary).duplicate(true))
	return out

static func _shop_key_less(a: Variant, b: Variant) -> bool:
	var sa := str(a)
	var sb := str(b)
	var a_is_int := sa.is_valid_int()
	var b_is_int := sb.is_valid_int()
	if a_is_int and b_is_int:
		return int(sa) < int(sb)
	if a_is_int != b_is_int:
		return a_is_int
	return sa < sb

