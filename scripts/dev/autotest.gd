extends Node
## Dev-only scripted playthrough, enabled via CROWD_SNIPER_AUTOTEST=1.
## Synthesizes real touch events (Viewport.push_input) to exercise the full
## input path: normal-view world panning (search), AIM-button scope raise,
## zoom-gated fire-on-release, then the level loop: correct hit -> next
## level, empty shot, wrong shot, ammo depletion -> fail -> retry, and
## crowd validity.

var game: GameManager
var passed := 0
var failed := 0
var _finger := Vector2.ZERO


func _ready() -> void:
	game = get_parent() as GameManager
	# Headless runs default to a 1920x1080 landscape window, which breaks the
	# portrait canvas (and thus pan bounds). Force the design window size.
	get_window().size = Vector2i(540, 960)
	_run.call_deferred()


func _run() -> void:
	print("[AutoTest] === scripted playthrough starting ===")

	await _wait_searching()
	_check(game.level == 1, "level 1 reaches SEARCHING after intro")
	_verify_crowd_validity()

	await _test_normal_pan()
	await _test_scope_mechanics()

	# --- Level 1 kill: shoot the target. ---
	await _shoot_at(_target_aim_point())
	await _wait_searching()
	_check(game.level == 2, "target hit advances to level 2 (got level %d)" % game.level)
	_check(_has_event("level_complete"), "level_complete event recorded")

	# --- Level 2: three non-target shots -> fail -> retry. ---
	_verify_crowd_validity()
	var ammo0 := game.ammo
	await _shoot_at(_empty_point())
	await _wait_searching()
	_check(game.ammo == ammo0 - 1, "non-target shot consumes a bullet (%d -> %d)" % [ammo0, game.ammo])
	_check(_has_event("wrong_shot"), "wrong_shot event recorded for any non-target shot")
	_check(game.level == 2, "non-target shot does not end the level")

	await _shoot_at(_empty_point())
	await _wait_searching()
	_check(game.ammo == ammo0 - 2, "second non-target shot consumes a bullet")

	await _shoot_at(_empty_point())
	# Ammo now 0 -> fail -> same level restarts with a fresh crowd.
	await _wait_searching()
	_check(_has_event("level_fail"), "level_fail event recorded at 0 ammo")
	_check(game.level == 2, "failed level restarts at the same level number")
	_check(game.ammo == game.current_config.ammo, "ammo refilled after retry")

	# --- Retry of level 2: shoot target to confirm regeneration works. ---
	_verify_crowd_validity()
	await _shoot_at(_target_aim_point())
	await _wait_searching()
	_check(game.level == 3, "retry then target hit advances to level 3")

	# --- CrowdSpot placement: temporary markers injected, then removed. ---
	var spots_node: Node2D = game.get_node("CrowdSpots")
	for i in 30:
		var marker := Marker2D.new()
		marker.position = Vector2(120.0 + (i % 6) * 150.0, 500.0 + int(i / 6.0) * 220.0)
		spots_node.add_child(marker)
	# All markers (scene-designed + temporary) are legitimate standing spots.
	var spot_positions: Array[Vector2] = []
	for child in spots_node.get_children():
		if child is Marker2D:
			spot_positions.append(child.position)
	game.start_level(game.level)
	await _wait_searching()
	var off_spot := 0
	for character in game.crowd.characters:
		if not spot_positions.has(character.home_position):
			off_spot += 1
	_check(off_spot == 0, "all characters stand exactly on CrowdSpot markers (%d off)" % off_spot)
	_verify_crowd_validity()
	for child in spots_node.get_children():
		child.queue_free()
	await get_tree().process_frame
	game.start_level(game.level)
	await _wait_searching()
	_check(game.crowd.characters.size() == 1,
		"no spots -> generator placement still works")

	# --- Procedural config sanity. ---
	for n in [10, 20]:
		var config := LevelConfig.for_level(n)
		_check(config.crowd_count > 0 and config.similarity < 1.0 and config.ammo > 0,
			"LevelConfig.for_level(%d) valid: crowd=%d sim=%.2f decoys=%d move=%.1f" %
			[n, config.crowd_count, config.similarity, config.decoy_count, config.movement_speed])

	print("[AutoTest] === DONE: %d passed, %d failed ===" % [passed, failed])
	if failed == 0:
		print("[AutoTest] ALL CHECKS PASSED")
	else:
		printerr("[AutoTest] %d CHECKS FAILED" % failed)


## Normal view: dragging the playfield pans the camera; release never fires.
func _test_normal_pan() -> void:
	var aim := game.aim
	var shots0 := _count_events("shot")
	var cam0: Vector2 = game.camera.position

	_press(Vector2(540, 900))
	await _drag_by(Vector2(-360, 0), 8)
	await _real(0.3)
	_check(game.camera.position.x > cam0.x + 40.0,
		"drag left pans camera right (map-style, moved %.0f px)" % (game.camera.position.x - cam0.x))
	var x_right: float = game.camera.position.x
	await _drag_by(Vector2(720, 0), 8)
	await _real(0.3)
	_check(game.camera.position.x < x_right - 40.0, "drag right pans camera left")
	var y0: float = game.camera.position.y
	await _drag_by(Vector2(0, -400), 8)
	await _real(0.3)
	_check(game.camera.position.y > y0 + 20.0, "drag up pans camera down")
	var y1: float = game.camera.position.y
	await _drag_by(Vector2(0, 800), 8)
	await _real(0.3)
	_check(game.camera.position.y < y1 - 20.0, "drag down pans camera up")
	_release_finger()
	await _real(0.4)
	_check(_count_events("shot") == shots0, "pan release does not fire")
	_check(not aim.overlay.visible, "pan does not raise the scope")
	_check(is_equal_approx(game.camera.zoom.x, 1.0), "pan does not zoom")
	_check(game.ammo == game.current_config.ammo, "pan consumes no ammo")

	# Bounds: yank far past every edge (map-style: drag towards top-left
	# pushes the camera to the bottom-right corner and vice versa).
	_press(Vector2(540, 900))
	await _drag_by(Vector2(-20000, -20000), 6)
	await _real(0.4)
	var half: Vector2 = game.get_viewport().get_visible_rect().size * 0.5 / game.camera.zoom.x
	var br: Vector2 = game.camera.position + half
	_check(br.x <= aim.camera_bounds.end.x + 1.0 and br.y <= aim.camera_bounds.end.y + 1.0,
		"pan clamps at bottom-right bounds")
	await _drag_by(Vector2(40000, 40000), 6)
	await _real(0.4)
	var tl: Vector2 = game.camera.position - half
	_check(tl.x >= aim.camera_bounds.position.x - 1.0 and tl.y >= aim.camera_bounds.position.y - 1.0,
		"pan clamps at top-left bounds")
	_release_finger()
	await _real(0.2)

	# Touches starting on HUD chrome must not pan the world.
	var cam1: Vector2 = game.camera.position
	_press(Vector2(300, 90))  # top stats panel
	await _drag_by(Vector2(-300, 200), 6)
	await _real(0.3)
	_check(game.camera.position.distance_to(cam1) < 2.0, "HUD touches do not pan the world")
	_release_finger()
	await _real(0.2)


## AIM button: quick tap cancels, zoom gates firing and preserves the
## searched area, bounds hold, panning resumes afterwards.
func _test_scope_mechanics() -> void:
	var aim := game.aim
	var btn := HUD.AIM_BUTTON_RECT.get_center()
	var shots0 := _count_events("shot")
	var searched: Vector2 = game.camera.position

	_press(btn)
	_check(aim.overlay.visible, "scope overlay appears on AIM press")
	_check(not aim.can_fire, "cannot fire before zoom-in completes")
	_release_finger()  # quick tap: released before the zoom finished
	await _real(0.6)
	_check(_count_events("shot") == shots0, "quick AIM tap does not fire")
	_check(game.ammo == game.current_config.ammo, "quick AIM tap does not consume ammo")
	_check(is_equal_approx(game.camera.zoom.x, 1.0), "camera returns to normal zoom after cancel")
	_check(not aim.overlay.visible, "scope overlay hidden after cancel")

	_press(btn)
	_check(await _wait_can_fire(), "zoom-in completes and enables firing")
	_check(absf(game.camera.zoom.x - aim.scope_zoom) < 0.01,
		"scoped zoom reaches scope_zoom (%.2f vs %.2f)" % [game.camera.zoom.x, aim.scope_zoom])
	_check(game.camera.position.distance_to(searched) < 60.0,
		"scope zooms into the searched area (drift %.0f px)" %
		game.camera.position.distance_to(searched))
	await _screenshot("scoped")
	await _drag_by(Vector2(-100000, -100000), 4)  # fine-aim far past the boundary
	await _real(0.5)
	var half: Vector2 = game.get_viewport().get_visible_rect().size * 0.5 / game.camera.zoom.x
	var tl: Vector2 = game.camera.position - half
	_check(tl.x >= aim.camera_bounds.position.x - 1.0 and tl.y >= aim.camera_bounds.position.y - 1.0,
		"scoped view stays inside bounds when dragging beyond them")
	aim._exit_scope()  # lower the scope without firing
	_release_finger()
	await _real(0.6)
	_check(is_equal_approx(game.camera.zoom.x, 1.0), "scope exits back to normal view")
	await _screenshot("normal")

	# Normal search panning still works after the scope (map-style: dragging
	# left moves the camera right, away from the left bound it ended near).
	var cam2: Vector2 = game.camera.position
	_press(Vector2(540, 900))
	await _drag_by(Vector2(-300, 0), 6)
	await _real(0.3)
	_check(game.camera.position.x > cam2.x + 20.0, "world panning works again after scope")
	_release_finger()
	await _real(0.2)


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[AutoTest] PASS: " + label)
	else:
		failed += 1
		printerr("[AutoTest] FAIL: " + label)


## Exactly one crowd member matches the target DNA on active traits.
func _verify_crowd_validity() -> void:
	var active: Array[String] = []
	for i in mini(game.current_config.target_trait_count, CharacterDNA.TRAIT_SPACE.size()):
		active.append(CharacterDNA.trait_names()[i])
	var matches := 0
	for character in game.crowd.characters:
		if character.dna.equals(game.current_target_dna, active):
			matches += 1
	_check(matches == 1, "exactly one exact target in crowd of %d (found %d)" %
		[game.crowd.characters.size(), matches])
	_check(game.crowd.characters.size() == 1,
		"world contains only the target character (decoys live in the art)")


func _target_aim_point() -> Vector2:
	return _aim_point_of(game.crowd.target_character)


func _aim_point_of(character: CrowdCharacter) -> Vector2:
	# Chest center: feet position minus half body height.
	return character.position + Vector2(0, -90.0 * character.scale.x)


## A reachable aim point as far from every character as possible, so a shot
## there is a guaranteed miss.
func _empty_point() -> Vector2:
	var best := Vector2(540, 1700)
	var best_d := 0.0
	for gy in 15:
		for gx in 11:
			var candidate: Vector2 = game.aim._clamp_aim(
				Vector2(60.0 + gx * 96.0, 280.0 + gy * 100.0))
			var d := INF
			for character in game.crowd.characters:
				d = minf(d, candidate.distance_to(character.position + Vector2(0, -90)))
			if d > best_d:
				best_d = d
				best = candidate
	return best


## Simulates the sniper loop: press AIM, wait for full zoom, put the aim on
## the point (fine-adjust shortcut), settle, release to fire.
func _shoot_at(world_point: Vector2) -> void:
	var aim := game.aim
	_press(HUD.AIM_BUTTON_RECT.get_center())
	_check(await _wait_can_fire(), "scope ready to fire before the shot")
	aim._aim_target = aim._clamp_aim(world_point)
	await _real(0.5)
	_release_finger()


## -- Synthetic touch input (goes through the real Viewport input path). --

func _press(pos: Vector2) -> void:
	_finger = pos
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = true
	game.get_viewport().push_input(e, true)  # positions are canvas coords


func _drag_by(total: Vector2, steps: int) -> void:
	var step := total / steps
	for i in steps:
		_finger += step
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = _finger
		e.relative = step
		game.get_viewport().push_input(e, true)
		await get_tree().process_frame


func _release_finger() -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = _finger
	e.pressed = false
	game.get_viewport().push_input(e, true)


func _wait_can_fire() -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while not game.aim.can_fire:
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _wait_searching() -> void:
	while game.state != GameManager.State.SEARCHING:
		await get_tree().process_frame


func _real(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, true, false, true).timeout


## Saves a viewport capture when CROWD_SNIPER_SHOT_DIR is set (windowed runs
## only — headless has no renderer).
func _screenshot(label: String) -> void:
	var dir := OS.get_environment("CROWD_SNIPER_SHOT_DIR")
	if dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := game.get_viewport().get_texture().get_image()
	var path := dir.path_join("autotest_%s.png" % label)
	image.save_png(path)
	print("[AutoTest] screenshot saved: " + path)


func _has_event(event_name: String) -> bool:
	return _count_events(event_name) > 0


func _count_events(event_name: String) -> int:
	var count := 0
	for entry in Analytics.events:
		if entry.event == event_name:
			count += 1
	return count
