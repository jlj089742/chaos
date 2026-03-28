extends Control

## 战斗 UI 与回合流程。卡牌真正生效的逻辑入口为 `_apply_battle_card_effect`。

const HAND_CARD_SCALE := 0.22
const FALLBACK_ENEMY_TEX := "res://resource/battle/battle01.png"
const _DRAW_ENTER_SEC := 0.26
const _DRAW_SHOWCASE_HOLD_SEC := 0.18
const _DRAW_TO_HAND_SEC := 0.3
const _DRAW_OFFSCREEN_PAD := 64.0

@onready var _play_zone: Control = $PlayZone
@onready var _hand: HBoxContainer = $HandContainer
@onready var _draw_anim_layer: Control = $DrawAnimLayer
@onready var _drag_layer: Control = $DragLayer
@onready var _end_turn: Button = $EndTurnButton
@onready var _enemy_tex: TextureRect = $MonsterRow/EnemyTexture
@onready var _enemy_name: Label = $MonsterRow/EnemyInfo/EnemyNameLabel
@onready var _enemy_hp: Label = $MonsterRow/EnemyInfo/EnemyHealthLabel
@onready var _player_tex: TextureRect = $PlayerRow/PlayerTexture
@onready var _player_hp: Label = $PlayerRow/PlayerInfo/PlayerHealthLabel
@onready var _player_shield: Label = $PlayerRow/PlayerInfo/PlayerShieldLabel
@onready var _player_mana: Label = $PlayerRow/PlayerInfo/PlayerManaLabel
@onready var _player_act: Label = $PlayerRow/PlayerInfo/PlayerActionLabel

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

var _next_spell_damage_double: bool = false
var _pending_turn_finish_damage: Array = []
var _play_resolve_in_progress: bool = false

func setup(main: Node) -> void:
	_game_main = main


func _ready() -> void:
	_end_turn.pressed.connect(_on_end_turn_pressed)
	set_process(false)


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
	_next_spell_damage_double = false
	_pending_turn_finish_damage.clear()
	_player_turn = true

	for c in _hand.get_children():
		_hand.remove_child(c)
		c.free()

	await _draw_cards(3)
	_sync_player_portrait()
	_refresh_monster_ui()
	_refresh_player_labels()
	if _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	set_process(false)


func end_battle() -> void:
	print("end_battle!")
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
	_player_mana.text = "法力 %d/%d" % [mp, mm]
	_player_act.text = "行动力 %d" % act


func _draw_cards(n: int) -> void:
	for _i in n:
		if _draw_pile.is_empty():
			print("牌库空了，无法抽卡")
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
	if not _player_turn:
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
	if _dragging_button == null:
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
	if mp < mp_need :
		print("try_play_selected_card mp不足")
		_cancel_drag()
		return
	if act < act_need :
		print("try_play_selected_card act不足")
		_cancel_drag()
		return

	_play_resolve_in_progress = true
	_game_data["mana"] = mp - mp_need
	_game_data["action"] = act - act_need

	await _apply_battle_card_effect(card)

	_remove_hand_entry_for_button(_dragging_button)
	_dragging_button.queue_free()
	_dragging_button = null
	_dragging_cid = 0
	set_process(false)

	_discard.append(int(card.get("card_id", 0)))
	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	_refresh_monster_ui()

	if _monster_hp <= 0:
		end_battle()

	_play_resolve_in_progress = false


func _remove_hand_entry_for_button(btn: Button) -> void:
	for i in range(_hand_entries.size() - 1, -1, -1):
		var e: Variant = _hand_entries[i]
		if e is Dictionary and (e as Dictionary).get("button") == btn:
			_hand_entries.remove_at(i)
			return


func _on_end_turn_pressed() -> void:
	if not _player_turn:
		return
	if _dragging_button != null:
		_cancel_drag()
	_resolve_turn_end_damage_preview()
	_player_turn = false

	if _monster_hp > 0:
		_monster_turn()

	_refresh_player_labels()
	if _game_main != null and _game_main.has_method("refresh_top_bar"):
		_game_main.refresh_top_bar()
	_refresh_monster_ui()

	if _monster_hp <= 0:
		print("monster fail")
		end_battle()
		return

	if int(_game_data.get("health", 0)) <= 0:
		print("gamer fail")
		end_battle()
		return

	await _begin_player_turn()


func _resolve_turn_end_damage_preview() -> void:
	for v in _pending_turn_finish_damage:
		_monster_hp = maxi(0, _monster_hp - int(v))
	_pending_turn_finish_damage.clear()


func _monster_turn() -> void:
	print("monster_turn!dmg=8")
	if _monster_hp <= 0:
		return
	_apply_damage_to_player(8)


## 玩家受到伤害：先扣战斗护盾，溢出再扣血量（护盾不入存档）。
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
				if _next_spell_damage_double:
					amt *= 2
					_next_spell_damage_double = false
				_monster_hp = maxi(0, _monster_hp - amt)
			"mp":
				var add := int(round(float(v)))
				var cur := int(_game_data.get("mana", 0))
				var mx := int(_game_data.get("max_mana", 0))
				_game_data["mana"] = clampi(cur + add, 0, mx)
			"shield":
				var add_sh := int(round(float(v)))
				_battle_shield = maxi(0, _battle_shield + add_sh)
			"double_damage":
				_next_spell_damage_double = true
			"draw", "deaw":
				var n := int(round(float(v)))
				await _draw_cards(n)
			"turn_finish_damage":
				_pending_turn_finish_damage.append(int(round(float(v))))
			_:
				pass
