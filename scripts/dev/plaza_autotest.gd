extends Node
## Dev-only acceptance test for the plaza background + pan milestone,
## enabled via CROWD_SNIPER_PLAZA_TEST=1 on the plaza scene. Synthesizes
## real touches (Viewport.push_input, canvas coords) and asserts fit zoom,
## centering, horizontal-only clamped panning, tap threshold, and resize
## recalculation.

var cam: WorldCamera
var passed := 0
var failed := 0
var _finger := Vector2.ZERO
var _tap_received := false


func _ready() -> void:
	cam = get_parent() as WorldCamera
	# Headless runs default to a 1920x1080 landscape window; force portrait.
	get_window().size = Vector2i(540, 960)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await _real(0.3)  # let the resize-driven refit settle
	print("[PlazaTest] === background + pan milestone checks ===")

	_check(cam.background != null, "camera resolved its background reference")
	if cam.background == null:
		_finish()
		return
	var tex: Texture2D = cam.background.texture
	_check(tex != null and tex.get_size() == Vector2(3168, 1344),
		"texture native size is 3168x1344 (got %s)" % tex.get_size())
	_check(cam.background.centered == false and cam.background.position == Vector2.ZERO
		and cam.background.scale == Vector2.ONE,
		"background at (0,0), non-centered, native scale")

	var vp: Vector2 = cam.get_viewport_rect().size
	var expected_zoom: float = vp.y / 1344.0
	_check(absf(cam.zoom.x - expected_zoom) < 0.0001 and cam.zoom.x == cam.zoom.y,
		"fit zoom = viewport_height/1344 on both axes (%.4f)" % cam.zoom.x)
	_check(absf(cam.position.x - 1584.0) < 1.0 and absf(cam.position.y - 672.0) < 0.01,
		"initial camera at world center (1584, 672), got %s" % cam.position)

	await _test_character()

	# Tap without meaningful drag must not move the camera.
	var x0: float = cam.position.x
	_press(Vector2(540, 900))
	await _drag_by(Vector2(-6, 0), 2)  # under the 12 px threshold
	_release_finger()
	await _real(0.3)
	_check(absf(cam.position.x - x0) < 1.0, "tap/tiny drag does not move the camera")

	# Drag left reveals the right side (camera x increases), horizontal only.
	_press(Vector2(540, 900))
	await _drag_by(Vector2(-260, 140), 8)
	_release_finger()
	await _real(0.4)
	_check(cam.position.x > x0 + 50.0, "drag left pans toward the right side")
	_check(absf(cam.position.y - 672.0) < 0.01, "vertical drag ignored, Y locked at 672")

	# Clamp precisely at both edges; view never leaves the image.
	var visible_w: float = vp.x / cam.zoom.x
	var max_x: float = 3168.0 - visible_w * 0.5
	var min_x: float = visible_w * 0.5
	_press(Vector2(540, 900))
	await _drag_by(Vector2(-20000, 0), 6)
	_release_finger()
	await _real(0.5)
	_check(absf(cam.position.x - max_x) < 1.0,
		"camera stops exactly at the right boundary (%.1f vs %.1f)" % [cam.position.x, max_x])
	_check(cam.position.x + visible_w * 0.5 <= 3168.0 + 0.5, "no empty space past the right edge")
	_press(Vector2(540, 900))
	await _drag_by(Vector2(20000, 0), 6)
	_release_finger()
	await _real(0.5)
	_check(absf(cam.position.x - min_x) < 1.0,
		"camera stops exactly at the left boundary (%.1f vs %.1f)" % [cam.position.x, min_x])
	_check(cam.position.x - visible_w * 0.5 >= -0.5, "no empty space past the left edge")

	# Window resize recalculates zoom and bounds.
	get_window().size = Vector2i(480, 1040)
	await _real(0.3)
	var vp2: Vector2 = cam.get_viewport_rect().size
	_check(absf(cam.zoom.x - vp2.y / 1344.0) < 0.0001,
		"resize recalculates fit zoom (viewport %s -> zoom %.4f)" % [vp2, cam.zoom.x])
	var visible_w2: float = vp2.x / cam.zoom.x
	_check(cam.position.x - visible_w2 * 0.5 >= -0.5
		and cam.position.x + visible_w2 * 0.5 <= 3168.5,
		"camera re-clamped inside bounds after resize")

	_finish()


func _finish() -> void:
	print("[PlazaTest] === DONE: %d passed, %d failed ===" % [passed, failed])
	if failed == 0:
		print("[PlazaTest] ALL CHECKS PASSED")
	else:
		printerr("[PlazaTest] %d CHECKS FAILED" % failed)
	get_tree().quit(0 if failed == 0 else 1)


## Single reusable crowd character: alpha, foot anchor, depth scale, tap.
func _test_character() -> void:
	var characters: Array[PlazaCharacter] = []
	for node in get_tree().current_scene.get_node("Characters").get_children():
		if node is PlazaCharacter:
			characters.append(node)
	_check(characters.size() == 2, "expected crowd characters present (male + female)")
	if characters.is_empty():
		return
	var chr: PlazaCharacter = characters[0]
	_check(get_tree().current_scene.get_node("Characters").y_sort_enabled,
		"character container has Y-sorting enabled")

	var tex: Texture2D = chr.sprite.texture
	var img: Image = tex.get_image()
	_check(img != null and img.detect_alpha() != Image.ALPHA_NONE,
		"character PNG has genuine alpha transparency")
	_check(tex.get_size() == Vector2(1440, 2912),
		"character texture at native size (got %s)" % tex.get_size())

	# Foot anchor: sprite bottom = node origin, read from the texture.
	_check(chr.sprite.offset == Vector2(0, -tex.get_size().y * 0.5),
		"sprite offset anchors feet at origin (offset %s)" % chr.sprite.offset)
	_check(chr.position == Vector2(1584, 820), "character feet at test position (1584, 820)")

	# Depth scale at y=820 per the exported formula.
	var expected_t: float = clampf(inverse_lerp(chr.depth_y_min, chr.depth_y_max, 820.0), 0.0, 1.0)
	var expected_scale: float = lerpf(chr.depth_scale_min, chr.depth_scale_max, expected_t)
	_check(absf(chr.scale.x - expected_scale) < 0.001 and chr.scale.x == chr.scale.y,
		"depth scale at y=820 is %.4f (uniform)" % chr.scale.x)

	# Moving the feet down (nearer) grows the character; feet stay anchored.
	chr.position.y = 1000.0
	await _real(0.15)  # a plain process_frame await can resume before _process runs
	var near_scale: float = chr.scale.x
	_check(near_scale > expected_scale + 0.008,
		"lower Y (nearer) increases scale (%.4f -> %.4f)" % [expected_scale, near_scale])
	_check(chr.position == Vector2(1584, 1000), "feet stay at the set ground point while scaling")
	chr.position.y = 820.0
	await _real(0.15)

	# Tap on the body (touch through the real input path) fires the signal.
	chr.character_tapped.connect(func (_c: PlazaCharacter) -> void: _tap_received = true)
	var body_world: Vector2 = chr.global_position + Vector2(0, -tex.get_size().y * 0.5 * chr.scale.y)
	var screen: Vector2 = get_viewport().get_canvas_transform() * body_world
	_press(screen)
	await _real(0.15)
	_release_finger()
	await _real(0.3)
	_check(_tap_received, "tap on the character fires character_tapped")

	# A pan that ends on the character must NOT fire the signal.
	_tap_received = false
	_press(screen + Vector2(200, 0))
	await _drag_by(Vector2(-200, 0), 6)
	_release_finger()
	await _real(0.4)
	_check(not _tap_received, "camera drag ending on the character does not tap")
	# Reset camera drift from that pan (target too, or it lerps right back).
	cam._target_x = 1584.0
	cam.position.x = 1584.0
	await _real(0.2)
	await _screenshot("plaza_character")


func _screenshot(label: String) -> void:
	var dir := OS.get_environment("CROWD_SNIPER_SHOT_DIR")
	if dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join("%s.png" % label)
	image.save_png(path)
	print("[PlazaTest] screenshot saved: " + path)


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[PlazaTest] PASS: " + label)
	else:
		failed += 1
		printerr("[PlazaTest] FAIL: " + label)


func _press(pos: Vector2) -> void:
	_finger = pos
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = true
	get_viewport().push_input(e, true)


func _drag_by(total: Vector2, steps: int) -> void:
	var step := total / steps
	for i in steps:
		_finger += step
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = _finger
		e.relative = step
		get_viewport().push_input(e, true)
		await get_tree().process_frame


func _release_finger() -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = _finger
	e.pressed = false
	get_viewport().push_input(e, true)


func _real(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, true, false, true).timeout
