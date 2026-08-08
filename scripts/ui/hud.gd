class_name HUD
extends CanvasLayer
## Prototype HUD: level label, ammo pips, AIM button, and big center feedback
## messages. Controls are built in code — no art assets required.
## The AIM button is purely visual (mouse_filter IGNORE): AimController does
## the hit-test via is_point_on_aim_button so press/drag/release stay in one
## input path, like Camo-Hunter's ScopeBtn over its fullscreen touch area.

## Matches Camo-Hunter's ScopeBtn: 300x300, bottom-center, raised from edge.
const AIM_BUTTON_RECT := Rect2(390, 1490, 300, 300)

var _level_label: Label
var _ammo_box: HBoxContainer
var _message_label: Label
var _message_tween: Tween
var _aim_button: PanelContainer


func _ready() -> void:
	layer = 5

	var top := PanelContainer.new()
	top.position = Vector2(24, 24)
	top.size = Vector2(560, 130)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.72)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_top = 14
	style.content_margin_right = 24
	style.content_margin_bottom = 14
	top.add_theme_stylebox_override("panel", style)
	add_child(top)

	var column := VBoxContainer.new()
	top.add_child(column)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 44)
	_level_label.text = "LEVEL 1"
	column.add_child(_level_label)

	_ammo_box = HBoxContainer.new()
	_ammo_box.add_theme_constant_override("separation", 10)
	column.add_child(_ammo_box)

	_message_label = Label.new()
	_message_label.position = Vector2(0, 700)
	_message_label.size = Vector2(1080, 220)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 110)
	_message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_message_label.add_theme_constant_override("outline_size", 18)
	_message_label.visible = false
	add_child(_message_label)

	_aim_button = PanelContainer.new()
	_aim_button.position = AIM_BUTTON_RECT.position
	_aim_button.size = AIM_BUTTON_RECT.size
	_aim_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aim_style := StyleBoxFlat.new()
	aim_style.bg_color = Color(0.08, 0.11, 0.18, 0.8)
	aim_style.set_corner_radius_all(int(AIM_BUTTON_RECT.size.x * 0.5))
	aim_style.border_color = Color(0.95, 0.8, 0.3, 0.85)
	aim_style.set_border_width_all(5)
	_aim_button.add_theme_stylebox_override("panel", aim_style)
	add_child(_aim_button)

	var aim_label := Label.new()
	aim_label.text = "AIM"
	aim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aim_label.add_theme_font_size_override("font_size", 64)
	aim_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	_aim_button.add_child(aim_label)


## True when the point is over HUD chrome that should block world panning.
func is_point_on_blocking_ui(point: Vector2) -> bool:
	return Rect2(24, 24, 560, 130).has_point(point)  # top stats panel


## Circular hit-test used by AimController's input routing.
func is_point_on_aim_button(point: Vector2) -> bool:
	return point.distance_to(AIM_BUTTON_RECT.get_center()) <= AIM_BUTTON_RECT.size.x * 0.5


func set_aim_button_active(active: bool) -> void:
	_aim_button.modulate = Color(1.5, 1.5, 1.5) if active else Color.WHITE


func set_level(level: int) -> void:
	_level_label.text = "LEVEL %d" % level


func set_ammo(ammo: int, max_ammo: int) -> void:
	for child in _ammo_box.get_children():
		child.queue_free()
	for i in max_ammo:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(20, 44)
		pip.color = Color(0.95, 0.8, 0.3) if i < ammo else Color(1, 1, 1, 0.16)
		_ammo_box.add_child(pip)


func show_message(text: String, color: Color, duration: float = 1.1) -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.visible = true
	_message_label.scale = Vector2(0.6, 0.6)
	_message_label.pivot_offset = _message_label.size * 0.5
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_property(_message_label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.25)
	_message_tween.tween_callback(func () -> void: _message_label.visible = false)
