extends Control

const CARD_BASE_PATH := "res://resource/card_base.png"
const CARD_SCALE := 1.0 / 3.0
## Control.layout_mode：锚点布局（引擎内为 LAYOUT_MODE_ANCHORS；GDScript 未暴露同名常量时用 1）
const CONTROL_LAYOUT_ANCHORS := 1

## card_base.png 参考尺寸与圆框（左上角 mp、右上角 action），与资源一致时可保证数字落在圆内
const _CARD_REF_W := 736.0
const _CARD_REF_H := 1024.0
const _COST_CIRCLE_R := 53.0
const _MP_CIRCLE_CX := 95.0
const _ACT_CIRCLE_CX := 640.0
const _COST_CIRCLE_CY := 100.0
## 归一化锚点：Label 填满圆的外接矩形，文字水平垂直居中
const _MP_COST_L := (_MP_CIRCLE_CX - _COST_CIRCLE_R) / _CARD_REF_W
const _MP_COST_R := (_MP_CIRCLE_CX + _COST_CIRCLE_R) / _CARD_REF_W
const _ACT_COST_L := (_ACT_CIRCLE_CX - _COST_CIRCLE_R) / _CARD_REF_W
const _ACT_COST_R := (_ACT_CIRCLE_CX + _COST_CIRCLE_R) / _CARD_REF_W
const _COST_BOX_T := (_COST_CIRCLE_CY - _COST_CIRCLE_R) / _CARD_REF_H
const _COST_BOX_B := (_COST_CIRCLE_CY + _COST_CIRCLE_R) / _CARD_REF_H

@onready var back_button: Button = $BackButton
@onready var card_grid: GridContainer = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/CardGrid
@onready var empty_hint: Label = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/EmptyHint

var _card_base_tex: Texture2D = preload(CARD_BASE_PATH)

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_on_view_resized)
	_apply_grid_layout()
	_render_deck()
	call_deferred("_apply_grid_layout")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://gameMain.tscn")

func _render_deck() -> void:
	for c in card_grid.get_children():
		c.queue_free()

	var save := SaveManager.load_save()
	var raw_deck: Variant = save.get("player_deck", [])
	if typeof(raw_deck) != TYPE_ARRAY:
		raw_deck = []
	var deck: Array = raw_deck as Array

	if deck.is_empty():
		empty_hint.visible = true
		empty_hint.text = "暂无牌"
		return

	# 目前只实现言灵配置的卡池展示：用 card_id 映射配置里的卡牌信息
	var all_cards := WizardInfoConfig.load_cards()
	var by_id: Dictionary = {}
	for item in all_cards:
		if item is Dictionary:
			var d := item as Dictionary
			var cid := int(d.get("card_id", 0))
			if cid != 0 and not by_id.has(cid):
				by_id[cid] = d

	empty_hint.visible = false
	for id_any in deck:
		var cid := int(id_any)
		if not by_id.has(cid):
			continue
		card_grid.add_child(_create_card_widget(by_id[cid] as Dictionary))
	_apply_grid_layout()

func _on_view_resized() -> void:
	_apply_grid_layout()

func _apply_grid_layout() -> void:
	var columns := 5
	card_grid.columns = columns

	var card_width := _card_base_tex.get_size().x * CARD_SCALE
	if card_width <= 0.0:
		return

	var available_width := card_grid.size.x
	if available_width <= 0.0:
		return

	# 让一行 5 张尽量排满：gap = (总宽 - 5*卡宽) / 4，并限制到较舒适区间
	var raw_gap := (available_width - card_width * columns) / float(columns - 1)
	var h_gap := int(round(clampf(raw_gap, 24.0, 64.0)))
	card_grid.add_theme_constant_override("h_separation", h_gap)
	card_grid.add_theme_constant_override("v_separation", 28)

func _card_stat_int_str(card: Dictionary, key: String) -> String:
	var v: Variant = card.get(key, 0)
	if typeof(v) == TYPE_INT:
		return str(v)
	if typeof(v) == TYPE_FLOAT:
		return str(int(round(v)))
	return str(int(round(float(v))))

func _create_card_widget(card: Dictionary) -> Control:
	var full_size := _card_base_tex.get_size()
	var card_size := full_size * CARD_SCALE
	var root := Control.new()
	root.custom_minimum_size = card_size

	var m := CARD_SCALE
	## 圆内数字：原图约 50–60px 高，1/3 卡约 16–20（按 56*m 取整并限制可读范围）
	var cost_font_sz := clampi(int(round(56.0 * m)), 15, 22)
	# 描述文字随卡牌缩放同比变化，同时提高基础可读性
	var body_font_sz := clampi(int(round(38.0 * m)), 10, 16)
	var name_font_sz := clampi(int(round(44.0 * m)), 12, 18)

	var bg := TextureRect.new()
	bg.layout_mode = CONTROL_LAYOUT_ANCHORS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = _card_base_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var mp := Label.new()
	mp.layout_mode = CONTROL_LAYOUT_ANCHORS
	mp.text = _card_stat_int_str(card, "mp_cost")
	mp.add_theme_font_size_override("font_size", cost_font_sz)
	mp.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	mp.set_anchor(SIDE_LEFT, _MP_COST_L)
	mp.set_anchor(SIDE_RIGHT, _MP_COST_R)
	mp.set_anchor(SIDE_TOP, _COST_BOX_T)
	mp.set_anchor(SIDE_BOTTOM, _COST_BOX_B)
	mp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mp)

	var act := Label.new()
	act.layout_mode = CONTROL_LAYOUT_ANCHORS
	act.text = _card_stat_int_str(card, "action_cost")
	act.add_theme_font_size_override("font_size", cost_font_sz)
	act.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	act.set_anchor(SIDE_LEFT, _ACT_COST_L)
	act.set_anchor(SIDE_RIGHT, _ACT_COST_R)
	act.set_anchor(SIDE_TOP, _COST_BOX_T)
	act.set_anchor(SIDE_BOTTOM, _COST_BOX_B)
	act.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	act.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(act)

	var name_label := Label.new()
	name_label.layout_mode = CONTROL_LAYOUT_ANCHORS
	name_label.text = str(card.get("card_name", ""))
	name_label.add_theme_font_size_override("font_size", name_font_sz)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	# 标题区：约在 y≈160 以下的装饰框内
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
	# 底部说明区：约在 y 615–935
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

