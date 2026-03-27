extends Node2D

const INTERACTION_SPOT_SCENE := preload("res://interaction_spot.tscn")
const INTERACTION_SPAWN_EDGE_MARGIN := 150.0
const START_TEX_PATH := "res://resource/startbase.png"
const BOX_TEX_PATH := "res://resource/box.png"
const REST_TEX_PATH := "res://resource/rest.png"
const EVENT_FALLBACK_TEX_PATH := "res://resource/startbase.png"
const CARD_BASE_PATH := "res://resource/card_base.png"
const CARD_SCALE := 1.0 / 3.0
const SHOP_CARD_SCALE := 0.29
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

@onready var game_camera: Camera2D = $GameCamera
@onready var map_sprite: Sprite2D = $MapSprite
@onready var interaction_spots_root: Node2D = $InteractionSpots
@onready var year_value_label: Label = $UI/TopBar/TopBarContent/YearValueLabel
@onready var gold_value_label: Label = $UI/TopBar/TopBarContent/GoldValueLabel
@onready var health_value_label: Label = $UI/TopBar/TopBarContent/HealthValueLabel
@onready var mana_value_label: Label = $UI/TopBar/TopBarContent/ManaValueLabel
@onready var action_value_label: Label = $UI/TopBar/TopBarContent/ActionValueLabel
@onready var settings_popup: PanelContainer = $UI/SettingsPopup
@onready var deck_button: Button = $UI/TopBar/TopBarContent/DeckLibraryButton
@onready var deck_overlay: Control = $UI/DeckOverlay
@onready var deck_overlay_close_button: Button = $UI/DeckOverlay/Root/Panel/Content/VBox/TopRow/DeckOverlayCloseButton
@onready var deck_grid: GridContainer = $UI/DeckOverlay/Root/Panel/Content/VBox/Scroll/DeckGrid
@onready var deck_empty_hint: Label = $UI/DeckOverlay/Root/Panel/Content/VBox/DeckEmptyHint
@onready var interaction_popup: PanelContainer = $UI/InteractionPopup
@onready var interaction_type_label: Label = $UI/InteractionPopup/InteractionPopupContent/InteractionTypeLabel
@onready var interaction_end_button: Button = $UI/InteractionPopup/InteractionPopupContent/InteractionEndButton
@onready var start_interaction_popup: Control = $UI/StartInteractionPopup
@onready var start_popup_background: TextureRect = $UI/StartInteractionPopup/Center/DialogRoot/Background
@onready var start_bubble_label: Label = $UI/StartInteractionPopup/Center/DialogRoot/Content/VBox/BubbleRow/BubblePanel/BubbleLabel
@onready var start_options_row: HBoxContainer = $UI/StartInteractionPopup/Center/DialogRoot/Content/VBox/StartOptionsRow
@onready var shop_popup: PanelContainer = $UI/ShopPopup
@onready var shop_hint_label: Label = $UI/ShopPopup/Content/VBox/HintLabel
@onready var shop_grid: GridContainer = $UI/ShopPopup/Content/VBox/Scroll/ShopGrid
@onready var shop_continue_button: Button = $UI/ShopPopup/Content/VBox/BottomRow/ShopContinueButton
@onready var remove_overlay: Control = $UI/ShopPopup/RemoveCardOverlay
@onready var remove_hint_label: Label = $UI/ShopPopup/RemoveCardOverlay/Center/Panel/RemoveContent/RemoveVBox/RemoveHint
@onready var remove_deck_grid: GridContainer = $UI/ShopPopup/RemoveCardOverlay/Center/Panel/RemoveContent/RemoveVBox/RemoveScroll/RemoveDeckGrid
@onready var remove_cancel_button: Button = $UI/ShopPopup/RemoveCardOverlay/Center/Panel/RemoveContent/RemoveVBox/RemoveBottom/RemoveCancelButton

const START_DIALOG_PROMPT := "来了吗？"
const START_DIALOG_AFTER_CHOICE := "如你所愿。"

var game_data: Dictionary = {}
var year_events_config: Dictionary = {}
var _start_repo_pool: Array = []
var _event_repo_pool: Array = []
var _box_repo_pool: Array = []
var _shop_repo_pool: Array = []
var map_size := Vector2.ZERO
var _start_popup_start_tex: Texture2D = preload(START_TEX_PATH)
var _start_popup_box_tex: Texture2D = preload(BOX_TEX_PATH)
var _start_popup_rest_tex: Texture2D = preload(REST_TEX_PATH)
var _start_popup_event_fallback_tex: Texture2D = preload(EVENT_FALLBACK_TEX_PATH)
var _card_base_tex: Texture2D = preload(CARD_BASE_PATH)
var _shop_sold_indices: Dictionary = {}

func _ready() -> void:
	game_data = SaveManager.load_save()
	_ensure_player_deck_initialized()
	year_events_config = YearEventConfig.load_year_events()
	_start_repo_pool = StartRepoConfig.load_options()
	_event_repo_pool = EventRepoConfig.load_common_events()
	_box_repo_pool = BoxRepoConfig.load_options()
	_shop_repo_pool = ShopListConfig.load_items()
	_update_top_bar()
	_setup_map_bounds()
	_restore_or_spawn_interaction_spots()
	_bind_ui_events()
	settings_popup.visible = false
	interaction_popup.visible = false
	start_interaction_popup.visible = false
	shop_popup.visible = false
	remove_overlay.visible = false
	deck_overlay.visible = false

func _setup_map_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	map_size = viewport_size

	var texture := map_sprite.texture
	if texture == null:
		map_sprite.position = map_size * 0.5
		game_camera.position = map_size * 0.5
		return

	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		map_sprite.scale = Vector2(map_size.x / texture_size.x, map_size.y / texture_size.y)

	map_sprite.position = map_size * 0.5
	game_camera.position = map_size * 0.5

func _bind_ui_events() -> void:
	$UI/TopBar/TopBarContent/SettingsButton.pressed.connect(_on_settings_button_pressed)
	deck_button.pressed.connect(_on_deck_button_pressed)
	$UI/SettingsPopup/PopupContent/SaveGameButton.pressed.connect(_on_save_game_pressed)
	$UI/SettingsPopup/PopupContent/ExitButton.pressed.connect(_on_exit_pressed)
	$UI/SettingsPopup/PopupContent/CloseButton.pressed.connect(_on_close_settings_pressed)
	interaction_end_button.pressed.connect(_on_interaction_end_pressed)
	shop_continue_button.pressed.connect(_on_shop_continue_pressed)
	remove_cancel_button.pressed.connect(_on_remove_cancel_pressed)
	deck_overlay_close_button.pressed.connect(_on_deck_overlay_close_pressed)

func _seed_deck_for_role(role: String) -> Array:
	# 言灵初始牌库：5张id1，5张id2，3张id3，2张id4（允许重复卡）
	match role:
		"Wizard":
			return [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4]
		_:
			return []

func _ensure_player_deck_initialized() -> void:
	var deck_initialized := bool(game_data.get("deck_initialized", false))
	var raw_deck: Variant = game_data.get("player_deck", [])

	var deck_is_array := typeof(raw_deck) == TYPE_ARRAY
	var deck_is_empty := (not deck_is_array) or (raw_deck as Array).is_empty()

	# 兼容旧存档：如果还没跑过初始化，并且当前牌库为空/无效，则按角色规则补齐初始牌库。
	if not deck_initialized and deck_is_empty:
		var role := str(game_data.get("role", "Wizard"))
		game_data["player_deck"] = _seed_deck_for_role(role)
		game_data["deck_initialized"] = true
		SaveManager.save_game(game_data)
	elif not deck_initialized and deck_is_array and not deck_is_empty:
		# 已经有牌库内容了，只是初始化标记缺失；补齐标记即可。
		game_data["deck_initialized"] = true
		SaveManager.save_game(game_data)

func _on_deck_button_pressed() -> void:
	if deck_overlay.visible:
		_on_deck_overlay_close_pressed()
		return
	_refresh_deck_overlay()
	deck_overlay.visible = true

func _on_deck_overlay_close_pressed() -> void:
	deck_overlay.visible = false

func _refresh_deck_overlay() -> void:
	for c in deck_grid.get_children():
		c.queue_free()
	var raw_deck: Variant = game_data.get("player_deck", [])
	if typeof(raw_deck) != TYPE_ARRAY:
		deck_empty_hint.visible = true
		deck_empty_hint.text = "暂无牌"
		return
	var deck: Array = raw_deck
	if deck.is_empty():
		deck_empty_hint.visible = true
		deck_empty_hint.text = "暂无牌"
		return
	var card_map := _card_map_by_id()
	deck_empty_hint.visible = false
	for id_any in deck:
		var cid := int(id_any)
		if card_map.has(cid):
			deck_grid.add_child(_create_card_widget(card_map[cid] as Dictionary))

func _update_top_bar() -> void:
	year_value_label.text = str(int(game_data.get("year", 1)))
	gold_value_label.text = str(int(game_data.get("gold", 200)))
	health_value_label.text = "%d/%d" % [int(game_data.get("health", 50)), int(game_data.get("max_health", 50))]
	mana_value_label.text = "%d/%d" % [int(game_data.get("mana", 24)), int(game_data.get("max_mana", 24))]
	action_value_label.text = str(int(game_data.get("action", 3)))

func _on_settings_button_pressed() -> void:
	settings_popup.visible = true

func _on_close_settings_pressed() -> void:
	settings_popup.visible = false

func _on_save_game_pressed() -> void:
	_sync_interaction_spots_to_game_data()
	SaveManager.save_game(game_data)
	settings_popup.visible = false

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://mainPage.tscn")

func _clamp_spot_position(pos: Vector2) -> Vector2:
	var margin := INTERACTION_SPAWN_EDGE_MARGIN
	var max_x := map_size.x - margin
	var max_y := map_size.y - margin
	if max_x <= margin or max_y <= margin:
		return map_size * 0.5
	return Vector2(clampf(pos.x, margin, max_x), clampf(pos.y, margin, max_y))

func _clear_interaction_spots() -> void:
	for child in interaction_spots_root.get_children():
		child.queue_free()

func _sync_interaction_spots_to_game_data() -> void:
	var entries: Array = []
	for child in interaction_spots_root.get_children():
		if child is InteractionSpot:
			var spot := child as InteractionSpot
			entries.append({
				"type": spot.spot_type,
				"x": spot.position.x,
				"y": spot.position.y,
			})
	game_data["interaction_spots"] = entries

func _restore_or_spawn_interaction_spots() -> void:
	var raw: Variant = game_data.get("interaction_spots", [])
	if typeof(raw) == TYPE_ARRAY and not raw.is_empty():
		_load_interaction_spots_from_save(raw)
	else:
		_spawn_year_interaction_spots()

func _load_interaction_spots_from_save(entries: Array) -> void:
	_clear_interaction_spots()
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var t := str(d.get("type", ""))
		var spot: Node = INTERACTION_SPOT_SCENE.instantiate()
		if not spot is InteractionSpot:
			continue
		var area := spot as InteractionSpot
		area.spot_type = t
		area.position = _clamp_spot_position(Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0))))
		area.clicked.connect(_on_interaction_spot_clicked)
		interaction_spots_root.add_child(area)
	_sync_interaction_spots_to_game_data()

func _pick_build_type(build: Array) -> String:
	if build.is_empty():
		return ""
	var total_weight := 0.0
	for entry in build:
		if entry is Dictionary:
			total_weight += float(entry.get("probability", 0))
	if total_weight <= 0.0:
		return str((build[0] as Dictionary).get("type", ""))
	var roll := randf() * total_weight
	var acc := 0.0
	for entry in build:
		if entry is Dictionary:
			acc += float(entry.get("probability", 0))
			if roll <= acc:
				return str(entry.get("type", ""))
	return str((build[build.size() - 1] as Dictionary).get("type", ""))

func _spawn_year_interaction_spots() -> void:
	_clear_interaction_spots()
	var year_table: Variant = year_events_config.get("yearEvent", {})
	if typeof(year_table) != TYPE_DICTIONARY:
		_sync_interaction_spots_to_game_data()
		return
	var year_key := str(int(game_data.get("year", 1)))
	if not year_table.has(year_key):
		_sync_interaction_spots_to_game_data()
		return
	var cfg: Variant = year_table[year_key]
	if typeof(cfg) != TYPE_DICTIONARY:
		_sync_interaction_spots_to_game_data()
		return
	var count := int(cfg.get("count", 0))
	var build: Variant = cfg.get("build", [])
	if count <= 0 or typeof(build) != TYPE_ARRAY or build.is_empty():
		_sync_interaction_spots_to_game_data()
		return
	var margin := INTERACTION_SPAWN_EDGE_MARGIN
	var max_x := map_size.x - margin
	var max_y := map_size.y - margin
	if max_x <= margin or max_y <= margin:
		_sync_interaction_spots_to_game_data()
		return
	for _i in count:
		var spot: Node = INTERACTION_SPOT_SCENE.instantiate()
		if not spot is InteractionSpot:
			continue
		var area := spot as InteractionSpot
		area.spot_type = _pick_build_type(build)
		area.position = Vector2(randf_range(margin, max_x), randf_range(margin, max_y))
		area.clicked.connect(_on_interaction_spot_clicked)
		interaction_spots_root.add_child(area)
	_sync_interaction_spots_to_game_data()

func _on_interaction_spot_clicked(spot_type: String) -> void:
	if spot_type == "start":
		_show_start_interaction_popup()
		return
	if spot_type == "box":
		_show_box_interaction_popup()
		return
	if spot_type == "rest":
		_show_rest_interaction_popup()
		return
	if spot_type == "event":
		_show_event_interaction_popup()
		return
	interaction_popup.visible = false
	start_interaction_popup.visible = false
	shop_popup.visible = false
	interaction_type_label.text = spot_type
	interaction_popup.visible = true

func _on_interaction_end_pressed() -> void:
	interaction_popup.visible = false
	_advance_year_and_respawn()

func _advance_year_and_respawn() -> void:
	game_data["year"] = int(game_data.get("year", 1)) + 1
	_update_top_bar()
	_spawn_year_interaction_spots()

func _apply_attr_changes(changes: Array) -> void:
	for item in changes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var attr := str(d.get("changeAttr", ""))
		if attr.is_empty():
			continue
		var delta := int(round(float(d.get("changeAmount", 0))))
		var cur := int(round(float(game_data.get(attr, 0))))
		game_data[attr] = cur + delta

func _pick_three_start_options() -> Array:
	if _start_repo_pool.is_empty():
		return []
	var indices: Array = range(_start_repo_pool.size())
	indices.shuffle()
	var n: int = mini(3, indices.size())
	var out: Array = []
	for i in n:
		var entry: Variant = _start_repo_pool[indices[i]]
		if entry is Dictionary:
			out.append((entry as Dictionary).duplicate(true))
	return out

func _rebuild_start_option_buttons(choices: Array) -> void:
	for c in start_options_row.get_children():
		c.queue_free()
	for entry in choices:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry as Dictionary
		var btn := Button.new()
		btn.text = str(d.get("context", ""))
		btn.custom_minimum_size = Vector2(220, 52)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_start_option_chosen.bind(d.duplicate(true)))
		start_options_row.add_child(btn)

func _show_start_interaction_popup() -> void:
	var choices := _pick_three_start_options()
	if choices.is_empty():
		interaction_type_label.text = "start"
		interaction_popup.visible = true
		return
	start_popup_background.texture = _start_popup_start_tex
	start_bubble_label.text = START_DIALOG_PROMPT
	interaction_popup.visible = false
	_rebuild_start_option_buttons(choices)
	start_interaction_popup.visible = true

func _show_start_continue_only_ui() -> void:
	for c in start_options_row.get_children():
		c.queue_free()
	var btn := Button.new()
	btn.text = "继续"
	btn.custom_minimum_size = Vector2(220, 52)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(_on_start_continue_pressed)
	start_options_row.add_child(btn)

func _on_start_continue_pressed() -> void:
	start_interaction_popup.visible = false
	shop_popup.visible = false
	_advance_year_and_respawn()

func _on_start_option_chosen(entry: Dictionary) -> void:
	var changes: Variant = entry.get("change", [])
	if changes is Array:
		_apply_attr_changes(changes)
	_update_top_bar()
	start_bubble_label.text = START_DIALOG_AFTER_CHOICE
	_show_start_continue_only_ui()

func _pick_one_common_event() -> Dictionary:
	if _event_repo_pool.is_empty():
		return {}
	var idx := randi_range(0, _event_repo_pool.size() - 1)
	var entry: Variant = _event_repo_pool[idx]
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}

func _apply_effect_map(effect_raw: Variant) -> void:
	if not effect_raw is Dictionary:
		return
	var effect: Dictionary = effect_raw as Dictionary
	for k in effect.keys():
		var key := str(k)
		if key.is_empty():
			continue
		var cur := int(round(float(game_data.get(key, 0))))
		var delta := int(round(float(effect[k])))
		game_data[key] = cur + delta
	_clamp_primary_resources()

func _show_event_interaction_popup() -> void:
	var event_entry := _pick_one_common_event()
	if event_entry.is_empty():
		interaction_type_label.text = "event"
		interaction_popup.visible = true
		return

	interaction_popup.visible = false
	shop_popup.visible = false
	start_interaction_popup.visible = true

	var img_path := str(event_entry.get("img", ""))
	var tex := load(img_path) as Texture2D if not img_path.is_empty() else null
	if tex == null:
		tex = _start_popup_event_fallback_tex
	start_popup_background.texture = tex

	var event_title := str(event_entry.get("event", "未知事件"))
	var event_desc := str(event_entry.get("desc", ""))
	start_bubble_label.text = "[%s]\n%s" % [event_title, event_desc]

	for c in start_options_row.get_children():
		c.queue_free()

	var choose_raw: Variant = event_entry.get("choose", [])
	if not choose_raw is Array:
		_show_start_continue_only_ui()
		return
	var chooses: Array = choose_raw
	for i in chooses.size():
		var option_raw: Variant = chooses[i]
		if not option_raw is Dictionary:
			continue
		var option := option_raw as Dictionary
		var btn := Button.new()
		btn.text = str(option.get("desc", "选项"))
		btn.custom_minimum_size = Vector2(260, 52)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_event_option_chosen.bind(option.duplicate(true)))
		start_options_row.add_child(btn)

	if start_options_row.get_child_count() == 0:
		_show_start_continue_only_ui()

func _on_event_option_chosen(option: Dictionary) -> void:
	_apply_effect_map(option.get("effect", {}))
	_update_top_bar()
	var after_text := str(option.get("after", ""))
	if after_text.is_empty():
		after_text = "你选择了：%s" % str(option.get("desc", ""))
	start_bubble_label.text = after_text
	_show_start_continue_only_ui()

func _pick_one_box_option() -> Dictionary:
	if _box_repo_pool.is_empty():
		return {}
	var idx := randi_range(0, _box_repo_pool.size() - 1)
	var entry: Variant = _box_repo_pool[idx]
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}

func _show_box_interaction_popup() -> void:
	start_popup_background.texture = _start_popup_box_tex
	start_bubble_label.text = "一个宝箱，可以打开它"
	interaction_popup.visible = false
	for c in start_options_row.get_children():
		c.queue_free()
	var btn := Button.new()
	btn.text = "打开"
	btn.custom_minimum_size = Vector2(220, 52)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(_on_box_open_pressed)
	start_options_row.add_child(btn)
	start_interaction_popup.visible = true

func _on_box_open_pressed() -> void:
	var entry := _pick_one_box_option()
	if entry.is_empty():
		start_bubble_label.text = "宝箱里空空如也。"
		_show_start_continue_only_ui()
		return
	var changes: Variant = entry.get("change", [])
	if changes is Array:
		_apply_attr_changes(changes)
	_update_top_bar()
	start_bubble_label.text = str(entry.get("context", "宝箱里有些收获。"))
	_show_start_continue_only_ui()

func _show_rest_interaction_popup() -> void:
	start_popup_background.texture = _start_popup_rest_tex
	start_bubble_label.text = "这是一个奇异宝珠"
	interaction_popup.visible = false
	shop_popup.visible = false
	for c in start_options_row.get_children():
		c.queue_free()

	var heal_btn := Button.new()
	heal_btn.text = "用来疗伤，恢复50%血量"
	heal_btn.custom_minimum_size = Vector2(260, 52)
	heal_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heal_btn.pressed.connect(_on_rest_heal_pressed)
	start_options_row.add_child(heal_btn)

	var summon_btn := Button.new()
	summon_btn.text = "尝试召唤"
	summon_btn.custom_minimum_size = Vector2(220, 52)
	summon_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summon_btn.pressed.connect(_on_rest_summon_pressed)
	start_options_row.add_child(summon_btn)
	start_interaction_popup.visible = true

func _on_rest_heal_pressed() -> void:
	var max_hp := int(game_data.get("max_health", 0))
	var cur_hp := int(game_data.get("health", 0))
	var add_hp := maxi(0, int(floor(float(max_hp) * 0.5)))
	game_data["health"] = mini(max_hp, cur_hp + add_hp)
	_update_top_bar()
	start_bubble_label.text = "宝珠的光辉修复了你的伤势。"
	_show_start_continue_only_ui()

func _on_rest_summon_pressed() -> void:
	start_bubble_label.text = "你召唤了无名幽魂"
	for c in start_options_row.get_children():
		c.queue_free()
	var trade_btn := Button.new()
	trade_btn.text = "交易"
	trade_btn.custom_minimum_size = Vector2(220, 52)
	trade_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_btn.pressed.connect(_on_rest_trade_pressed)
	start_options_row.add_child(trade_btn)

func _on_rest_trade_pressed() -> void:
	start_interaction_popup.visible = false
	_open_shop_popup()

func _open_shop_popup() -> void:
	_shop_sold_indices.clear()
	remove_overlay.visible = false
	shop_popup.visible = true
	shop_hint_label.text = "点击商品购买"
	_rebuild_shop_items()

func _card_map_by_id() -> Dictionary:
	var cards := WizardInfoConfig.load_cards()
	var out: Dictionary = {}
	for item in cards:
		if item is Dictionary:
			var d := item as Dictionary
			var cid := int(d.get("card_id", 0))
			if cid != 0 and not out.has(cid):
				out[cid] = d
	return out

func _rebuild_shop_items() -> void:
	for c in shop_grid.get_children():
		c.queue_free()
	var card_map := _card_map_by_id()
	for i in _shop_repo_pool.size():
		var raw: Variant = _shop_repo_pool[i]
		if not raw is Dictionary:
			continue
		var item := raw as Dictionary
		var wrap := VBoxContainer.new()
		wrap.custom_minimum_size = Vector2(260, 430)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(260, 350)
		btn.clip_contents = true
		btn.flat = true
		btn.toggle_mode = false
		btn.disabled = _shop_sold_indices.get(i, false)
		btn.pressed.connect(_on_shop_item_pressed.bind(i))
		var desc_text := _shop_item_desc(item, card_map)
		btn.mouse_entered.connect(_on_shop_item_hovered.bind(desc_text))
		btn.mouse_exited.connect(_on_shop_item_hover_exited)

		var t := str(item.get("type", ""))
		if t == "card":
			var attr_raw: Variant = item.get("attr", {})
			var cid := 0
			if attr_raw is Dictionary:
				var attr: Dictionary = attr_raw
				cid = int(attr.get("card_id", 0))
			if card_map.has(cid):
				btn.add_child(_create_card_widget(card_map[cid] as Dictionary, SHOP_CARD_SCALE))
			else:
				btn.text = "%s\ncard_id=%d" % [str(item.get("shop_name", "未知卡牌")), cid]
		else:
			var img_path := str(item.get("img", ""))
			var tex := load(img_path) as Texture2D if not img_path.is_empty() else null
			if tex == null:
				tex = _start_popup_box_tex
			var tex_rect := TextureRect.new()
			tex_rect.layout_mode = CONTROL_LAYOUT_ANCHORS
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.texture = tex
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tex_rect)
			btn.text = ""

		var name_label := Label.new()
		name_label.text = str(item.get("shop_name", "商品"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var price_label := Label.new()
		var sold := bool(_shop_sold_indices.get(i, false))
		var price := int(item.get("price", 0))
		price_label.text = "售罄" if sold else ("价格: %d" % price)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		wrap.add_child(btn)
		wrap.add_child(name_label)
		wrap.add_child(price_label)
		shop_grid.add_child(wrap)

func _shop_item_desc(item: Dictionary, card_map: Dictionary) -> String:
	var custom_desc := str(item.get("desc", ""))
	if not custom_desc.is_empty():
		return custom_desc
	var t := str(item.get("type", ""))
	if t == "card":
		var attr_raw: Variant = item.get("attr", {})
		if attr_raw is Dictionary:
			var attr: Dictionary = attr_raw
			var cid := int(attr.get("card_id", 0))
			if card_map.has(cid):
				return str((card_map[cid] as Dictionary).get("desc", ""))
		return "购买后加入牌库。"
	if t == "elixir":
		return "购买后直接获得药剂属性加成。"
	if t == "remove":
		return "购买后可从当前牌库删除一张牌。"
	return "点击购买该商品。"

func _on_shop_item_hovered(desc_text: String) -> void:
	if desc_text.is_empty():
		shop_hint_label.text = "点击商品购买"
	else:
		shop_hint_label.text = desc_text

func _on_shop_item_hover_exited() -> void:
	shop_hint_label.text = "点击商品购买"

func _on_shop_item_pressed(idx: int) -> void:
	if bool(_shop_sold_indices.get(idx, false)):
		return
	if idx < 0 or idx >= _shop_repo_pool.size():
		return
	var raw: Variant = _shop_repo_pool[idx]
	if not raw is Dictionary:
		return
	var item := raw as Dictionary
	var price := int(item.get("price", 0))
	var gold := int(game_data.get("gold", 0))
	if gold < price:
		shop_hint_label.text = "金币不足"
		return

	var ok := _apply_shop_item_effect(item)
	if not ok:
		shop_hint_label.text = "该商品暂不可购买"
		return

	game_data["gold"] = gold - price
	_update_top_bar()
	_shop_sold_indices[idx] = true
	shop_hint_label.text = "%s 已购买" % str(item.get("shop_name", "商品"))
	_rebuild_shop_items()

func _apply_shop_item_effect(item: Dictionary) -> bool:
	var t := str(item.get("type", ""))
	if t == "card":
		var attr_raw: Variant = item.get("attr", {})
		if not attr_raw is Dictionary:
			return false
		var attr: Dictionary = attr_raw
		var cid := int(attr.get("card_id", 0))
		if cid == 0:
			return false
		var deck: Array = game_data.get("player_deck", [])
		deck.append(cid)
		game_data["player_deck"] = deck
		return true

	if t == "elixir":
		var attr2_raw: Variant = item.get("attr", {})
		if not attr2_raw is Dictionary:
			return false
		var attr2: Dictionary = attr2_raw
		for k in attr2.keys():
			var key := str(k)
			var cur := int(game_data.get(key, 0))
			var delta := int(round(float(attr2.get(k, 0))))
			game_data[key] = cur + delta
		_clamp_primary_resources()
		return true

	if t == "remove":
		_show_remove_overlay()
		return true

	return false

func _clamp_primary_resources() -> void:
	var max_health := int(game_data.get("max_health", 0))
	var max_mana := int(game_data.get("max_mana", 0))
	var max_action := int(game_data.get("max_action", 0))

	game_data["health"] = clampi(int(game_data.get("health", 0)), 0, max_health)
	game_data["mana"] = clampi(int(game_data.get("mana", 0)), 0, max_mana)
	game_data["action"] = clampi(int(game_data.get("action", 0)), 0, max_action)

func _show_remove_overlay() -> void:
	var deck_raw: Variant = game_data.get("player_deck", [])
	if typeof(deck_raw) != TYPE_ARRAY:
		shop_hint_label.text = "当前牌库为空，无法删牌"
		return
	var deck := deck_raw as Array
	if deck.is_empty():
		shop_hint_label.text = "当前牌库为空，无法删牌"
		return
	for c in remove_deck_grid.get_children():
		c.queue_free()
	var card_map := _card_map_by_id()
	for i in deck.size():
		var cid := int(deck[i])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(250, 120)
		btn.text = "删除卡牌 id=%d" % cid
		if card_map.has(cid):
			btn.text = "删除：%s (id=%d)" % [str((card_map[cid] as Dictionary).get("card_name", "卡牌")), cid]
		btn.pressed.connect(_on_remove_card_selected.bind(i, cid))
		remove_deck_grid.add_child(btn)
	remove_hint_label.text = "点击任意卡牌执行删除"
	remove_overlay.visible = true

func _on_remove_card_selected(deck_idx: int, cid: int) -> void:
	var deck_raw: Variant = game_data.get("player_deck", [])
	if typeof(deck_raw) != TYPE_ARRAY:
		return
	var deck := (deck_raw as Array).duplicate()
	if deck_idx < 0 or deck_idx >= deck.size():
		return
	deck.remove_at(deck_idx)
	game_data["player_deck"] = deck
	remove_overlay.visible = false
	shop_hint_label.text = "已删除卡牌 id=%d" % cid

func _on_remove_cancel_pressed() -> void:
	remove_overlay.visible = false

func _on_shop_continue_pressed() -> void:
	shop_popup.visible = false
	remove_overlay.visible = false
	_on_start_continue_pressed()

func _create_card_widget(card: Dictionary, scale: float = CARD_SCALE) -> Control:
	var full_size := _card_base_tex.get_size()
	var card_size := full_size * scale
	var root := Control.new()
	root.custom_minimum_size = card_size
	# 用于嵌入商品按钮时，不拦截点击事件（否则按钮 pressed 不会触发）
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var m := scale
	var cost_font_sz := clampi(int(round(56.0 * m)), 15, 22)
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

func _card_stat_int_str(card: Dictionary, key: String) -> String:
	var v: Variant = card.get(key, 0)
	if typeof(v) == TYPE_INT:
		return str(v)
	if typeof(v) == TYPE_FLOAT:
		return str(int(round(v)))
	return str(int(round(float(v))))
