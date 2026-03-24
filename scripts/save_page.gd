extends Control

@onready var save_slot_label: Label = $CenterPanel/SlotContainer/SaveSlotLabel
@onready var start_from_save_button: Button = $CenterPanel/SlotContainer/StartFromSaveButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	_refresh_slot()
	start_from_save_button.pressed.connect(_on_start_from_save_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _refresh_slot() -> void:
	var data := SaveManager.load_save()
	save_slot_label.text = "默认存档槽\n年份: %d\n金币: %d" % [int(data["year"]), int(data["gold"])]

func _on_start_from_save_pressed() -> void:
	get_tree().change_scene_to_file("res://gameMain.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://mainPage.tscn")
