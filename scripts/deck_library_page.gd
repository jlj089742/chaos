extends Control

const CARD_SCALE := 1.0 / 3.0

@onready var back_button: Button = $BackButton
@onready var card_grid: GridContainer = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/CardGrid
@onready var empty_hint: Label = $MainMargin/MainVBox/Scroll/MarginInner/ContentVBox/EmptyHint

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
	var by_id := CardCatalog.build_card_map(true, false)

	empty_hint.visible = false
	for id_any in deck:
		var cid := int(id_any)
		if not by_id.has(cid):
			continue
		card_grid.add_child(CardUIFactory.create_card_widget(by_id[cid] as Dictionary, CARD_SCALE))
	_apply_grid_layout()

func _on_view_resized() -> void:
	_apply_grid_layout()

func _apply_grid_layout() -> void:
	var columns := 5
	card_grid.columns = columns

	var card_width := CardUIFactory.get_base_texture_size().x * CARD_SCALE
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
