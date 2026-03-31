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
const _MONSTER_CARD_SHOWCASE_HOLD_SEC := 1.5
const _MONSTER_CARDS_PER_TURN := 2

## 统一伤害结算：伤害来源（谁造成本次结算的基础伤害）
const DAMAGE_SOURCE_CARD := "card"
const DAMAGE_SOURCE_MONSTER_CARD := "monster_card"
const DAMAGE_SOURCE_PLAYER_BUFF := "player_buff"
const DAMAGE_SOURCE_ENEMY_ATTACK := "enemy_attack"
const DAMAGE_SOURCE_ENEMY_BUFF := "enemy_buff"

## 统一伤害结算：伤害目标
const DAMAGE_TARGET_PLAYER := "player"
const DAMAGE_TARGET_ENEMY := "enemy"

## 玩家身上「下一次造成伤害翻倍」的可叠加 buff；结算 outgoing 伤害时每层翻倍一次并消耗一层。
## 规范：① `buff_type` 为 legacy `"damage_double"`；② `buff_type` 为 `"damage"` 且 `double_damage` > 0（如通明）；
## ③ `buff_type` 为 `"damage"` 且带 `increase` 字段：持久伤害增幅，按 `increase * buff_count` 加到每次玩家造成的敌方伤害上（如愤怒）。
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
@onready var _enemy_shield: Label = $MonsterRow/EnemyInfo/EnemyShieldLabel
@onready var _turn_phase_label: Label = $TurnPhasePanel/TurnPhaseLabel
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
@onready var _battle_log_btn: Button = $BattleLogButton
@onready var _deck_remain_label: Label = $DeckRemainLabel
@onready var _battle_log_layer: Control = $BattleLogLayer
@onready var _battle_log_dim: ColorRect = $BattleLogLayer/BattleLogDim
@onready var _battle_log_close: Button = $BattleLogLayer/BattleLogPanel/BattleLogVBox/BattleLogTitleRow/BattleLogClose
@onready var _battle_log_scroll: ScrollContainer = $BattleLogLayer/BattleLogPanel/BattleLogVBox/BattleLogScroll
@onready var _battle_log_text: TextEdit = $BattleLogLayer/BattleLogPanel/BattleLogVBox/BattleLogScroll/BattleLogText

var _game_main: Node = null
var _game_data: Dictionary = {}

var _card_map: Dictionary = {}
var _draw_pile: Array = []
var _discard: Array = []
## 手牌实例：每张牌独立一条，支持同 id 多张
var _hand_entries: Array = []

var _monster_entry: Dictionary = {}
var _monster_hp: int = 0
## 怪物战斗内护盾，不入存档；开局 0
var _enemy_battle_shield: int = 0
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
## 为 true 时从 `battle_repo.json` 的 `boss` 列表取怪，否则按年份取普通池。
var _use_boss_battle: bool = false
## 非空时从 `battle_repo.json` 根节点下按该 key 取战斗条目数组（例如 `"event01"`）。
var _battle_repo_key: String = ""
## 与现有 print 文案同步，供战斗日志面板展示
var _battle_log_lines: PackedStringArray = PackedStringArray()

func setup(main: Node) -> void:
	_game_main = main


func _ready() -> void:
	_end_turn.pressed.connect(_on_end_turn_pressed)
	_help_hint_button.pressed.connect(_on_help_hint_button_pressed)
	_battle_log_btn.pressed.connect(_on_battle_log_button_pressed)
	_battle_log_close.pressed.connect(_on_battle_log_close_pressed)
	_battle_log_dim.gui_input.connect(_on_battle_log_dim_gui_input)
	_setup_player_tip_bubble_style()
	_setup_help_hint_ui()
	_setup_turn_phase_panel()
	_setup_battle_log_panel()
	set_process(false)


func _battle_print(line: String) -> void:
	print(line)
	_battle_log_lines.append(line)


func _sync_battle_log_textedit() -> void:
	if _battle_log_text == null:
		return
	_battle_log_text.text = "\n".join(_battle_log_lines)


func _scroll_battle_log_to_bottom_next_frames() -> void:
	# 等布局与 TextEdit 换行高度计算完成，scrollbar 的 max_value 才正确
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_battle_log_text):
		var te_bar := _battle_log_text.get_v_scroll_bar()
		if te_bar != null:
			te_bar.value = te_bar.max_value
	if is_instance_valid(_battle_log_scroll):
		var vbar := _battle_log_scroll.get_v_scroll_bar()
		if vbar != null:
			vbar.value = vbar.max_value


func _refresh_deck_remain_label() -> void:
	if _deck_remain_label != null:
		_deck_remain_label.text = "牌库剩余：%d" % _draw_pile.size()


func _on_battle_log_button_pressed() -> void:
	_hide_help_hint_bubble()
	_battle_log_layer.visible = true
	_sync_battle_log_textedit()
	_scroll_battle_log_to_bottom_next_frames()


func _on_battle_log_close_pressed() -> void:
	_battle_log_layer.visible = false


func _on_battle_log_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_battle_log_layer.visible = false


func _setup_battle_log_panel() -> void:
	var panel := get_node_or_null("BattleLogLayer/BattleLogPanel") as PanelContainer
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.2, 0.98)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	sb.set_border_width_all(1)
	sb.border_color = Color(0.35, 0.38, 0.5, 0.9)
	panel.add_theme_stylebox_override("panel", sb)
	if _battle_log_text != null:
		_battle_log_text.editable = false


func _setup_player_tip_bubble_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.16, 0.22, 0.92)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_player_tip_bubble.add_theme_stylebox_override("panel", sb)


func _setup_turn_phase_panel() -> void:
	var panel := get_node_or_null("TurnPhasePanel") as PanelContainer
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.22, 0.94)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.set_border_width_all(1)
	sb.border_color = Color(0.38, 0.4, 0.52, 0.85)
	panel.add_theme_stylebox_override("panel", sb)


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


func start_battle(use_boss: bool = false, battle_repo_key: String = "") -> void:
	_use_boss_battle = use_boss
	_battle_repo_key = battle_repo_key
	_battle_log_lines.clear()
	_sync_battle_log_textedit()
	_battle_print("对战开始!")
	if _game_main == null:
		return
	if _game_main.has_method("set_world_map_help_visible"):
		_game_main.set_world_map_help_visible(false)
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
	_enemy_battle_shield = 0
	_battle_shield = 0

	var deck_raw: Variant = _game_data.get("player_deck", [])
	var deck: Array = deck_raw.duplicate() if typeof(deck_raw) == TYPE_ARRAY else []
	deck.shuffle()
	_draw_pile = deck
	_discard.clear()
	_refresh_deck_remain_label()
	_hand_entries.clear()
	_player_buffs.clear()
	_enemy_buffs.clear()
	_player_turn = true
	_hide_help_hint_bubble()

	for c in _hand.get_children():
		_hand.remove_child(c)
		c.free()

	# 先刷新头像与属性，再开始抽卡演出，避免进入战斗后长时间只看到空白信息区
	_sync_player_portrait()
	_refresh_monster_ui()
	_refresh_player_labels()
	_refresh_buff_ui()
	_update_turn_indicator()
	if _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	await get_tree().process_frame
	await get_tree().process_frame

	await _draw_cards(3)
	set_process(false)
	_refresh_deck_remain_label()
	_battle_print("对战初始化完毕")

func _on_monster_defeated() -> void:
	end_battle()
	if _game_main != null and _game_main.has_method("show_battle_loot_popup"):
		await _game_main.show_battle_loot_popup(_monster_entry.duplicate(true))


func end_battle() -> void:
	_battle_print("对战结束")
	if _battle_log_layer != null:
		_battle_log_layer.visible = false
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
	_enemy_battle_shield = 0
	_cancel_drag()
	set_process(false)
	_use_boss_battle = false
	_battle_repo_key = ""
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	if _game_main != null and _game_main.has_method("set_world_map_help_visible"):
		_game_main.set_world_map_help_visible(true)


func _build_card_map() -> void:
	_card_map.clear()
	for item in WizardInfoConfig.load_cards():
		if item is Dictionary:
			var d: Dictionary = item
			var cid := int(d.get("card_id", 0))
			if cid != 0:
				_card_map[cid] = d.duplicate(true)
	## 怪物出牌、`card_id_list` 引用的是 monster_info.json 中的卡。
	for item in MonsterInfoConfig.load_cards():
		if item is Dictionary:
			var d2: Dictionary = item
			var cid2 := int(d2.get("card_id", 0))
			if cid2 != 0:
				_card_map[cid2] = d2.duplicate(true)


func _pick_monster() -> void:
	var pool: Array = []
	if not _battle_repo_key.is_empty():
		pool = BattleRepoConfig.entries_for_key(_battle_repo_key)
	elif _use_boss_battle:
		pool = BattleRepoConfig.boss_entries()
	else:
		var year := int(_game_data.get("year", 1))
		pool = BattleRepoConfig.entries_for_year(year)
	if pool.is_empty():
		_monster_entry = {
			"battle_target_name": "未知之影",
			"health": 100,
			"img": FALLBACK_ENEMY_TEX,
			"card_id_list": [],
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
	if _enemy_shield != null:
		_enemy_shield.text = "护盾 %d" % _enemy_battle_shield


func _update_turn_indicator() -> void:
	if _turn_phase_label == null:
		return
	_turn_phase_label.text = "玩家回合" if _player_turn else "怪物回合"
	if _end_turn != null:
		_end_turn.disabled = not _player_turn


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
		"enemy_shield": _enemy_battle_shield,
		"battle_shield": _battle_shield,
		"health": int(_game_data.get("health", 0)),
		"mana": int(_game_data.get("mana", 0)),
		"action": int(_game_data.get("action", 0)),
	}


func _tween_battle_stat_labels_if_changed(snap: Dictionary, duration: float) -> void:
	var mh := int(_game_data.get("max_health", 1))
	var mm := int(_game_data.get("max_mana", 1))
	var e_mon := _monster_hp
	var e_esh := _enemy_battle_shield
	var e_sh := _battle_shield
	var e_hp := int(_game_data.get("health", 0))
	var e_mn := int(_game_data.get("mana", 0))
	var e_ac := int(_game_data.get("action", 0))
	var s_mon := int(snap.get("monster_hp", 0))
	var s_esh := int(snap.get("enemy_shield", 0))
	var s_sh := int(snap.get("battle_shield", 0))
	var s_hp := int(snap.get("health", 0))
	var s_mn := int(snap.get("mana", 0))
	var s_ac := int(snap.get("action", 0))

	if s_mon == e_mon and s_esh == e_esh and s_sh == e_sh and s_hp == e_hp and s_mn == e_mn and s_ac == e_ac:
		return

	if _stat_display_tween != null and _stat_display_tween.is_valid():
		_stat_display_tween.kill()
	_stat_display_tween = create_tween()
	_stat_display_tween.set_trans(Tween.TRANS_LINEAR)
	var update_stats := func(alpha: float) -> void:
		var a := clampf(alpha, 0.0, 1.0)
		_enemy_hp.text = "生命: %d" % int(round(lerpf(float(s_mon), float(e_mon), a)))
		if _enemy_shield != null:
			_enemy_shield.text = "护盾 %d" % int(round(lerpf(float(s_esh), float(e_esh), a)))
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
		_refresh_deck_remain_label()
		
	_refresh_deck_remain_label()


func _build_hand_card_button(cid: int) -> Button:
	return _build_card_button_internal(cid, true)


func _build_card_button_internal(cid: int, connect_hand_drag: bool) -> Button:
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
	if connect_hand_drag:
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
	await _trigger_buffs_at_player_turn_end()
	if _monster_hp > 0:
		_player_turn = false
		_update_turn_indicator()
		await _monster_turn()

	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	_refresh_monster_ui()

	if _monster_hp <= 0:
		_battle_print("monster fail")
		await _on_monster_defeated()
		return

	if int(_game_data.get("health", 0)) <= 0:
		_battle_print("gamer fail")
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
			await _trigger_buff_effect(b as Dictionary, true)
	_refresh_buff_ui()


## 玩家回合开始时：结算一次性 next_turn_start buff，触发后移除（每层仅生效一次）。
func _trigger_buffs_at_player_turn_start() -> void:
	for i in range(_player_buffs.size() - 1, -1, -1):
		if not (_player_buffs[i] is Dictionary):
			continue
		var b: Dictionary = _player_buffs[i] as Dictionary
		if str(b.get("buff_type", "")) != "next_turn_start":
			continue
		var buff_show_name := "触发：" + str(b.get("buff_name", ""))
		_show_player_tip(buff_show_name)
		await _trigger_buff_effect(b, true)
		_player_buffs.remove_at(i)
	_refresh_buff_ui()


## 敌人回合结束时：仅结算挂在敌人身上的 turn_finish buff。
func _trigger_buffs_at_enemy_turn_end() -> void:
	for b in _enemy_buffs:
		if b is Dictionary and str((b as Dictionary).get("buff_type", "")) == "turn_finish":
			await _trigger_buff_effect(b as Dictionary, false)
	_refresh_buff_ui()


## 敌人回合开始时：结算一次性 next_turn_start buff，触发后移除（每层仅生效一次）。
func _trigger_buffs_at_enemy_turn_start() -> void:
	for i in range(_enemy_buffs.size() - 1, -1, -1):
		if not (_enemy_buffs[i] is Dictionary):
			continue
		var b: Dictionary = _enemy_buffs[i] as Dictionary
		if str(b.get("buff_type", "")) != "next_turn_start":
			continue
		await _trigger_buff_effect(b, false)
		_enemy_buffs.remove_at(i)
	_refresh_buff_ui()


## 根据 buff 的 buff_type 执行效果；owner_is_player 表示该 buff 挂在玩家(true)或敌人(false)身上。
func _trigger_buff_effect(buff: Dictionary, owner_is_player: bool) -> void:
	var bt := str(buff.get("buff_type", ""))
	var snap := _battle_stat_snapshot_before_pay()
	match bt:
		"turn_finish", "next_turn_start":
			var base_dmg := int(round(float(buff.get("damage", 0))))
			var mp_each := int(round(float(buff.get("mp", 0))))
			## 每层单独结算一次基础伤害，便于未来「每次造成伤害」类连锁；勿合并为 base * buff_count。
			var n := maxi(1, int(buff.get("buff_count", 1)))
			var did := false
			if base_dmg > 0:
				did = true
				for _i in n:
					if owner_is_player:
						_battle_print("触发buff效果：" + str(buff.get("buff_name")))
						_apply_battle_damage(base_dmg, DAMAGE_SOURCE_PLAYER_BUFF, DAMAGE_TARGET_ENEMY)
					else:
						_battle_print("触发buff效果：" + str(buff.get("buff_name")))
						_apply_battle_damage(base_dmg, DAMAGE_SOURCE_ENEMY_BUFF, DAMAGE_TARGET_PLAYER)
			## 归元：玩家回合结束时按层数恢复法力（每层 mp 点，合计后一次封顶 max_mana）。
			if mp_each > 0 and owner_is_player:
				did = true
				var add_total := mp_each * n
				var cur_mp := int(_game_data.get("mana", 0))
				var mx_mp := int(_game_data.get("max_mana", 0))
				_game_data["mana"] = clampi(cur_mp + add_total, 0, mx_mp)
				_battle_print("触发buff效果：" + str(buff.get("buff_name")) + "，法力恢复%d点" % add_total)
				if _game_main != null and _game_main.has_method("_clamp_primary_resources"):
					_game_main._clamp_primary_resources()
			if not did:
				return
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
	# next_turn_start 为“施法者自身挂 buff”，不受 card.target 影响。
	if str(buff.get("buff_type", "")) == "next_turn_start":
		_battle_print("施加buff给自己："+str(buff.get("buff_name", "")))
		_add_or_stack_buff(_player_buffs, buff)
		_refresh_buff_ui()
		return
	var tgt := int(card.get("target", 0))
	if tgt == 1:
		_battle_print("施加buff给敌人："+buff.get("buff_name"))
		_add_or_stack_buff(_enemy_buffs, buff)
	else:
		_battle_print("施加buff给自己："+buff.get("buff_name"))
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


func _stack_damage_double_buff_on_enemy() -> void:
	_add_or_stack_buff(_enemy_buffs, {
		"buff_type": "damage",
		"buff_name": "伤害翻倍",
		"buff_desc": "下一次造成的伤害翻倍（可叠加，每次造成伤害消耗一层）",
		"double_damage": 1,
	})
	_refresh_buff_ui()


func _consume_one_damage_double_stack_from_enemy_and_multiply(amount: int) -> int:
	var out := amount
	var idx := _find_buff_index_damage_double_stack(_enemy_buffs)
	if idx < 0:
		return out
	var b: Dictionary = _enemy_buffs[idx]
	var stacks := int(b.get("buff_count", 1))
	if stacks <= 0:
		_enemy_buffs.remove_at(idx)
		return out
	out *= 2
	stacks -= 1
	if stacks <= 0:
		_enemy_buffs.remove_at(idx)
	else:
		b["buff_count"] = stacks
	_refresh_buff_ui()
	return out


func _pick_random_monster_card_id() -> int:
	var raw: Variant = _monster_entry.get("card_id_list", [])
	if typeof(raw) != TYPE_ARRAY or raw.is_empty():
		return 0
	var pick: Variant = raw[randi_range(0, raw.size() - 1)]
	var s := str(pick).strip_edges()
	if s.is_empty():
		return 0
	return int(s)


func _showcase_and_resolve_monster_card(cid: int) -> void:
	if not _card_map.has(cid):
		return
	var card: Dictionary = _card_map[cid]
	_battle_print("怪物打出卡牌："+card.get("card_name"))
	var btn := _build_card_button_internal(cid, false)
	if btn == null:
		return
	_play_zone.add_child(btn)
	btn.z_index = 6
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	await get_tree().process_frame
	var psz: Vector2 = btn.size
	if psz == Vector2.ZERO:
		psz = btn.custom_minimum_size
	var pcm := _play_zone.get_global_rect()
	btn.global_position = pcm.get_center() - psz * 0.5
	var snap := _battle_stat_snapshot_before_pay()
	await get_tree().create_timer(_MONSTER_CARD_SHOWCASE_HOLD_SEC).timeout
	await _apply_monster_battle_card_effect(card)
	await _tween_battle_stat_labels_if_changed(snap, _STAT_TWEEN_SEC)
	if is_instance_valid(btn):
		btn.queue_free()


func _append_buff_for_monster_card(card: Dictionary, buff: Dictionary) -> void:
	# next_turn_start 为“施法者自身挂 buff”，不受 card.target 影响。
	if str(buff.get("buff_type", "")) == "next_turn_start":
		_battle_print("怪物增加buff："+str(buff.get("buff_name", "")))
		_add_or_stack_buff(_enemy_buffs, buff)
		_refresh_buff_ui()
		return
	var tgt := int(card.get("target", 0))
	if tgt == 1:
		_battle_print("玩家增加buff："+buff.get("buff_name"))
		_add_or_stack_buff(_player_buffs, buff)
	else:
		_battle_print("怪物增加buff："+buff.get("buff_name"))
		_add_or_stack_buff(_enemy_buffs, buff)
	_refresh_buff_ui()


func _apply_monster_battle_card_effect(card: Dictionary) -> void:
	var effect_raw: Variant = card.get("effect", {})
	if not effect_raw is Dictionary:
		return
	var effect: Dictionary = effect_raw
	# 百鬼夜行：按 damage + damage_count 多次结算
	var handled_multi_damage := false
	if effect.has("damage") and effect.has("damage_count"):
		var dmg := int(round(float(effect.get("damage", 0))))
		var n := int(round(float(effect.get("damage_count", 1))))
		n = maxi(1, n)
		for _i in n:
			_apply_battle_damage(dmg, DAMAGE_SOURCE_MONSTER_CARD, DAMAGE_TARGET_PLAYER)
		handled_multi_damage = true

	for k in effect.keys():
		var key := str(k)
		var v: Variant = effect[key]
		match key:
			"damage":
				if handled_multi_damage:
					continue
				var amt := int(round(float(v)))
				_apply_battle_damage(amt, DAMAGE_SOURCE_MONSTER_CARD, DAMAGE_TARGET_PLAYER)
			"damage_count":
				# 已在百鬼夜行特殊分支中处理
				pass
			"mp":
				pass
			"mana":
				# 夺魂刺：造成伤害同时减少目标法力
				var delta := int(round(float(v)))
				var cur := int(_game_data.get("mana", 0))
				var mx := int(_game_data.get("max_mana", 0))
				_game_data["mana"] = clampi(cur + delta, 0, mx)
				if delta < 0:
					_battle_print("减少法力：" + str(-delta))
				elif delta > 0:
					_battle_print("增加法力：" + str(delta))
			"shield":
				var add_sh := int(round(float(v)))
				_enemy_battle_shield = maxi(0, _enemy_battle_shield + add_sh)
				_battle_print("怪物获得护盾："+str(add_sh))
			"double_damage":
				_stack_damage_double_buff_on_enemy()
			"max_health":
				# 鬼王令：减少目标血量上限，且当前生命不能超过上限
				var delta_hp_max := int(round(float(v)))
				var cur_max := int(_game_data.get("max_health", 0))
				var new_max := maxi(0, cur_max + delta_hp_max)
				_game_data["max_health"] = new_max
				_game_data["health"] = mini(int(_game_data.get("health", 0)), new_max)
				if delta_hp_max < 0:
					_battle_print("鬼王令减少生命上限：" + str(-delta_hp_max))
				elif delta_hp_max > 0:
					_battle_print("鬼王令增加生命上限：" + str(delta_hp_max))
				if _game_main != null and _game_main.has_method("_clamp_primary_resources"):
					_game_main._clamp_primary_resources()
			"draw", "deaw":
				pass
			"buff":
				if v is Dictionary:
					# 支持 effect 层级 buff_count：表示对同一 buff 施加 N 次
					var bd := (v as Dictionary).duplicate(true)
					var outer_cnt := int(round(float(effect.get("buff_count", 1))))
					if outer_cnt <= 0:
						outer_cnt = 1
					var inner_cnt := int(round(float(bd.get("buff_count", 1))))
					bd["buff_count"] = maxi(1, inner_cnt) * maxi(1, outer_cnt)
					_append_buff_for_monster_card(card, bd)
			_:
				pass


func _monster_turn() -> void:
	_battle_print("开始怪物回合")
	if _monster_hp <= 0:
		return
	await _trigger_buffs_at_enemy_turn_start()
	if _monster_hp <= 0 or int(_game_data.get("health", 0)) <= 0:
		return
	_play_resolve_in_progress = true
	for _i in _MONSTER_CARDS_PER_TURN:
		if _monster_hp <= 0 or int(_game_data.get("health", 0)) <= 0:
			break
		var cid := _pick_random_monster_card_id()
		if cid > 0 and _card_map.has(cid):
			await _showcase_and_resolve_monster_card(cid)
		else:
			var snap := _battle_stat_snapshot_before_pay()
			_apply_battle_damage(8, DAMAGE_SOURCE_ENEMY_ATTACK, DAMAGE_TARGET_PLAYER)
			await _tween_battle_stat_labels_if_changed(snap, _STAT_TWEEN_SEC)
	_refresh_monster_ui()
	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	await _trigger_buffs_at_enemy_turn_end()
	_play_resolve_in_progress = false


func _buff_merge_key(buff: Dictionary) -> String:
	return "%s|%s" % [str(buff.get("buff_type", "")), str(buff.get("buff_name", ""))]


## 相同 buff_type + buff_name 视为同一种 buff，重复施加仅叠 buff_count。
func _add_or_stack_buff(buffs: Array, buff: Dictionary) -> void:
	var incoming: Dictionary = buff.duplicate(true)
	# 支持「初始就施加 N 层」：鬼域配置用 ineffective 表示初始层数。
	# 没给 buff_count 的情况下，如果存在 ineffective，则把它当作初始 buff_count。
	if not incoming.has("buff_count"):
		if incoming.has("ineffective"):
			var n := int(round(float(incoming.get("ineffective", 1))))
			incoming["buff_count"] = maxi(1, n)
		else:
			incoming["buff_count"] = 1
	var key := _buff_merge_key(incoming)
	var idx := -1
	for i in buffs.size():
		if buffs[i] is Dictionary and _buff_merge_key(buffs[i] as Dictionary) == key:
			idx = i
			break
	if idx < 0:
		buffs.append(incoming)
	else:
		var b: Dictionary = buffs[idx]
		# 新施加的 buff 可能携带初始层数（例如鬼域 ineffective）。
		b["buff_count"] = int(b.get("buff_count", 1)) + int(incoming.get("buff_count", 1))


func _try_consume_one_inffective_buff_on_enemy_if_damage(amt: int) -> int:
	# 鬼域：当怪物收到一次伤害（amt > 0）时，免疫一次伤害并消耗 1 层。
	if amt <= 0:
		return amt
	for i in _enemy_buffs.size():
		if not (_enemy_buffs[i] is Dictionary):
			continue
		var b: Dictionary = _enemy_buffs[i] as Dictionary
		# 免疫一次伤害的 buff：配置在 buff 上的 ineffective >= 1
		# 之前实现只识别 buff_name == "鬼域"，导致其它同类（如“因果”）无法免疫。
		if str(b.get("buff_type", "")) != "damage":
			continue
		var inef := int(round(float(b.get("ineffective", 0))))
		if inef <= 0:
			continue
		var stacks := int(b.get("buff_count", 1))
		if stacks <= 0:
			_enemy_buffs.remove_at(i)
			_refresh_buff_ui()
			return 0
		stacks -= 1
		if stacks <= 0:
			_enemy_buffs.remove_at(i)
		else:
			b["buff_count"] = stacks
		_refresh_buff_ui()
		return 0
	return amt


func _try_consume_one_inffective_buff_on_player_if_damage(amt: int) -> int:
	# 因果/鬼域同类：当玩家收到一次伤害（amt > 0）时，免疫一次伤害并消耗 1 层。
	if amt <= 0:
		return amt
	for i in _player_buffs.size():
		if not (_player_buffs[i] is Dictionary):
			continue
		var b: Dictionary = _player_buffs[i] as Dictionary
		if str(b.get("buff_type", "")) != "damage":
			continue
		var inef := int(round(float(b.get("ineffective", 0))))
		if inef <= 0:
			continue
		var stacks := int(b.get("buff_count", 1))
		if stacks <= 0:
			_player_buffs.remove_at(i)
			_refresh_buff_ui()
			return 0
		stacks -= 1
		if stacks <= 0:
			_player_buffs.remove_at(i)
		else:
			b["buff_count"] = stacks
		_refresh_buff_ui()
		return 0
	return amt


## 战斗内所有扣血入口：基础伤害 + 来源 + 目标；敌方受伤害时按需消耗玩家「伤害翻倍」层数，并叠加持久伤害增幅。
func _apply_battle_damage(base_damage: int, damage_source: String, damage_target: String) -> void:
	var amt: int = maxi(0, base_damage)
	var player_is_dealer: bool = (
		damage_source == DAMAGE_SOURCE_CARD
		or damage_source == DAMAGE_SOURCE_PLAYER_BUFF
	)
	if damage_target == DAMAGE_TARGET_ENEMY:
		var amp := 0
		if player_is_dealer:
			amp = _player_persistent_damage_amp_total()
		if amt <= 0 and amp <= 0:
			return
		if player_is_dealer:
			# 持久增幅应作用于“最终伤害数值”，因此先加增幅，再结算翻倍buff。
			amt += amp
			if amt > 0:
				amt = _consume_one_damage_double_stack_and_multiply(amt)
		elif amt <= 0:
			return
		# 怪物受伤：如果有「鬼域」buff，免疫一次伤害并消耗一层。
		amt = _try_consume_one_inffective_buff_on_enemy_if_damage(amt)
		_battle_print("造成"+str(amt)+"伤害")
		if _enemy_battle_shield > 0:
			var absorbed_en: int = mini(_enemy_battle_shield, amt)
			_enemy_battle_shield -= absorbed_en
			amt -= absorbed_en
		_monster_hp = maxi(0, _monster_hp - amt)
	elif damage_target == DAMAGE_TARGET_PLAYER:
		var enemy_is_dealer := (
			damage_source == DAMAGE_SOURCE_MONSTER_CARD
			or damage_source == DAMAGE_SOURCE_ENEMY_ATTACK
			or damage_source == DAMAGE_SOURCE_ENEMY_BUFF
		)
		if enemy_is_dealer:
			var amp := _enemy_persistent_damage_amp_total()
			if amt <= 0 and amp <= 0:
				return
			# 持久增幅应作用于最终伤害数值，因此先加增幅，再结算翻倍buff。
			amt += amp
			if amt > 0:
				amt = _consume_one_damage_double_stack_from_enemy_and_multiply(amt)
		elif amt <= 0:
			return
		# 玩家受伤：如果有「ineffective」类 buff，免疫一次伤害并消耗一层。
		amt = _try_consume_one_inffective_buff_on_player_if_damage(amt)
		_battle_print("造成"+str(amt)+"伤害")
		_apply_damage_to_player(amt)


func _buff_has_persistent_damage_increase(buff: Dictionary) -> bool:
	if str(buff.get("buff_type", "")) != "damage":
		return false
	if not buff.has("increase"):
		return false
	return int(round(float(buff.get("increase", 0)))) != 0


## 玩家身上所有「伤害增幅」类 buff 的合计：`sum(increase * buff_count)`，战斗内持续生效、不消耗层数。
func _player_persistent_damage_amp_total() -> int:
	var total := 0
	for item in _player_buffs:
		if not item is Dictionary:
			continue
		var b: Dictionary = item
		if not _buff_has_persistent_damage_increase(b):
			continue
		var per := int(round(float(b.get("increase", 0))))
		var stacks := maxi(1, int(b.get("buff_count", 1)))
		total += per * stacks
	return total


## 怪物身上所有「伤害增幅」类 buff 的合计：`sum(increase * buff_count)`。
func _enemy_persistent_damage_amp_total() -> int:
	var total := 0
	for item in _enemy_buffs:
		if not item is Dictionary:
			continue
		var b: Dictionary = item
		if not _buff_has_persistent_damage_increase(b):
			continue
		var per := int(round(float(b.get("increase", 0))))
		var stacks := maxi(1, int(b.get("buff_count", 1)))
		total += per * stacks
	return total


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
	_update_turn_indicator()
	await _trigger_buffs_at_player_turn_start()
	if _monster_hp <= 0:
		await _on_monster_defeated()
		return
	if int(_game_data.get("health", 0)) <= 0:
		end_battle()
		if _game_main != null and _game_main.has_method("play_player_death_sequence"):
			await _game_main.play_player_death_sequence()
		return
	_game_data["action"] = int(_game_data.get("max_action", 0))
	await _draw_cards(2)
	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()


func _apply_battle_card_effect(card: Dictionary) -> void:
	_battle_print("玩家打出卡牌:"+card.get("card_name"))
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
				_battle_print("法力恢复"+str(add)+"点")
			"shield":
				var add_sh := int(round(float(v)))
				_battle_shield = maxi(0, _battle_shield + add_sh)
				_battle_print("护盾增加"+str(add_sh)+"点")
			"double_damage":
				_stack_damage_double_buff_on_player()
			"draw", "deaw":
				var n := int(round(float(v)))
				await _draw_cards(n)
			"buff":
				if v is Dictionary:
					# 支持两种配置写法：
					# 1) effect.buff 内直接带 buff_count
					# 2) effect 层级单独提供 buff_count：表示对该 buff 施加 N 次
					var bd := (v as Dictionary).duplicate(true)
					var outer_cnt := int(round(float(effect.get("buff_count", 1))))
					if outer_cnt <= 0:
						outer_cnt = 1
					var inner_cnt := int(round(float(bd.get("buff_count", 1))))
					bd["buff_count"] = maxi(1, inner_cnt) * maxi(1, outer_cnt)
					_append_buff_for_card_target(card, bd)
			_:
				pass
