extends RefCounted
class_name CardUIFactory

const CARD_BASE_PATH := "res://resource/card_base.png"
const CONTROL_LAYOUT_ANCHORS := 1

const _CARD_REF_W := 736.0
const _CARD_REF_H := 1024.0
const _COST_CIRCLE_R := 53.0
const _MP_CIRCLE_CX := 95.0
const _ACT_CIRCLE_CX := 640.0
const _COST_CIRCLE_CY := 100.0
const _MP_COST_L := (_MP_CIRCLE_CX - _COST_CIRCLE_R) / _CARD_REF_W
const _MP_COST_R := (_MP_CIRCLE_CX + _COST_CIRCLE_R) / _CARD_REF_W
const _ACT_COST_L := (_ACT_CIRCLE_CX - _COST_CIRCLE_R) / _CARD_REF_W
const _ACT_COST_R := (_ACT_CIRCLE_CX + _COST_CIRCLE_R) / _CARD_REF_W
const _COST_BOX_T := (_COST_CIRCLE_CY - _COST_CIRCLE_R) / _CARD_REF_H
const _COST_BOX_B := (_COST_CIRCLE_CY + _COST_CIRCLE_R) / _CARD_REF_H

static var _card_base_tex: Texture2D = preload(CARD_BASE_PATH)

static func get_base_texture_size() -> Vector2:
	return _card_base_tex.get_size()

static func create_card_widget(card: Dictionary, scale: float, ignore_mouse: bool = false) -> Control:
	var full_size := _card_base_tex.get_size()
	var card_size := full_size * scale
	var root := Control.new()
	root.custom_minimum_size = card_size
	if ignore_mouse:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cost_font_sz := clampi(int(round(56.0 * scale)), 15, 22)
	var body_font_sz := clampi(int(round(38.0 * scale)), 10, 16)
	var name_font_sz := clampi(int(round(44.0 * scale)), 12, 18)

	var bg := TextureRect.new()
	bg.layout_mode = CONTROL_LAYOUT_ANCHORS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = _card_base_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var mp := _build_cost_label(_card_stat_int_str(card, "mp_cost"), cost_font_sz, _MP_COST_L, _MP_COST_R)
	root.add_child(mp)
	var act := _build_cost_label(_card_stat_int_str(card, "action_cost"), cost_font_sz, _ACT_COST_L, _ACT_COST_R)
	root.add_child(act)

	var name_label := Label.new()
	name_label.layout_mode = CONTROL_LAYOUT_ANCHORS
	name_label.text = str(card.get("card_name", ""))
	name_label.add_theme_font_size_override("font_size", name_font_sz)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.set_anchor(SIDE_LEFT, 85.0 / _CARD_REF_W)
	name_label.set_anchor(SIDE_RIGHT, 650.0 / _CARD_REF_W)
	name_label.set_anchor(SIDE_TOP, 160.0 / _CARD_REF_H)
	name_label.set_anchor(SIDE_BOTTOM, 420.0 / _CARD_REF_H)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)

	var desc := Label.new()
	desc.layout_mode = CONTROL_LAYOUT_ANCHORS
	desc.text = str(card.get("desc", ""))
	desc.add_theme_font_size_override("font_size", body_font_sz)
	desc.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	desc.set_anchor(SIDE_LEFT, 85.0 / _CARD_REF_W)
	desc.set_anchor(SIDE_RIGHT, 650.0 / _CARD_REF_W)
	desc.set_anchor(SIDE_TOP, 615.0 / _CARD_REF_H)
	desc.set_anchor(SIDE_BOTTOM, 935.0 / _CARD_REF_H)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(desc)

	return root

static func _build_cost_label(text: String, font_size: int, left_anchor: float, right_anchor: float) -> Label:
	var lbl := Label.new()
	lbl.layout_mode = CONTROL_LAYOUT_ANCHORS
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	lbl.set_anchor(SIDE_LEFT, left_anchor)
	lbl.set_anchor(SIDE_RIGHT, right_anchor)
	lbl.set_anchor(SIDE_TOP, _COST_BOX_T)
	lbl.set_anchor(SIDE_BOTTOM, _COST_BOX_B)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

static func _card_stat_int_str(card: Dictionary, key: String) -> String:
	var v: Variant = card.get(key, 0)
	if typeof(v) == TYPE_INT:
		return str(v)
	if typeof(v) == TYPE_FLOAT:
		return str(int(round(v)))
	return str(int(round(float(v))))
