extends Control

@onready var start_new_game_button: Button = $CenterButtons/StartNewGameButton
@onready var view_save_button: Button = $CenterButtons/ViewSaveButton

func _ready() -> void:
	start_new_game_button.pressed.connect(_on_start_new_game_pressed)
	view_save_button.pressed.connect(_on_view_save_pressed)

func _on_start_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://gameMain.tscn")

func _on_view_save_pressed() -> void:
	get_tree().change_scene_to_file("res://savePage.tscn")
