class_name AimController
extends Node2D
## Sniper controls ported from Camo-Hunter (Unity) and adapted to 2D.
##
## NORMAL VIEW (search): dragging the playfield pans the camera (Camo-Hunter's
## fullscreen SpTouchDeltaHandler + Normal-state look). Releasing never fires.
## AIM MODE: pressing and holding the HUD AIM button (Camo-Hunter's ScopeBtn)
## raises the scope instantly and zooms into the CURRENT searched area; the
## same finger then drags to fine-aim relatively (crosshair fixed at screen
## center, so the finger never covers the target); release fires at the scope
## center — only once zoom-in has completed (Camo-Hunter's CanFire gating).

signal aim_started
signal shot_fired(world_pos: Vector2)

enum ScopeState { IDLE, ENTERING, AIMING, FIRED, EXITING }

## -- Tuning. "CH" = value taken from Camo-Hunter, otherwise adapted for 2D. --

## World px the camera pans per screen px of drag in normal view (adapted:
## CH turns 3.5 deg/px in 3D; 1.0 = the world tracks the finger 1:1 here).
@export var normal_pan_sensitivity := 1.0
## CH: SmoothDamp smoothTime in Normal (look) state.
@export var normal_pan_smooth_time := 0.05
## Screen px of drag before a pan engages (CH has none).
@export var normal_pan_deadzone := 0.0
## Glide time constant after releasing a pan; 0 disables (CH has no inertia).
@export var normal_pan_inertia := 0.0
## CH pans the camera toward the finger direction; enable for map-style drag.
@export var normal_pan_invert := false

## World px of aim travel per screen px of drag while scoped (adapted: CH
## rotates 1 deg/px across a ±25..30 deg window with heavy smoothing).
@export var aim_sensitivity := 0.85
## Scoped magnification (adapted: CH FOV 75->15 is 5.8x, too tight to search
## a 2D crowd; the whole play area is only ~2 screens wide).
@export var scope_zoom := 3.0
## CH: 60 deg FOV change at 250 deg/s linear tween = 0.24 s each way.
@export var scope_enter_duration := 0.24
@export var scope_exit_duration := 0.24
## CH: SmoothDamp smoothTime while scoped.
@export var aim_smooth_time := 0.08
## Recoil kick in world px (adapted: CH kicks its 3D camera up 2 units).
@export var recoil_amount := 34.0
## CH: 0.15 s up + 0.15 s back (yoyo).
@export var recoil_duration := 0.3
## CH: pause after the fire effect before the scope resets.
@export var post_fire_delay := 0.35
## World rect the camera view may show, at any zoom or aspect ratio. Enlarge
## this (plus the backdrop) for bigger searchable levels later.
@export var camera_bounds := Rect2(-140, -80, 1360, 2140)
## Release = fire (CH behavior). Off = release just lowers the scope.
@export var fire_on_release := true

## CH normal FOV. Zoom follows the same linear-FOV curve as CH's tween, so
## perceived magnification accelerates toward the end of the zoom-in.
const NORMAL_FOV_DEG := 75.0
const BASE_CENTER := Vector2(540, 960)

var enabled := false : set = set_enabled
var state := ScopeState.IDLE
var can_fire := false
var camera: Camera2D
var hud: HUD
## Callables (Vector2 -> bool); touches starting on blocking UI never pan.
var ui_blockers: Array[Callable] = []

var _zoom_t := 0.0            # 0 = normal view, 1 = fully scoped (linear time)
var _aim_target := BASE_CENTER
var _pan_target := BASE_CENTER
var _cam_center := BASE_CENTER
var _fire_timer := 0.0
var _scope_touch_index := -1
var _pan_touch_index := -1
var _pan_accum := 0.0
var _glide_velocity := Vector2.ZERO

@onready var overlay: CanvasLayer = $ScopeOverlay


func _ready() -> void:
	overlay.visible = false


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_scope_touch_index = -1
		_pan_touch_index = -1
		_glide_velocity = Vector2.ZERO
		# A fired shot finishes its recoil/exit sequence on its own.
		if state == ScopeState.ENTERING or state == ScopeState.AIMING:
			_exit_scope()


## Recenters instantly (used between levels; the intro card covers the snap).
func reset_view() -> void:
	state = ScopeState.IDLE
	can_fire = false
	_zoom_t = 0.0
	_fire_timer = 0.0
	_scope_touch_index = -1
	_pan_touch_index = -1
	_glide_velocity = Vector2.ZERO
	_pan_target = _clamp_view_center(BASE_CENTER, 1.0)
	_aim_target = _pan_target
	_cam_center = _pan_target
	if camera != null:
		camera.position = _cam_center
		camera.zoom = Vector2.ONE
		camera.offset = Vector2.ZERO
	overlay.visible = false
	if hud != null:
		hud.set_aim_button_active(false)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event)
		else:
			_handle_touch_up(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_press(event: InputEventScreenTouch) -> void:
	# Presses are accepted in IDLE, and also during the post-shot tail
	# (FIRED/EXITING) so the controls never feel dead once search resumes —
	# the scope simply re-raises from wherever the camera currently is.
	if state == ScopeState.ENTERING or state == ScopeState.AIMING:
		return
	if hud != null and hud.is_point_on_aim_button(event.position):
		# AIM button: raise the scope over the current searched area (CH
		# ScopeBtn). Takes over from any active pan.
		if _scope_touch_index == -1:
			_pan_touch_index = -1
			_scope_touch_index = event.index
			_begin_scope_from_view()
	elif _scope_touch_index == -1 and _pan_touch_index == -1 \
			and not _is_on_blocking_ui(event.position):
		# Playfield: start a search pan. Never fires, never scopes.
		_pan_touch_index = event.index
		_pan_accum = 0.0
		_glide_velocity = Vector2.ZERO


func _is_on_blocking_ui(point: Vector2) -> bool:
	for blocker in ui_blockers:
		if blocker.call(point):
			return true
	return false


func _handle_touch_up(event: InputEventScreenTouch) -> void:
	if event.index == _scope_touch_index:
		_scope_touch_index = -1
		if event.canceled:
			_cancel_scope()
		else:
			_handle_release()
	elif event.index == _pan_touch_index:
		_pan_touch_index = -1  # pan release: search only, nothing fires


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _scope_touch_index:
		if state == ScopeState.ENTERING or state == ScopeState.AIMING:
			_apply_drag(event.relative)
	elif event.index == _pan_touch_index:
		_apply_pan_drag(event.relative)


## Scope raise from the AIM button: the aim starts at the camera's current
## center, so the zoom lands on the area the player just searched.
func _begin_scope_from_view() -> void:
	_aim_target = _clamp_aim(_cam_center)
	can_fire = false
	state = ScopeState.ENTERING
	overlay.visible = true
	if hud != null:
		hud.set_aim_button_active(true)
	aim_started.emit()


## Scoped relative drag: finger direction = aim direction (CH mapping).
func _apply_drag(relative: Vector2) -> void:
	_aim_target = _clamp_aim(_aim_target + relative * aim_sensitivity)


## Normal-view search pan (CH: camera pans toward the finger direction).
func _apply_pan_drag(relative: Vector2) -> void:
	_pan_accum += relative.length()
	if _pan_accum < normal_pan_deadzone:
		return
	var step := relative * normal_pan_sensitivity * (-1.0 if normal_pan_invert else 1.0)
	if state == ScopeState.IDLE:
		_pan_target = _clamp_view_center(_pan_target + step, 1.0)
	elif state == ScopeState.EXITING:
		# Panning while the scope lowers keeps the search fluid.
		_aim_target = _clamp_view_center(_aim_target + step, 1.0)
	if normal_pan_inertia > 0.0:
		var dt := maxf(get_process_delta_time(), 0.001)
		_glide_velocity = _glide_velocity.lerp(step / dt, 0.5)


func _handle_release() -> void:
	match state:
		ScopeState.ENTERING:
			# Zoom not finished -> no shot allowed yet (CH CanFire gating).
			_cancel_scope()
		ScopeState.AIMING:
			if fire_on_release and can_fire:
				_fire()
			else:
				_exit_scope()


func _cancel_scope() -> void:
	if state == ScopeState.ENTERING or state == ScopeState.AIMING:
		_exit_scope()


func _fire() -> void:
	can_fire = false
	state = ScopeState.FIRED
	_fire_timer = 0.0
	shot_fired.emit(_cam_center)


func _exit_scope() -> void:
	can_fire = false
	state = ScopeState.EXITING
	if hud != null:
		hud.set_aim_button_active(false)


func _process(delta: float) -> void:
	if camera == null:
		return
	# Real-time step so the scope keeps its timing during slow-motion kills.
	var dt := delta / maxf(Engine.time_scale, 0.05)

	match state:
		ScopeState.ENTERING:
			_zoom_t = minf(_zoom_t + dt / scope_enter_duration, 1.0)
			if _zoom_t >= 1.0:
				state = ScopeState.AIMING
				can_fire = true  # CH: SetCanFire once the FOV tween completes
		ScopeState.FIRED:
			_fire_timer += dt
			if _fire_timer >= recoil_duration + post_fire_delay:
				_exit_scope()
		ScopeState.EXITING:
			_zoom_t = maxf(_zoom_t - dt / scope_exit_duration, 0.0)
			if _zoom_t <= 0.0:
				_settle_idle()
		ScopeState.IDLE:
			if _pan_touch_index == -1 and normal_pan_inertia > 0.0 \
					and _glide_velocity.length_squared() > 25.0:
				_pan_target = _clamp_view_center(_pan_target + _glide_velocity * dt, 1.0)
				_glide_velocity *= exp(-dt / normal_pan_inertia)
		_:
			pass

	var zoom := _zoom_at(_zoom_t)
	var smooth := normal_pan_smooth_time if state == ScopeState.IDLE else aim_smooth_time
	# Exponential smoothing toward the goal (ports CH's SmoothDamp feel).
	_cam_center = _cam_center.lerp(_goal_center(zoom), 1.0 - exp(-dt / maxf(smooth, 0.001)))
	_cam_center = _clamp_view_center(_cam_center, zoom)
	camera.position = _cam_center
	camera.zoom = Vector2(zoom, zoom)
	camera.offset = _recoil_offset()


func _goal_center(zoom: float) -> Vector2:
	if state == ScopeState.IDLE:
		return _clamp_view_center(_pan_target, 1.0)
	# The scope zooms in on, holds, and zooms back out around the aim area —
	# the camera never resets away from where the player searched.
	return _clamp_view_center(_aim_target, zoom)


## CH kicks the camera up and back over recoil_duration (yoyo with a sharp
## Ease.InFlash snap), then holds for the post-fire pause.
func _recoil_offset() -> Vector2:
	if state != ScopeState.FIRED or _fire_timer >= recoil_duration:
		return Vector2.ZERO
	var half := recoil_duration * 0.5
	var k: float
	if _fire_timer < half:
		var t := _fire_timer / half
		k = 1.0 - pow(1.0 - t, 3.0)  # sharp kick out
	else:
		var t := (_fire_timer - half) / half
		k = 1.0 - t * t  # smooth return
	return Vector2(0, -recoil_amount * k)


## Scope fully lowered: return to the searchable view where the player was.
func _settle_idle() -> void:
	state = ScopeState.IDLE
	_zoom_t = 0.0
	_pan_target = _clamp_view_center(_cam_center, 1.0)
	_cam_center = _pan_target
	camera.position = _cam_center
	camera.zoom = Vector2.ONE
	camera.offset = Vector2.ZERO
	overlay.visible = false


## Magnification for linear progress t, following CH's linear FOV tween.
func _zoom_at(t: float) -> float:
	var half_normal := deg_to_rad(NORMAL_FOV_DEG) * 0.5
	var half_scoped := atan(tan(half_normal) / scope_zoom)
	return tan(half_normal) / tan(lerpf(half_normal, half_scoped, t))


## Keeps the camera view rect fully inside camera_bounds at any zoom and
## viewport aspect ratio.
func _clamp_view_center(center: Vector2, zoom: float) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / zoom
	return Vector2(
		_clamp_axis(center.x, camera_bounds.position.x + half.x, camera_bounds.end.x - half.x),
		_clamp_axis(center.y, camera_bounds.position.y + half.y, camera_bounds.end.y - half.y))


## The aim point may go anywhere the fully-zoomed view center can reach.
func _clamp_aim(point: Vector2) -> Vector2:
	return _clamp_view_center(point, scope_zoom)


static func _clamp_axis(value: float, low: float, high: float) -> float:
	if low > high:
		return (low + high) * 0.5
	return clampf(value, low, high)
