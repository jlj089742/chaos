extends RefCounted
class_name CardCatalog

const ROLE_WIZARD := "Wizard"

static func load_cards_by_role(role: String) -> Array:
	if role == ROLE_WIZARD:
		return WizardInfoConfig.load_cards()
	if role == "Beast":
		return MonsterInfoConfig.load_cards()
	return []

static func build_card_map(include_wizard: bool = true, include_monster: bool = true) -> Dictionary:
	var out: Dictionary = {}
	if include_wizard:
		_append_cards_to_map(out, WizardInfoConfig.load_cards())
	if include_monster:
		_append_cards_to_map(out, MonsterInfoConfig.load_cards())
	return out

static func build_card_pool_ids_for_role(role: String, reward_one_only: bool = false) -> Array:
	var ids: Array = []
	for item in WizardInfoConfig.load_cards():
		if not (item is Dictionary):
			continue
		var d := item as Dictionary
		if reward_one_only and int(d.get("reward", 0)) != 1:
			continue
		var cid := int(d.get("card_id", 0))
		if cid == 0:
			continue
		var roles_raw: Variant = d.get("roles", null)
		if roles_raw is Array:
			var rs: Array = roles_raw
			for r in rs:
				if str(r) == role:
					ids.append(cid)
					break
		elif role == ROLE_WIZARD:
			ids.append(cid)
	if ids.is_empty():
		for item2 in WizardInfoConfig.load_cards():
			if not (item2 is Dictionary):
				continue
			var d2 := item2 as Dictionary
			if reward_one_only and int(d2.get("reward", 0)) != 1:
				continue
			var cid2 := int(d2.get("card_id", 0))
			if cid2 != 0:
				ids.append(cid2)
	return ids

static func _append_cards_to_map(out: Dictionary, cards: Array) -> void:
	for item in cards:
		if not (item is Dictionary):
			continue
		var d := item as Dictionary
		var cid := int(d.get("card_id", 0))
		if cid != 0 and not out.has(cid):
			out[cid] = d
