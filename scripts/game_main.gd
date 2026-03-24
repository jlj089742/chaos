extends Node2D

const INTERACTION_SPOT_SCENE := preload("res://interaction_spot.tscn")

@onready var game_camera: Camera2D = $GameCamera
@onready var map_sprite: Sprite2D = $MapSprite
@onready var interaction_spots_root: Node2D = $InteractionSpots
@onready var year_value_label: Label = $UI/TopBar/TopBarContent/YearValueLabel
@onready var gold_value_label: Label = $UI/TopBar/TopBarContent/GoldValueLabel
@onready var health_value_label: Label = $UI/TopBar/TopBarContent/HealthValueLabel
@onready var settings_popup: PanelContainer = $UI/SettingsPopup
@onready var interaction_popup: PanelContainer = $UI/InteractionPopup
@onready var interaction_type_label: Label = $UI/InteractionPopup/InteractionPopupContent/InteractionTypeLabel
@onready var interaction_end_button: Button = $UI/InteractionPopup/InteractionPopupContent/InteractionEndButton

var game_data: Dictionary = {}
var year_events_config: Dictionary = {}
var map_size := Vector2.ZERO

func _ready() -> void:
	game_data = SaveManager.load_save()
	game_data["health"] = 50
	year_events_config = YearEventConfig.load_year_events()
	_update_top_bar()
	_setup_map_bounds()
	_restore_or_spawn_interaction_spots()
	_bind_ui_events()
	settings_popup.visible = false
	interaction_popup.visible = false

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
	$UI/SettingsPopup/PopupContent/SaveGameButton.pressed.connect(_on_save_game_pressed)
	$UI/SettingsPopup/PopupContent/ExitButton.pressed.connect(_on_exit_pressed)
	$UI/SettingsPopup/PopupContent/CloseButton.pressed.connect(_on_close_settings_pressed)
	interaction_end_button.pressed.connect(_on_interaction_end_pressed)

func _update_top_bar() -> void:
	year_value_label.text = str(int(game_data.get("year", 1)))
	gold_value_label.text = str(int(game_data.get("gold", 1000)))
	health_value_label.text = str(int(game_data.get("health", 50)))

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
	var margin := maxf(48.0, minf(map_size.x, map_size.y) * 0.05)
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
	var margin := maxf(48.0, minf(map_size.x, map_size.y) * 0.05)
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
	interaction_type_label.text = spot_type
	interaction_popup.visible = true

func _on_interaction_end_pressed() -> void:
	interaction_popup.visible = false
	game_data["year"] = int(game_data.get("year", 1)) + 1
	_update_top_bar()
	_spawn_year_interaction_spots()
