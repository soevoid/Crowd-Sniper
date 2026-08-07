class_name AimController
extends Node2D
## Sniper scope controls ported from Camo-Hunter (Unity) and adapted to 2D.
## Touch-and-hold raises the scope: the overlay appears instantly and the
## camera zooms toward the touched spot. Dragging moves the aim RELATIVELY
## (crosshair fixed at screen center, so the finger never covers the target).
## Release fires at the scope center — but only once zoom-in has completed,
## exactly like Camo-Hunter's CanFire gating.

signal aim_started
signal shot_fired(world_pos: Vector2)

enum ScopeState { IDLE, ENTERING, AIMING, FIRED, EXITING }

## -- Tuning. "CH" = value taken from Camo-Hunter, otherwise adapted for 2D. --

## World px of aim travel per screen px of drag (adapted: CH rotates 1 deg/px
## across a ±25..30 deg window with heavy smoothing; scaled to our play area).
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
## World rect the camera view may show. Wider than the 1080x1920 design so
## the scope center can reach characters at the play-area edges.
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

var _zoom_t := 0.0            # 0 = normal view, 1 = fully scoped (linear time)
var _aim_target := BASE_CENTER
var _cam_center := BASE_CENTER
var _fire_timer := 0.0
var _touch_index := -1

@onready var overlay: CanvasLayer = $ScopeOverlay


func _ready() -> void:
	overlay.visible = false
	set_process(false)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_touch_index = -1
		# A fired shot finishes its recoil/exit sequence on its own.
		if state == ScopeState.ENTERING or state == ScopeState.AIMING:
			_exit_scope()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Single-touch only (CH disables multi-touch).
			if _touch_index == -1 and (state == ScopeState.IDLE or state == ScopeState.EXITING):
				_touch_index = event.index
				_begin_scope(event.position)
		elif event.index == _touch_index:
			_touch_index = -1
			if event.canceled:
				_cancel_scope()
			else:
				_handle_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if state == ScopeState.ENTERING or state == ScopeState.AIMING:
			_apply_drag(event.relative)


## Touch down: scope UI appears instantly (CH behavior), zoom-in starts toward
## the touched world position so the suspect stays under the aim.
func _begin_scope(screen_pos: Vector2) -> void:
	_aim_target = _clamp_aim(_screen_to_world(screen_pos))
	can_fire = false
	state = ScopeState.ENTERING
	overlay.visible = true
	set_process(true)
	aim_started.emit()


## Relative drag: finger direction = aim direction (CH mapping).
func _apply_drag(relative: Vector2) -> void:
	_aim_target = _clamp_aim(_aim_target + relative * aim_sensitivity)


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


func _process(delta: float) -> void:
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
				return
		_:
			pass

	var zoom := _zoom_at(_zoom_t)
	# Exponential smoothing toward the goal (ports CH's SmoothDamp feel).
	_cam_center = _cam_center.lerp(_goal_center(zoom), 1.0 - exp(-dt / aim_smooth_time))
	_cam_center = _clamp_view_center(_cam_center, zoom)
	camera.position = _cam_center
	camera.zoom = Vector2(zoom, zoom)
	camera.offset = _recoil_offset()


func _goal_center(zoom: float) -> Vector2:
	match state:
		ScopeState.AIMING, ScopeState.FIRED:
			return _clamp_view_center(_aim_target, zoom)
		ScopeState.ENTERING, ScopeState.EXITING:
			# Slide between the resting view and the aim in sync with the zoom.
			var w := (zoom - 1.0) / (scope_zoom - 1.0)
			return BASE_CENTER.lerp(_clamp_view_center(_aim_target, zoom), w)
		_:
			return BASE_CENTER


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


func _settle_idle() -> void:
	state = ScopeState.IDLE
	_zoom_t = 0.0
	_cam_center = BASE_CENTER
	camera.position = BASE_CENTER
	camera.zoom = Vector2.ONE
	camera.offset = Vector2.ZERO
	overlay.visible = false
	set_process(false)


## Magnification for linear progress t, following CH's linear FOV tween.
func _zoom_at(t: float) -> float:
	var half_normal := deg_to_rad(NORMAL_FOV_DEG) * 0.5
	var half_scoped := atan(tan(half_normal) / scope_zoom)
	return tan(half_normal) / tan(lerpf(half_normal, half_scoped, t))


## Keeps the camera view rect fully inside camera_bounds.
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


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos
