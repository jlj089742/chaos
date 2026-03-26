extends Node2D

const INTERACTION_SPOT_SCENE := preload("res://interaction_spot.tscn")
const INTERACTION_SPAWN_EDGE_MARGIN := 150.0

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
@onready var interaction_popup: PanelContainer = $UI/InteractionPopup
@onready var interaction_type_label: Label = $UI/InteractionPopup/InteractionPopupContent/InteractionTypeLabel
@onready var interaction_end_button: Button = $UI/InteractionPopup/InteractionPopupContent/InteractionEndButton
@onready var start_interaction_popup: Control = $UI/StartInteractionPopup
@onready var start_bubble_label: Label = $UI/StartInteractionPopup/Center/DialogRoot/Content/VBox/BubbleRow/BubblePanel/BubbleLabel
@onready var start_options_row: HBoxContainer = $UI/StartInteractionPopup/Center/DialogRoot/Content/VBox/StartOptionsRow

const START_DIALOG_PROMPT := "来了吗？"
const START_DIALOG_AFTER_CHOICE := "如你所愿。"

var game_data: Dictionary = {}
var year_events_config: Dictionary = {}
var _start_repo_pool: Array = []
var map_size := Vector2.ZERO

func _ready() -> void:
	game_data = SaveManager.load_save()
	_ensure_player_deck_initialized()
	year_events_config = YearEventConfig.load_year_events()
	_start_repo_pool = StartRepoConfig.load_options()
	_update_top_bar()
	_setup_map_bounds()
	_restore_or_spawn_interaction_spots()
	_bind_ui_events()
	settings_popup.visible = false
	interaction_popup.visible = false
	start_interaction_popup.visible = false

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
	# 进入牌库前同步存档数据，确保用户在不手动存档时也能看到最新牌库。
	_sync_interaction_spots_to_game_data()
	SaveManager.save_game(game_data)
	settings_popup.visible = false
	get_tree().change_scene_to_file("res://deckLibrary.tscn")

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
	interaction_popup.visible = false
	start_interaction_popup.visible = false
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
	_advance_year_and_respawn()

func _on_start_option_chosen(entry: Dictionary) -> void:
	var changes: Variant = entry.get("change", [])
	if changes is Array:
		_apply_attr_changes(changes)
	_update_top_bar()
	start_bubble_label.text = START_DIALOG_AFTER_CHOICE
	_show_start_continue_only_ui()
