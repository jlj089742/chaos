extends Area2D
class_name InteractionSpot

signal clicked(spot_type: String)

var _spot_type: String = ""
var spot_type: String:
	get:
		return _spot_type
	set(value):
		_spot_type = value
		if is_inside_tree():
			queue_redraw()

func _ready() -> void:
	input_pickable = true
	queue_redraw()

func _type_to_letter(t: String) -> String:
	match t:
		"start":
			return "H"
		"battle":
			return "B"
		"box":
			return "X"
		"event":
			return "?"
		"rest":
			return "R"
		"boss":
			return "S"
		_:
			return "?"

func _type_to_fill_color(t: String) -> Color:
	match t:
		"start":
			return Color(0.22, 0.72, 0.38, 0.92)
		"battle":
			return Color(0.88, 0.28, 0.22, 0.92)
		"box":
			return Color(0.82, 0.62, 0.2, 0.92)
		"event":
			return Color(0.52, 0.36, 0.86, 0.92)
		"rest":
			return Color(0.32, 0.68, 0.88, 0.92)
		"boss":
			return Color(0.48, 0.14, 0.42, 0.92)
		_:
			return Color(0.5, 0.5, 0.5, 0.92)

func _draw() -> void:
	var fill := _type_to_fill_color(_spot_type)
	var letter := _type_to_letter(_spot_type)
	draw_circle(Vector2.ZERO, 22.0, fill)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
	var font := ThemeDB.fallback_font
	var font_size := 20
	var sz := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(-sz.x * 0.5, font.get_ascent(font_size) * 0.35)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(_spot_type)
			viewport.set_input_as_handled()
