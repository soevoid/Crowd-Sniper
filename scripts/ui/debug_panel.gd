class_name DebugPanel
extends CanvasLayer
## Development-only overlay: live level/crowd/FPS stats plus restart / next /
## regenerate shortcuts. Toggled by the DBG button in the corner.

signal restart_requested
signal next_level_requested
signal regenerate_requested

var _panel: PanelContainer
var _toggle: Button
var _stats: Label
var _game: Node


func _ready() -> void:
	layer = 10

	_toggle = Button.new()
	_toggle.text = "DBG"
	_toggle.position = Vector2(960, 1830)
	_toggle.size = Vector2(100, 70)
	_toggle.pressed.connect(func () -> void: _panel.visible = not _panel.visible)
	add_child(_toggle)

	_panel = PanelContainer.new()
	_panel.position = Vector2(24, 1310)
	_panel.size = Vector2(500, 500)
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.78)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_top = 12
	style.content_margin_right = 18
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	_panel.add_child(column)

	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 26)
	column.add_child(_stats)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_add_button(buttons, "Restart", func () -> void: restart_requested.emit())
	_add_button(buttons, "Next", func () -> void: next_level_requested.emit())
	_add_button(buttons, "Regen", func () -> void: regenerate_requested.emit())

	set_process(false)


func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 80)
	button.pressed.connect(action)
	parent.add_child(button)


## True when the point is over debug UI that should block world panning.
func is_point_on_ui(point: Vector2) -> bool:
	if Rect2(_toggle.position, _toggle.size).has_point(point):
		return true
	return _panel.visible and Rect2(_panel.position, _panel.size).has_point(point)


func attach(game: Node) -> void:
	_game = game
	set_process(true)


func _process(_delta: float) -> void:
	if not _panel.visible or _game == null:
		return
	var config: LevelConfig = _game.current_config
	var target_dna: CharacterDNA = _game.current_target_dna
	var lines := [
		"FPS: %d" % Engine.get_frames_per_second(),
		"level: %d   ammo: %d/%d" % [config.level, _game.ammo, config.ammo],
		"crowd: %d   decoys: %d" % [config.crowd_count, config.decoy_count],
		"similarity: %.2f   traits: %d" % [config.similarity, config.target_trait_count],
		"move: %.1f   scale: %.2f" % [config.movement_speed, config.character_scale],
		"target:",
	]
	if target_dna != null:
		for key in target_dna.to_dict():
			var value: Variant = target_dna.get_trait(key)
			if value is bool:
				if value: lines.append("  %s" % key)
			elif str(value) != "none":
				lines.append("  %s: %s" % [key, value])
	_stats.text = "\n".join(lines)
