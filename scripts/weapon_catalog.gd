extends RefCounted
class_name WeaponCatalog

const ROLE_WIZARD := "Wizard"
const ROLE_MASTER := "Master"
const ROLE_SWORD := "Sword"
const ROLE_BEAST := "Beast"

static func build_weapon_map(include_wizard: bool = true, include_monster: bool = true) -> Dictionary:
	var out: Dictionary = {}
	if include_wizard:
		_append_weapons_to_map(out, WizardInfoConfig.load_magic_weapons())
	if include_monster:
		_append_weapons_to_map(out, MonsterInfoConfig.load_magic_weapons())
	return out

static func build_weapon_map_for_role(role: String) -> Dictionary:
	match role:
		ROLE_WIZARD:
			return _build_weapon_map_from_list(WizardInfoConfig.load_magic_weapons())
		ROLE_BEAST:
			return _build_weapon_map_from_list(MonsterInfoConfig.load_magic_weapons())
		ROLE_MASTER, ROLE_SWORD:
			return {}
		_:
			return {}

static func _append_weapons_to_map(out: Dictionary, weapons: Array) -> void:
	for item in weapons:
		if not (item is Dictionary):
			continue
		var w := item as Dictionary
		var wid := int(w.get("weapon_id", 0))
		if wid != 0 and not out.has(wid):
			out[wid] = w

static func _build_weapon_map_from_list(weapons: Array) -> Dictionary:
	var out: Dictionary = {}
	_append_weapons_to_map(out, weapons)
	return out
