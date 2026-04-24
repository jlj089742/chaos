extends Control

const ROLE_WIZARD := "Wizard" # 言灵
const ROLE_MASTER := "Master" # 大道
const ROLE_SWORD := "Sword" # 剑修
const ROLE_BEAST := "Beast" # 妖兽

@onready var back_button: Button = $BackButton
@onready var wizard_tab: Button = $MainMargin/MainVBox/TabRow/WizardTab
@onready var master_tab: Button = $MainMargin/MainVBox/TabRow/MasterTab
@onready var sword_tab: Button = $MainMargin/MainVBox/TabRow/SwordTab
@onready var beast_tab: Button = $MainMargin/MainVBox/TabRow/BeastTab
@onready var weapon_list_vbox: VBoxContainer = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/WeaponListVBox
@onready var empty_hint: Label = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/EmptyHint

var _current_role: String = ROLE_WIZARD

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	var tab_group := ButtonGroup.new()
	wizard_tab.toggle_mode = true
	master_tab.toggle_mode = true
	sword_tab.toggle_mode = true
	beast_tab.toggle_mode = true
	wizard_tab.button_group = tab_group
	master_tab.button_group = tab_group
	sword_tab.button_group = tab_group
	beast_tab.button_group = tab_group
	wizard_tab.pressed.connect(func(): _select_role(ROLE_WIZARD))
	master_tab.pressed.connect(func(): _select_role(ROLE_MASTER))
	sword_tab.pressed.connect(func(): _select_role(ROLE_SWORD))
	beast_tab.pressed.connect(func(): _select_role(ROLE_BEAST))
	wizard_tab.button_pressed = true
	_current_role = ROLE_WIZARD
	_refresh_weapons()

func _select_role(role: String) -> void:
	_current_role = role
	_refresh_weapons()

func _refresh_weapons() -> void:
	for c in weapon_list_vbox.get_children():
		c.queue_free()
	empty_hint.visible = false

	var weapon_map := WeaponCatalog.build_weapon_map_for_role(_current_role)
	var ids := weapon_map.keys()
	if ids.is_empty() and (_current_role == ROLE_MASTER or _current_role == ROLE_SWORD):
		empty_hint.visible = true
		empty_hint.text = "敬请期待"
		return
	if ids.is_empty():
		empty_hint.visible = true
		empty_hint.text = "暂无法宝数据"
		return

	ids.sort()
	for id_any in ids:
		var wid := int(id_any)
		var w: Dictionary = weapon_map[wid] as Dictionary
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 88)
		weapon_list_vbox.add_child(panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		margin.add_child(vb)

		var title := Label.new()
		title.text = "【%s】(id=%d)" % [str(w.get("weapon_name", "未知法宝")), wid]
		title.add_theme_font_size_override("font_size", 18)
		vb.add_child(title)

		var effect_raw: Variant = w.get("effect", {})
		var weapon_buff_raw: Variant = {}
		if effect_raw is Dictionary:
			weapon_buff_raw = (effect_raw as Dictionary).get("weapon_buff", {})
		var desc := ""
		if weapon_buff_raw is Dictionary:
			desc = str((weapon_buff_raw as Dictionary).get("buff_desc", ""))
		var desc_label := Label.new()
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.text = "效果：%s" % desc
		vb.add_child(desc_label)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://mainPage.tscn")
