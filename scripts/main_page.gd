extends Control

@onready var start_new_game_button: Button = $CenterButtons/StartNewGameButton
@onready var view_save_button: Button = $CenterButtons/ViewSaveButton
@onready var view_card_library_button: Button = $CenterButtons/ViewCardLibraryButton
@onready var view_weapon_library_button: Button = $CenterButtons/ViewWeaponLibraryButton

func _ready() -> void:
	start_new_game_button.pressed.connect(_on_start_new_game_pressed)
	view_save_button.pressed.connect(_on_view_save_pressed)
	view_card_library_button.pressed.connect(_on_view_card_library_pressed)
	view_weapon_library_button.pressed.connect(_on_view_weapon_library_pressed)

func _on_start_new_game_pressed() -> void:
	SaveManager.write_fresh_save()
	get_tree().change_scene_to_file("res://roleSelect.tscn")

func _on_view_save_pressed() -> void:
	get_tree().change_scene_to_file("res://savePage.tscn")

func _on_view_card_library_pressed() -> void:
	get_tree().change_scene_to_file("res://cardLibrary.tscn")

func _on_view_weapon_library_pressed() -> void:
	get_tree().change_scene_to_file("res://weaponLibrary.tscn")
