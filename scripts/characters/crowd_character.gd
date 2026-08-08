class_name PlazaCharacter
extends Area2D
## One reusable crowd character for the plaza environment.
##
## FOOT ANCHOR: the node's origin is the ground point under the feet. The
## sprite is lifted by half its texture height (read at runtime, never
## hardcoded), so the bottom of the shoes sits exactly on the origin and any
## scaling — depth or otherwise — happens around the feet, keeping them
## glued to the same ground point.
##
## DEPTH: optional Y-based perspective scale — characters lower in the image
## (nearer) render larger, higher (farther) smaller. Tuning is exported for
## visual calibration; the defaults are a starting point, not final values.
##
## TAP: emits character_tapped on a touch (or emulated mouse) tap that lands
## on the body without meaningful movement; pans are suppressed both by a
## local movement tolerance and by asking the WorldCamera whether the touch
## was a pan. (Class is named PlazaCharacter because the legacy prototype
## already owns the CrowdCharacter class name.)

signal character_tapped(character: PlazaCharacter)

@export var depth_scaling_enabled: bool = true
@export var depth_y_min: float = 360.0
@export var depth_y_max: float = 1240.0
@export var depth_scale_min: float = 0.0315
@export var depth_scale_max: float = 0.1092
## Screen px a touch may travel and still count as a tap.
@export var tap_move_tolerance := 12.0
## Prints texture/position/depth math on ready. Never enable in production.
@export var debug_logging := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _pressed := false
var _press_screen_pos := Vector2.ZERO
var _last_depth_y := INF


func _ready() -> void:
	var tex_size := Vector2(sprite.texture.get_size())
	# Foot anchor: centered sprite lifted by half its height.
	sprite.offset = Vector2(0, -tex_size.y * 0.5)
	# Capsule covering the visible body, defined in unscaled sprite space so
	# it scales with the whole node (never independently).
	var capsule := CapsuleShape2D.new()
	capsule.radius = tex_size.x * 0.22
	capsule.height = tex_size.y * 0.96
	collision.shape = capsule
	collision.position = Vector2(0, -tex_size.y * 0.5)
	_update_depth_scale()
	if debug_logging:
		var img := sprite.texture.get_image()
		print("[PlazaCharacter] texture=%s alpha=%s pos=%s depth_t=%.3f scale=%.4f" % [
			tex_size, img != null and img.detect_alpha() != Image.ALPHA_NONE,
			global_position, _depth_t(), scale.x])


func _process(_delta: float) -> void:
	# Re-evaluate depth only when the ground Y actually changed.
	if depth_scaling_enabled and global_position.y != _last_depth_y:
		_update_depth_scale()


func _depth_t() -> float:
	return clampf(inverse_lerp(depth_y_min, depth_y_max, global_position.y), 0.0, 1.0)


func _update_depth_scale() -> void:
	if not depth_scaling_enabled:
		return
	_last_depth_y = global_position.y
	var character_scale := lerpf(depth_scale_min, depth_scale_max, _depth_t())
	scale = Vector2.ONE * character_scale


## Tap detection via a manual world-space body test (physics picking does not
## reliably deliver touch events, and a direct test is cheaper for a future
## crowd anyway — a crowd manager can route this centrally later).
## Touch only: the project emulates touch from mouse, so desktop clicks
## arrive here too; handling both event types would double-fire.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if event.pressed:
			_pressed = _body_rect().has_point(world)
			_press_screen_pos = event.position
		elif _pressed:
			_pressed = false
			if _body_rect().has_point(world) \
					and event.position.distance_to(_press_screen_pos) <= tap_move_tolerance \
					and not _camera_was_panning():
				character_tapped.emit(self)
				print("Crowd character tapped: %s" %
					sprite.texture.resource_path.get_file().get_basename())


## World-space rect covering the visible body (matches the collision capsule).
func _body_rect() -> Rect2:
	var tex_size := Vector2(sprite.texture.get_size())
	var size := Vector2(tex_size.x * 0.44, tex_size.y * 0.96) * scale
	return Rect2(global_position - Vector2(size.x * 0.5, size.y), size)


func _camera_was_panning() -> bool:
	var cam := get_viewport().get_camera_2d()
	return cam != null and cam.has_method("was_recently_panning") and cam.was_recently_panning()
