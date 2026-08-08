class_name WorldCamera
extends Camera2D
## Horizontal pan camera for wide 2D environments in a portrait viewport.
##
## Fits the full background height to the viewport (zoom = viewport_height /
## world_height, same on both axes — no stretching), locks Y to the world's
## vertical center, and lets the player drag left/right to explore. Map-style
## drag: the world follows the finger, so dragging left reveals the right
## side. The view is clamped so no empty space ever shows past the image.
##
## Future systems (character placement, tap selection, aim/scope zoom) can
## drive this camera through `pan_locked` and the world/limit helpers.

## Path to the background sprite that defines the world size. The sprite
## must be non-centered at (0, 0) and unscaled; its texture size becomes
## the world rect. Resolved once in _ready into `background`.
@export var background_path: NodePath = ^"../BackgroundWorld/PlazaBackground"

var background: Sprite2D
## Screen px of world movement per screen px of drag (1.0 = finger-locked).
@export var drag_sensitivity := 1.0
## Screen px a touch must travel before the pan engages (taps don't move).
@export var drag_threshold := 12.0
## Exponential smoothing time constant for pan follow (small = responsive).
@export var pan_smooth_time := 0.05
## Freezes pan input while other systems (aim, cutscenes) own the camera.
@export var pan_locked := false
## Prints fit/bounds math on every recalculation. Never enable in production.
@export var debug_logging := false

## Fallback world size when no background is assigned (native plaza size).
const FALLBACK_WORLD_SIZE := Vector2(3168.0, 1344.0)

var _world_size := FALLBACK_WORLD_SIZE
var _fit_zoom := 1.0
var _min_camera_x := 0.0
var _max_camera_x := 0.0
var _target_x := 0.0

var _touch_index := -1
var _drag_accum := 0.0
var _last_pan_release_ms := -10000


func _ready() -> void:
	background = get_node_or_null(background_path) as Sprite2D
	if background != null and background.texture != null:
		_world_size = Vector2(background.texture.get_size())
	_fit_to_viewport()
	_target_x = _world_size.x * 0.5
	position = Vector2(_target_x, _world_size.y * 0.5)
	get_viewport().size_changed.connect(_fit_to_viewport)
	# Dev-only scripted acceptance test (no effect unless the env var is set).
	if OS.get_environment("CROWD_SNIPER_PLAZA_TEST") == "1":
		add_child(load("res://scripts/dev/plaza_autotest.gd").new())


## Recomputes zoom and pan limits from the current viewport size. Called on
## startup and whenever the window resizes or rotates.
func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	_fit_zoom = viewport_size.y / _world_size.y
	zoom = Vector2(_fit_zoom, _fit_zoom)

	var visible_world_width := viewport_size.x / _fit_zoom
	if visible_world_width >= _world_size.x:
		# Viewport wider than the world: pin to the center, no panning room.
		_min_camera_x = _world_size.x * 0.5
		_max_camera_x = _world_size.x * 0.5
	else:
		_min_camera_x = visible_world_width * 0.5
		_max_camera_x = _world_size.x - visible_world_width * 0.5

	_target_x = clampf(_target_x, _min_camera_x, _max_camera_x)
	position = Vector2(clampf(position.x, _min_camera_x, _max_camera_x), _world_size.y * 0.5)

	if debug_logging:
		print("[WorldCamera] texture=%s viewport=%s fit_zoom=%.4f visible_w=%.1f min_x=%.1f max_x=%.1f pos=%s" %
			[_world_size, viewport_size, _fit_zoom, visible_world_width, _min_camera_x, _max_camera_x, position])


func _unhandled_input(event: InputEvent) -> void:
	if pan_locked:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_drag_accum = 0.0
		elif event.index == _touch_index:
			if _drag_accum >= drag_threshold:
				_last_pan_release_ms = Time.get_ticks_msec()
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag_accum += absf(event.relative.x)
		if _drag_accum < drag_threshold:
			return
		# Map-style: the world follows the finger, so the camera moves the
		# other way. Screen px -> world px via the current zoom. Vertical
		# drag is ignored entirely.
		_target_x -= event.relative.x * drag_sensitivity / zoom.x
		_target_x = clampf(_target_x, _min_camera_x, _max_camera_x)


## True while the active touch is a pan, or just after one ended. Characters
## use this to suppress taps that were really the tail of a camera drag
## (physics picking delivers the release a frame after _unhandled_input).
func was_recently_panning() -> bool:
	if _touch_index != -1 and _drag_accum >= drag_threshold:
		return true
	return Time.get_ticks_msec() - _last_pan_release_ms < 150


func _process(delta: float) -> void:
	var x := lerpf(position.x, _target_x, 1.0 - exp(-delta / maxf(pan_smooth_time, 0.001)))
	position = Vector2(clampf(x, _min_camera_x, _max_camera_x), _world_size.y * 0.5)
