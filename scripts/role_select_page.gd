extends Control

const ROLE_WIZARD := "Wizard" # 言灵
const ROLE_MASTER := "Master" # 大道
const ROLE_SWORD := "Sword" # 剑修

const WIZARD_TEX_PATH := "res://resource/wizard2.png"
const MASTER_TEX_PATH := "res://resource/master.png"
const SWORD_TEX_PATH := "res://resource/sword.png"

var _wizard_tex: Texture2D = preload(WIZARD_TEX_PATH)

@onready var background: TextureRect = $Background
@onready var bubble_label: Label = $BubblePanel/BubbleLabel
@onready var confirm_button: Button = $ConfirmButtonCorner

@onready var wizard_button: Button = $BottomContainer/RoleButtonsRow/WizardPanel/WizardButton
@onready var master_button: Button = $BottomContainer/RoleButtonsRow/MasterPanel/MasterButton
@onready var sword_button: Button = $BottomContainer/RoleButtonsRow/SwordPanel/SwordButton

var selected_role: String = ROLE_WIZARD

func _ready() -> void:
	wizard_button.pressed.connect(func(): _set_selected_role(ROLE_WIZARD))
	master_button.pressed.connect(func(): _set_selected_role(ROLE_MASTER))
	sword_button.pressed.connect(func(): _set_selected_role(ROLE_SWORD))
	confirm_button.pressed.connect(_on_confirm_pressed)

	_set_selected_role(ROLE_WIZARD)

func _set_selected_role(role: String) -> void:
	selected_role = role
	_sync_ui_for_selected_role()

func _sync_ui_for_selected_role() -> void:
	# Confirm is only available for Wizard right now.
	confirm_button.disabled = selected_role != ROLE_WIZARD

	# Role introduction bubble.
	if selected_role == ROLE_WIZARD:
		bubble_label.text = "言灵\n破坏力非凡，追求高效爆发\n生命70/70\n法力36/36\n行动力3"
	else:
		bubble_label.text = "敬请期待"

	# Background: only Wizard has an image right now.
	# For other roles, the background should be empty (no texture).
	if selected_role == ROLE_WIZARD:
		background.texture = _wizard_tex
		background.modulate = Color(1, 1, 1, 1)
	else:
		background.texture = null

	# Selection highlight.
	var selected_color := Color(1, 1, 1, 1)
	var unselected_color := Color(0.65, 0.65, 0.65, 1)
	wizard_button.modulate = selected_color if selected_role == ROLE_WIZARD else unselected_color
	master_button.modulate = selected_color if selected_role == ROLE_MASTER else unselected_color
	sword_button.modulate = selected_color if selected_role == ROLE_SWORD else unselected_color

func _on_confirm_pressed() -> void:
	if selected_role != ROLE_WIZARD:
		return
	SaveManager.save_game(SaveManager.fresh_save_for_role(selected_role))
	get_tree().change_scene_to_file("res://gameMain.tscn")
