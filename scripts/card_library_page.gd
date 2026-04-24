extends Control

const ROLE_WIZARD := "Wizard" # 言灵
const ROLE_MASTER := "Master" # 大道
const ROLE_SWORD := "Sword" # 剑修
const ROLE_BEAST := "Beast" # 妖兽

const CARD_SCALE := 1.0 / 3.0

@onready var back_button: Button = $BackButton
@onready var wizard_tab: Button = $MainMargin/MainVBox/TabRow/WizardTab
@onready var master_tab: Button = $MainMargin/MainVBox/TabRow/MasterTab
@onready var sword_tab: Button = $MainMargin/MainVBox/TabRow/SwordTab
@onready var beast_tab: Button = $MainMargin/MainVBox/TabRow/BeastTab
@onready var card_grid: GridContainer = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/CardGrid
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
	_refresh_cards()

func _select_role(role: String) -> void:
	_current_role = role
	_refresh_cards()

func _refresh_cards() -> void:
	for c in card_grid.get_children():
		c.queue_free()
	empty_hint.visible = false
	var cards := CardCatalog.load_cards_by_role(_current_role)
	if cards.is_empty() and (_current_role == ROLE_MASTER or _current_role == ROLE_SWORD):
		empty_hint.visible = true
		empty_hint.text = "敬请期待"
		return
	if cards.is_empty():
		empty_hint.visible = true
		empty_hint.text = "暂无卡牌数据"
		return
	for item in cards:
		if item is Dictionary:
			card_grid.add_child(CardUIFactory.create_card_widget(item as Dictionary, CARD_SCALE))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://mainPage.tscn")
