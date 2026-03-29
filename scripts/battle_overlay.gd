extends Control

## 战斗 UI 与回合流程。卡牌真正生效的逻辑入口为 `_apply_battle_card_effect`。

const HAND_CARD_SCALE := 0.22
const HAND_MAX := 8
const FALLBACK_ENEMY_TEX := "res://resource/battle/battle01.png"
const _DRAW_ENTER_SEC := 0.26
const _DRAW_SHOWCASE_HOLD_SEC := 0.18
const _DRAW_TO_HAND_SEC := 0.3
const _DRAW_OFFSCREEN_PAD := 64.0
const _STAT_TWEEN_SEC := 0.5

## 统一伤害结算：伤害来源（谁造成本次结算的基础伤害）
const DAMAGE_SOURCE_CARD := "card"
const DAMAGE_SOURCE_PLAYER_BUFF := "player_buff"
const DAMAGE_SOURCE_ENEMY_ATTACK := "enemy_attack"
const DAMAGE_SOURCE_ENEMY_BUFF := "enemy_buff"

## 统一伤害结算：伤害目标
const DAMAGE_TARGET_PLAYER := "player"
const DAMAGE_TARGET_ENEMY := "enemy"

## 玩家身上「下一次造成伤害翻倍」的可叠加 buff；结算 outgoing 伤害时每层翻倍一次并消耗一层。
## 规范：① `buff_type` 为 legacy `"damage_double"`；② `buff_type` 为 `"damage"` 且 `double_damage` > 0（如通明）。
const BUFF_TYPE_DAMAGE_DOUBLE := "damage_double"

## 战斗页右上角「？」气泡的提示全文。多行请直接在本字符串里换行。
const BATTLE_HELP_HINT_TEXT := "战斗说明：\n卡牌左上角为法力值消耗，右上角为行动力消耗。\n卡牌选中后放置在中间区域，即可生效\n初始手牌3张，每回合默认抽2张牌\n法力值每场战斗开始时恢复满\n行动力每回合开始时恢复满"

@onready var _play_zone: Control = $PlayZone
@onready var _hand: HBoxContainer = $HandContainer
@onready var _draw_anim_layer: Control = $DrawAnimLayer
@onready var _drag_layer: Control = $DragLayer
@onready var _end_turn: Button = $EndTurnButton
@onready var _enemy_tex: TextureRect = $MonsterRow/EnemyAvatarColumn/EnemyTexture
@onready var _enemy_buff_row: HBoxContainer = $MonsterRow/EnemyAvatarColumn/EnemyBuffRow
@onready var _enemy_name: Label = $MonsterRow/EnemyInfo/EnemyNameLabel
@onready var _enemy_hp: Label = $MonsterRow/EnemyInfo/EnemyHealthLabel
@onready var _player_tex: TextureRect = $PlayerRow/PlayerAvatarColumn/PlayerTexture
@onready var _player_buff_row: HBoxContainer = $PlayerRow/PlayerAvatarColumn/PlayerBuffRow
@onready var _player_tip_bubble: PanelContainer = $PlayerRow/PlayerAvatarColumn/PlayerTipBubble
@onready var _player_tip_label: Label = $PlayerRow/PlayerAvatarColumn/PlayerTipBubble/PlayerTipLabel
@onready var _player_hp: Label = $PlayerRow/PlayerInfo/PlayerHealthLabel
@onready var _player_shield: Label = $PlayerRow/PlayerInfo/PlayerShieldLabel
@onready var _player_mana: Label = $PlayerRow/PlayerInfo/PlayerManaLabel
@onready var _player_act: Label = $PlayerRow/PlayerInfo/PlayerActionLabel
@onready var _help_hint_button: Button = $BattleHelpRoot/HelpHintButton
@onready var _help_hint_bubble: PanelContainer = $BattleHelpRoot/HelpHintBubble
@onready var _help_hint_label: Label = $BattleHelpRoot/HelpHintBubble/HelpHintLabel

var _game_main: Node = null
var _game_data: Dictionary = {}

var _card_map: Dictionary = {}
var _draw_pile: Array = []
var _discard: Array = []
## 手牌实例：每张牌独立一条，支持同 id 多张
var _hand_entries: Array = []

var _monster_entry: Dictionary = {}
var _monster_hp: int = 0
## 战斗内护盾，不入存档；开局 0，仅本场有效
var _battle_shield: int = 0

var _player_turn: bool = true

var _dragging_button: Button = null
var _dragging_cid: int = 0
var _drag_pickup_offset: Vector2 = Vector2.ZERO
var _drag_hand_index: int = 0

## 战斗内 buff，不入存档；双方各一列表
var _player_buffs: Array = []
var _enemy_buffs: Array = []
var _play_resolve_in_progress: bool = false
var _tip_tween: Tween = null
var _stat_display_tween: Tween = null

func setup(main: Node) -> void:
	_game_main = main


func _ready() -> void:
	_end_turn.pressed.connect(_on_end_turn_pressed)
	_help_hint_button.pressed.connect(_on_help_hint_button_pressed)
	_setup_player_tip_bubble_style()
	_setup_help_hint_ui()
	set_process(false)


func _setup_player_tip_bubble_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.16, 0.22, 0.92)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_player_tip_bubble.add_theme_stylebox_override("panel", sb)


func _setup_help_hint_ui() -> void:
	var bubble_sb := StyleBoxFlat.new()
	bubble_sb.bg_color = Color(0.12, 0.13, 0.2, 0.96)
	bubble_sb.set_corner_radius_all(10)
	bubble_sb.content_margin_left = 12
	bubble_sb.content_margin_right = 12
	bubble_sb.content_margin_top = 10
	bubble_sb.content_margin_bottom = 10
	bubble_sb.set_border_width_all(1)
	bubble_sb.border_color = Color(0.35, 0.38, 0.48, 0.9)
	_help_hint_bubble.add_theme_stylebox_override("panel", bubble_sb)
	_help_hint_label.text = BATTLE_HELP_HINT_TEXT
	var r := 20.0
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.22, 0.24, 0.32, 0.92)
	btn_normal.set_corner_radius_all(int(r))
	btn_normal.set_border_width_all(1)
	btn_normal.border_color = Color(0.45, 0.48, 0.58, 0.85)
	var btn_hover := btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.28, 0.3, 0.4, 0.95)
	var btn_pressed := btn_normal.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.18, 0.2, 0.28, 0.98)
	_help_hint_button.add_theme_stylebox_override("normal", btn_normal)
	_help_hint_button.add_theme_stylebox_override("hover", btn_hover)
	_help_hint_button.add_theme_stylebox_override("pressed", btn_pressed)
	_help_hint_button.add_theme_color_override("font_color", Color(0.92, 0.93, 0.96))
	_help_hint_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_help_hint_button.add_theme_color_override("font_pressed_color", Color(0.85, 0.86, 0.9))


func _on_help_hint_button_pressed() -> void:
	if _help_hint_bubble.visible:
		_help_hint_bubble.visible = false
	else:
		_help_hint_label.text = BATTLE_HELP_HINT_TEXT
		_help_hint_bubble.visible = true


func _hide_help_hint_bubble() -> void:
	if _help_hint_bubble != null:
		_help_hint_bubble.visible = false


func _show_player_tip(text: String) -> void:
	if _player_tip_label == null or _player_tip_bubble == null:
		return
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_player_tip_label.text = text
	_player_tip_bubble.visible = true
	_player_tip_bubble.modulate = Color(1, 1, 1, 1)
	_tip_tween = create_tween()
	_tip_tween.tween_interval(1.35)
	_tip_tween.tween_property(_player_tip_bubble, "modulate:a", 0.0, 0.32)
	_tip_tween.tween_callback(func() -> void:
		_player_tip_bubble.visible = false
		_player_tip_bubble.modulate = Color(1, 1, 1, 1)
		_tip_tween = null
	)


func _input(event: InputEvent) -> void:
	if not visible or _dragging_button == null:
		return
	if _play_resolve_in_progress:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			_resolve_drag_click_at_global_mouse()


func _process(_delta: float) -> void:
	if _dragging_button != null:
		_dragging_button.global_position = get_global_mouse_position() + _drag_pickup_offset


func start_battle() -> void:
	print("start_battle!")
	if _game_main == null:
		return
	visible = true
	_game_data = _game_main.game_data
	# 进入战斗：生命沿用顶栏/存档当前值；法力与行动力回满（行动力每回合开始在 _begin_player_turn 再次回满）。
	_game_data["mana"] = int(_game_data.get("max_mana", 0))
	_game_data["action"] = int(_game_data.get("max_action", 0))
	if _game_main.has_method("_clamp_primary_resources"):
		_game_main._clamp_primary_resources()
	_build_card_map()
	_pick_monster()
	_monster_hp = int(_monster_entry.get("health", 1))
	_battle_shield = 0

	var deck_raw: Variant = _game_data.get("player_deck", [])
	var deck: Array = deck_raw.duplicate() if typeof(deck_raw) == TYPE_ARRAY else []
	deck.shuffle()
	_draw_pile = deck
	_discard.clear()
	_hand_entries.clear()
	_player_buffs.clear()
	_enemy_buffs.clear()
	_player_turn = true
	_hide_help_hint_bubble()

	for c in _hand.get_children():
		_hand.remove_child(c)
		c.free()

	await _draw_cards(3)
	_sync_player_portrait()
	_refresh_monster_ui()
	_refresh_player_labels()
	_refresh_buff_ui()
	if _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	set_process(false)


func _on_monster_defeated() -> void:
	end_battle()
	if _game_main != null and _game_main.has_method("show_battle_loot_popup"):
		await _game_main.show_battle_loot_popup()


func end_battle() -> void:
	print("end_battle!")
	if _stat_display_tween != null and _stat_display_tween.is_valid():
		_stat_display_tween.kill()
	_stat_display_tween = null
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = null
	if _player_tip_bubble != null:
		_player_tip_bubble.visible = false
		_player_tip_bubble.modulate = Color(1, 1, 1, 1)
	_hide_help_hint_bubble()
	visible = false
	_battle_shield = 0
	_cancel_drag()
	set_process(false)
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()


func _build_card_map() -> void:
	_card_map.clear()
	for item in WizardInfoConfig.load_cards():
		if item is Dictionary:
			var d: Dictionary = item
			var cid := int(d.get("card_id", 0))
			if cid != 0:
				_card_map[cid] = d.duplicate(true)


func _pick_monster() -> void:
	var year := int(_game_data.get("year", 1))
	var pool: Array = BattleRepoConfig.entries_for_year(year)
	if pool.is_empty():
		_monster_entry = {
			"battle_target_name": "未知之影",
			"health": 100,
			"img": FALLBACK_ENEMY_TEX,
		}
		return
	var pick: Variant = pool[randi_range(0, pool.size() - 1)]
	_monster_entry = pick.duplicate(true) if pick is Dictionary else {}


func _enemy_texture() -> Texture2D:
	var p := str(_monster_entry.get("img", ""))
	if not p.is_empty():
		var t := load(p) as Texture2D
		if t != null:
			return t
	return load(FALLBACK_ENEMY_TEX) as Texture2D


func _sync_player_portrait() -> void:
	var role := str(_game_data.get("role", "Wizard"))
	var path := "res://resource/wizard2.png"
	match role:
		"Wizard":
			path = "res://resource/wizard2.png"
		"Master":
			path = "res://resource/master.png"
		"Sword":
			path = "res://resource/sword.png"
	var tex := load(path) as Texture2D
	_player_tex.texture = tex


func _refresh_monster_ui() -> void:
	_enemy_tex.texture = _enemy_texture()
	_enemy_name.text = str(_monster_entry.get("battle_target_name", "敌人"))
	_enemy_hp.text = "生命: %d" % _monster_hp


func _refresh_player_labels() -> void:
	var mh := int(_game_data.get("max_health", 1))
	var hp := int(_game_data.get("health", 0))
	var mm := int(_game_data.get("max_mana", 1))
	var mp := int(_game_data.get("mana", 0))
	var act := int(_game_data.get("action", 0))
	_player_hp.text = "生命 %d/%d" % [hp, mh]
	_player_shield.text = "护盾 %d" % _battle_shield
	##战斗开始时，法力恢复满
	_player_mana.text = "法力 %d/%d" % [mp, mm]
	_player_act.text = "行动力 %d" % act


func _battle_stat_snapshot_before_pay() -> Dictionary:
	return {
		"monster_hp": _monster_hp,
		"battle_shield": _battle_shield,
		"health": int(_game_data.get("health", 0)),
		"mana": int(_game_data.get("mana", 0)),
		"action": int(_game_data.get("action", 0)),
	}


func _tween_battle_stat_labels_if_changed(snap: Dictionary, duration: float) -> void:
	var mh := int(_game_data.get("max_health", 1))
	var mm := int(_game_data.get("max_mana", 1))
	var e_mon := _monster_hp
	var e_sh := _battle_shield
	var e_hp := int(_game_data.get("health", 0))
	var e_mn := int(_game_data.get("mana", 0))
	var e_ac := int(_game_data.get("action", 0))
	var s_mon := int(snap.get("monster_hp", 0))
	var s_sh := int(snap.get("battle_shield", 0))
	var s_hp := int(snap.get("health", 0))
	var s_mn := int(snap.get("mana", 0))
	var s_ac := int(snap.get("action", 0))

	if s_mon == e_mon and s_sh == e_sh and s_hp == e_hp and s_mn == e_mn and s_ac == e_ac:
		return

	if _stat_display_tween != null and _stat_display_tween.is_valid():
		_stat_display_tween.kill()
	_stat_display_tween = create_tween()
	_stat_display_tween.set_trans(Tween.TRANS_LINEAR)
	var update_stats := func(alpha: float) -> void:
		var a := clampf(alpha, 0.0, 1.0)
		_enemy_hp.text = "生命: %d" % int(round(lerpf(float(s_mon), float(e_mon), a)))
		_player_shield.text = "护盾 %d" % int(round(lerpf(float(s_sh), float(e_sh), a)))
		_player_hp.text = "生命 %d/%d" % [int(round(lerpf(float(s_hp), float(e_hp), a))), mh]
		_player_mana.text = "法力 %d/%d" % [int(round(lerpf(float(s_mn), float(e_mn), a))), mm]
		_player_act.text = "行动力 %d" % int(round(lerpf(float(s_ac), float(e_ac), a)))
	_stat_display_tween.tween_method(update_stats, 0.0, 1.0, duration)
	await _stat_display_tween.finished
	_stat_display_tween = null
	_refresh_player_labels()
	_refresh_monster_ui()


func _draw_cards(n: int) -> void:
	for _i in n:
		if _hand_entries.size() >= HAND_MAX:
			break
		if _draw_pile.is_empty():
			_show_player_tip("没有牌了")
			break
		var cid := int(_draw_pile.pop_back())
		await _animate_draw_card_to_hand(cid)


func _build_hand_card_button(cid: int) -> Button:
	if not _card_map.has(cid):
		return null
	var card_def: Dictionary = _card_map[cid]
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var widget: Control = _game_main.create_card_for_ui(card_def, HAND_CARD_SCALE)
	btn.add_child(widget)
	var wsize: Vector2 = widget.custom_minimum_size
	if wsize == Vector2.ZERO and widget is Control:
		wsize = (widget as Control).size
	btn.custom_minimum_size = wsize + Vector2(8, 8)
	btn.gui_input.connect(_on_hand_card_gui_input.bind(btn, cid))
	return btn


## 抽卡演出：从屏幕右侧滑入 → 中间区域展示 → 插入手牌最右侧。
func _animate_draw_card_to_hand(cid: int) -> void:
	var btn := _build_hand_card_button(cid)
	if btn == null:
		return
	_hand.add_child(btn)
	await get_tree().process_frame
	await get_tree().process_frame
	var target_top_left: Vector2 = btn.global_position
	var card_size: Vector2 = btn.size
	if card_size == Vector2.ZERO:
		card_size = btn.custom_minimum_size
	_hand.remove_child(btn)
	_draw_anim_layer.add_child(btn)
	var vp_w := get_viewport_rect().size.x
	var start := Vector2(vp_w + _DRAW_OFFSCREEN_PAD, target_top_left.y)
	btn.global_position = start
	var show_rect := _play_zone.get_global_rect()
	var show_top_left := show_rect.position + (show_rect.size - card_size) * 0.5
	var tw1 := create_tween()
	tw1.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw1.tween_property(btn, "global_position", show_top_left, _DRAW_ENTER_SEC)
	await tw1.finished
	await get_tree().create_timer(_DRAW_SHOWCASE_HOLD_SEC).timeout
	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(btn, "global_position", target_top_left, _DRAW_TO_HAND_SEC)
	await tw2.finished
	_draw_anim_layer.remove_child(btn)
	_hand.add_child(btn)
	_hand_entries.append({"cid": cid, "button": btn})


func _on_hand_card_gui_input(event: InputEvent, btn: Button, cid: int) -> void:
	if not _player_turn or _play_resolve_in_progress:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _dragging_button == null:
		get_viewport().set_input_as_handled()
		_begin_drag(btn, cid)
	else:
		if _dragging_button == btn:
			get_viewport().set_input_as_handled()
			_resolve_drag_click_at_global_mouse()


func _begin_drag(btn: Button, cid: int) -> void:
	if _play_resolve_in_progress:
		return
	_drag_hand_index = btn.get_index()
	_drag_pickup_offset = btn.global_position - get_global_mouse_position()
	_hand.remove_child(btn)
	_drag_layer.add_child(btn)
	_dragging_button = btn
	_dragging_cid = cid
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _cancel_drag() -> void:
	if _dragging_button == null:
		set_process(false)
		return
	var btn := _dragging_button
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_layer.remove_child(btn)
	var idx: int = clampi(_drag_hand_index, 0, _hand.get_child_count())
	_hand.add_child(btn)
	_hand.move_child(btn, idx)
	_dragging_button = null
	_dragging_cid = 0
	set_process(false)


func _resolve_drag_click_at_global_mouse() -> void:
	if _dragging_button == null or _play_resolve_in_progress:
		return
	var gp := get_global_mouse_position()
	if _play_zone.get_global_rect().has_point(gp):
		_try_play_selected_card()
	else:
		_cancel_drag()


func _try_play_selected_card() -> void:
	if _dragging_button == null:
		return
	if not _card_map.has(_dragging_cid):
		_cancel_drag()
		return
	var card: Dictionary = _card_map[_dragging_cid]
	var mp_need := int(round(float(card.get("mp_cost", 0))))
	var act_need := int(round(float(card.get("action_cost", 0))))
	var mp := int(_game_data.get("mana", 0))
	var act := int(_game_data.get("action", 0))
	if mp < mp_need:
		_show_player_tip("法力不足")
		_cancel_drag()
		return
	if act < act_need:
		_show_player_tip("行动力不足")
		_cancel_drag()
		return

	_play_resolve_in_progress = true

	var played_btn := _dragging_button
	var played_cid := _dragging_cid
	_dragging_button = null
	_dragging_cid = 0
	set_process(false)

	played_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.remove_child(played_btn)
	_play_zone.add_child(played_btn)
	played_btn.z_index = 4
	await get_tree().process_frame
	var psz: Vector2 = played_btn.size
	if psz == Vector2.ZERO:
		psz = played_btn.custom_minimum_size
	var pcm := _play_zone.get_global_rect()
	played_btn.global_position = pcm.get_center() - psz * 0.5

	var snap := _battle_stat_snapshot_before_pay()
	_game_data["mana"] = mp - mp_need
	_game_data["action"] = act - act_need

	await _apply_battle_card_effect(card)
	await _tween_battle_stat_labels_if_changed(snap, _STAT_TWEEN_SEC)

	_remove_hand_entry_for_button(played_btn)
	played_btn.queue_free()

	_discard.append(int(card.get("card_id", 0)))
	_refresh_player_labels()
	_refresh_monster_ui()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()

	if _monster_hp <= 0:
		await _on_monster_defeated()
		_play_resolve_in_progress = false
		return

	if int(_game_data.get("health", 0)) <= 0:
		end_battle()
		if _game_main != null and _game_main.has_method("play_player_death_sequence"):
			await _game_main.play_player_death_sequence()
		_play_resolve_in_progress = false
		return

	_play_resolve_in_progress = false


func _remove_hand_entry_for_button(btn: Button) -> void:
	for i in range(_hand_entries.size() - 1, -1, -1):
		var e: Variant = _hand_entries[i]
		if e is Dictionary and (e as Dictionary).get("button") == btn:
			_hand_entries.remove_at(i)
			return


func _on_end_turn_pressed() -> void:
	if not _player_turn or _play_resolve_in_progress:
		return
	if _dragging_button != null:
		_cancel_drag()
	##回合结束buff触发方法
	_trigger_buffs_at_player_turn_end()
	_player_turn = false

	if _monster_hp > 0:
		_monster_turn()

	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	_refresh_monster_ui()

	if _monster_hp <= 0:
		print("monster fail")
		await _on_monster_defeated()
		return

	if int(_game_data.get("health", 0)) <= 0:
		print("gamer fail")
		end_battle()
		if _game_main != null and _game_main.has_method("play_player_death_sequence"):
			await _game_main.play_player_death_sequence()
		return

	await _begin_player_turn()


## 玩家回合结束时：仅结算挂在玩家身上的 turn_finish buff。
func _trigger_buffs_at_player_turn_end() -> void:
	for b in _player_buffs:
		if b is Dictionary and str((b as Dictionary).get("buff_type", "")) == "turn_finish":
			##处理文案展示
			var buff_show_name="触发："+(b as Dictionary).get("buff_name");
			_show_player_tip(buff_show_name)
			_trigger_buff_effect(b as Dictionary, true)
	_refresh_buff_ui()


## 敌人回合结束时：仅结算挂在敌人身上的 turn_finish buff。
func _trigger_buffs_at_enemy_turn_end() -> void:
	for b in _enemy_buffs:
		if b is Dictionary and str((b as Dictionary).get("buff_type", "")) == "turn_finish":
			
			##实际处理部分
			_trigger_buff_effect(b as Dictionary, false)
	_refresh_buff_ui()


## 根据 buff 的 buff_type 执行效果；owner_is_player 表示该 buff 挂在玩家(true)或敌人(false)身上。
func _trigger_buff_effect(buff: Dictionary, owner_is_player: bool) -> void:
	var bt := str(buff.get("buff_type", ""))
	var snap := _battle_stat_snapshot_before_pay()
	match bt:
		"turn_finish":
			var base := int(round(float(buff.get("damage", 0))))
			if base <= 0:
				return
			## 每层单独结算一次基础伤害，便于未来「每次造成伤害」类连锁；勿合并为 base * buff_count。
			var n := maxi(1, int(buff.get("buff_count", 1)))
			for _i in n:
				if owner_is_player:
					_apply_battle_damage(base, DAMAGE_SOURCE_PLAYER_BUFF, DAMAGE_TARGET_ENEMY)
				else:
					_apply_battle_damage(base, DAMAGE_SOURCE_ENEMY_BUFF, DAMAGE_TARGET_PLAYER)
		_:
			pass
	await _tween_battle_stat_labels_if_changed(snap, _STAT_TWEEN_SEC)


func _refresh_buff_ui() -> void:
	_refresh_buff_row(_player_buff_row, _player_buffs)
	_refresh_buff_row(_enemy_buff_row, _enemy_buffs)


func _refresh_buff_row(row: HBoxContainer, buffs: Array) -> void:
	for c in row.get_children():
		c.queue_free()
	for item in buffs:
		if not item is Dictionary:
			continue
		var bd: Dictionary = item
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 22)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.42, 0.22, 1.0)
		sb.set_corner_radius_all(11)
		dot.add_theme_stylebox_override("panel", sb)
		var name_part := str(bd.get("buff_name", ""))
		var desc_part := str(bd.get("buff_desc", ""))
		var cnt := int(bd.get("buff_count", 1))
		var tip := name_part
		if cnt > 1:
			tip = "%s x%d" % [name_part, cnt] if not name_part.is_empty() else "x%d" % cnt
		if not desc_part.is_empty():
			tip = tip if tip.is_empty() else tip + "\n"
			tip += desc_part
		dot.tooltip_text = tip
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(dot)


func _append_buff_for_card_target(card: Dictionary, buff: Dictionary) -> void:
	var tgt := int(card.get("target", 0))
	if tgt == 1:
		_add_or_stack_buff(_enemy_buffs, buff)
	else:
		_add_or_stack_buff(_player_buffs, buff)
	_refresh_buff_ui()


func _stack_damage_double_buff_on_player() -> void:
	_add_or_stack_buff(_player_buffs, {
		"buff_type": "damage",
		"buff_name": "伤害翻倍",
		"buff_desc": "下一次造成的伤害翻倍（可叠加，每次造成伤害消耗一层）",
		"double_damage": 1,
	})
	_refresh_buff_ui()


func _monster_turn() -> void:
	print("monster_turn!dmg=8")
	if _monster_hp <= 0:
		return
	_apply_battle_damage(8, DAMAGE_SOURCE_ENEMY_ATTACK, DAMAGE_TARGET_PLAYER)
	_trigger_buffs_at_enemy_turn_end()


func _buff_merge_key(buff: Dictionary) -> String:
	return "%s|%s" % [str(buff.get("buff_type", "")), str(buff.get("buff_name", ""))]


## 相同 buff_type + buff_name 视为同一种 buff，重复施加仅叠 buff_count。
func _add_or_stack_buff(buffs: Array, buff: Dictionary) -> void:
	var incoming: Dictionary = buff.duplicate(true)
	var key := _buff_merge_key(incoming)
	var idx := -1
	for i in buffs.size():
		if buffs[i] is Dictionary and _buff_merge_key(buffs[i] as Dictionary) == key:
			idx = i
			break
	if idx < 0:
		var ic := int(round(float(incoming.get("buff_count", 1))))
		incoming["buff_count"] = maxi(1, ic)
		buffs.append(incoming)
	else:
		var b: Dictionary = buffs[idx]
		b["buff_count"] = int(b.get("buff_count", 1)) + 1


## 战斗内所有扣血入口：基础伤害 + 来源 + 目标；敌方受伤害时按需消耗玩家「伤害翻倍」层数。
func _apply_battle_damage(base_damage: int, damage_source: String, damage_target: String) -> void:
	var amt: int = maxi(0, base_damage)
	if amt <= 0:
		return
	var player_is_dealer: bool = (
		damage_source == DAMAGE_SOURCE_CARD
		or damage_source == DAMAGE_SOURCE_PLAYER_BUFF
	)
	if damage_target == DAMAGE_TARGET_ENEMY:
		if player_is_dealer:
			amt = _consume_one_damage_double_stack_and_multiply(amt)
		_monster_hp = maxi(0, _monster_hp - amt)
	elif damage_target == DAMAGE_TARGET_PLAYER:
		_apply_damage_to_player(amt)


func _buff_is_damage_double_stack(buff: Dictionary) -> bool:
	var bt := str(buff.get("buff_type", ""))
	if bt == BUFF_TYPE_DAMAGE_DOUBLE:
		return true
	if bt == "damage" and int(round(float(buff.get("double_damage", 0)))) > 0:
		return true
	return false


func _find_buff_index_damage_double_stack(buffs: Array) -> int:
	for i in buffs.size():
		if buffs[i] is Dictionary and _buff_is_damage_double_stack(buffs[i] as Dictionary):
			return i
	return -1


## 每层「伤害翻倍」使本次伤害乘以 2 一次，并令该 buff 的 buff_count 减一；减至 0 则移除。
func _consume_one_damage_double_stack_and_multiply(amount: int) -> int:
	var out := amount
	var idx := _find_buff_index_damage_double_stack(_player_buffs)
	if idx < 0:
		return out
	var b: Dictionary = _player_buffs[idx]
	var stacks := int(b.get("buff_count", 1))
	if stacks <= 0:
		_player_buffs.remove_at(idx)
		return out
	out *= 2
	stacks -= 1
	if stacks <= 0:
		_player_buffs.remove_at(idx)
	else:
		b["buff_count"] = stacks
	_refresh_buff_ui()
	return out


## 玩家受到伤害：先扣战斗护盾，溢出再扣血量（护盾不入存档）。仅由 _apply_battle_damage 在目标为玩家时调用。
func _apply_damage_to_player(amount: int) -> void:
	var dmg: int = maxi(0, amount)
	if dmg <= 0:
		return
	if _battle_shield > 0:
		var absorbed: int = mini(_battle_shield, dmg)
		_battle_shield -= absorbed
		dmg -= absorbed
	if dmg > 0:
		var hp := int(_game_data.get("health", 0))
		_game_data["health"] = maxi(0, hp - dmg)
	if _game_main != null and _game_main.has_method("_clamp_primary_resources"):
		_game_main._clamp_primary_resources()


func _begin_player_turn() -> void:
	_player_turn = true
	_game_data["action"] = int(_game_data.get("max_action", 0))
	await _draw_cards(2)
	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()


func _apply_battle_card_effect(card: Dictionary) -> void:
	var effect_raw: Variant = card.get("effect", {})
	if not effect_raw is Dictionary:
		return
	var effect: Dictionary = effect_raw
	for k in effect.keys():
		var key := str(k)
		var v: Variant = effect[key]
		match key:
			"damage":
				var amt := int(round(float(v)))
				_apply_battle_damage(amt, DAMAGE_SOURCE_CARD, DAMAGE_TARGET_ENEMY)
			"mp":
				var add := int(round(float(v)))
				var cur := int(_game_data.get("mana", 0))
				var mx := int(_game_data.get("max_mana", 0))
				_game_data["mana"] = clampi(cur + add, 0, mx)
			"shield":
				var add_sh := int(round(float(v)))
				_battle_shield = maxi(0, _battle_shield + add_sh)
			"double_damage":
				_stack_damage_double_buff_on_player()
			"draw", "deaw":
				var n := int(round(float(v)))
				await _draw_cards(n)
			"buff":
				if v is Dictionary:
					_append_buff_for_card_target(card, v as Dictionary)
			_:
				pass
