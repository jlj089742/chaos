extends Node2D

@onready var game_camera: Camera2D = $GameCamera
@onready var map_sprite: Sprite2D = $MapSprite
@onready var year_value_label: Label = $UI/TopBar/TopBarContent/YearValueLabel
@onready var gold_value_label: Label = $UI/TopBar/TopBarContent/GoldValueLabel
@onready var settings_popup: PanelContainer = $UI/SettingsPopup

var game_data: Dictionary = {}
var is_dragging := false
var map_size := Vector2.ZERO

func _ready() -> void:
	game_data = SaveManager.load_save()
	_update_top_bar()
	_setup_map_bounds()
	_bind_ui_events()
	settings_popup.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
	elif event is InputEventMouseMotion and is_dragging:
		# Dragging the map is implemented by moving camera opposite to mouse motion.
		game_camera.position -= event.relative
		_clamp_camera()

func _setup_map_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	map_size = viewport_size * 3.0

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
	_clamp_camera()

func _clamp_camera() -> void:
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size * 0.5
	var min_pos := half_view
	var max_pos := map_size - half_view

	# If the map is smaller than viewport, keep centered safely.
	if min_pos.x > max_pos.x:
		min_pos.x = map_size.x * 0.5
		max_pos.x = min_pos.x
	if min_pos.y > max_pos.y:
		min_pos.y = map_size.y * 0.5
		max_pos.y = min_pos.y

	game_camera.position.x = clampf(game_camera.position.x, min_pos.x, max_pos.x)
	game_camera.position.y = clampf(game_camera.position.y, min_pos.y, max_pos.y)

func _bind_ui_events() -> void:
	$UI/TopBar/TopBarContent/SettingsButton.pressed.connect(_on_settings_button_pressed)
	$UI/SettingsPopup/PopupContent/SaveGameButton.pressed.connect(_on_save_game_pressed)
	$UI/SettingsPopup/PopupContent/ExitButton.pressed.connect(_on_exit_pressed)
	$UI/SettingsPopup/PopupContent/CloseButton.pressed.connect(_on_close_settings_pressed)

func _update_top_bar() -> void:
	year_value_label.text = str(int(game_data.get("year", 1)))
	gold_value_label.text = str(int(game_data.get("gold", 1000)))

func _on_settings_button_pressed() -> void:
	settings_popup.visible = true

func _on_close_settings_pressed() -> void:
	settings_popup.visible = false

func _on_save_game_pressed() -> void:
	SaveManager.save_game(game_data)
	settings_popup.visible = false

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://mainPage.tscn")
