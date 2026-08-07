extends Node
## Dev-only scripted playthrough, enabled via CROWD_SNIPER_AUTOTEST=1.
## Drives the AimController exactly like a finger would (press -> scope zooms
## in -> drag onto the point -> settle -> release fires) and asserts the full
## loop: scope mechanics (cancel, fire gating, camera bounds), correct hit ->
## next level, empty shot, wrong-target shot, ammo depletion -> fail -> retry,
## and crowd validity.

var game: GameManager
var passed := 0
var failed := 0


func _ready() -> void:
	game = get_parent() as GameManager
	_run.call_deferred()


func _run() -> void:
	print("[AutoTest] === scripted playthrough starting ===")

	# --- Level 1: crowd sanity, then scope mechanics. ---
	await _wait_searching()
	_check(game.level == 1, "level 1 reaches SEARCHING after intro")
	_verify_crowd_validity()

	var aim := game.aim
	var shots_before := _count_events("shot")
	var ammo_full := game.ammo
	aim._begin_scope(Vector2(540, 960))
	_check(aim.overlay.visible, "scope overlay appears on touch down")
	_check(not aim.can_fire, "cannot fire before zoom-in completes")
	aim._handle_release()  # quick tap: released before the zoom finished
	await _real(0.6)
	_check(_count_events("shot") == shots_before, "quick tap does not fire")
	_check(game.ammo == ammo_full, "quick tap does not consume ammo")
	_check(is_equal_approx(game.camera.zoom.x, 1.0), "camera returns to normal zoom after cancel")
	_check(not aim.overlay.visible, "scope overlay hidden after cancel")

	aim._begin_scope(Vector2(540, 960))
	_check(await _wait_can_fire(), "zoom-in completes and enables firing")
	_check(absf(game.camera.zoom.x - aim.scope_zoom) < 0.01,
		"scoped zoom reaches scope_zoom (%.2f vs %.2f)" % [game.camera.zoom.x, aim.scope_zoom])
	await _screenshot("scoped")
	aim._apply_drag(Vector2(-100000, -100000))  # yank far past the boundary
	await _real(0.5)
	var half_view: Vector2 = game.get_viewport().get_visible_rect().size * 0.5 / game.camera.zoom.x
	var top_left: Vector2 = game.camera.position - half_view
	_check(top_left.x >= aim.camera_bounds.position.x - 1.0
		and top_left.y >= aim.camera_bounds.position.y - 1.0,
		"camera view stays inside bounds when dragging beyond them")
	aim._exit_scope()  # lower the scope without firing
	await _real(0.6)
	_check(is_equal_approx(game.camera.zoom.x, 1.0), "scope exits back to normal view")
	await _screenshot("normal")

	# --- Level 1 kill: shoot the target. ---
	await _shoot_at(_target_aim_point())
	await _wait_searching()
	_check(game.level == 2, "target hit advances to level 2 (got level %d)" % game.level)
	_check(_has_event("level_complete"), "level_complete event recorded")

	# --- Level 2: empty shot, wrong shot, empty shot -> fail -> retry. ---
	_verify_crowd_validity()
	var ammo0 := game.ammo
	await _shoot_at(_empty_point())
	await _wait_searching()
	_check(game.ammo == ammo0 - 1, "empty shot consumes a bullet (%d -> %d)" % [ammo0, game.ammo])
	_check(_has_event("empty_shot"), "empty_shot event recorded")

	var wrong := _non_target_character()
	await _shoot_at(_aim_point_of(wrong))
	await _wait_searching()
	_check(game.ammo == ammo0 - 2, "wrong-target shot consumes a bullet")
	_check(_has_event("wrong_shot"), "wrong_shot event recorded")
	_check(game.level == 2, "wrong shot does not end the level")

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
	_check(game.crowd.characters.size() == game.current_config.crowd_count,
		"crowd size matches config (%d)" % game.current_config.crowd_count)


func _target_aim_point() -> Vector2:
	return _aim_point_of(game.crowd.target_character)


func _aim_point_of(character: CrowdCharacter) -> Vector2:
	# Chest center: feet position minus half body height.
	return character.position + Vector2(0, -90.0 * character.scale.x)


func _non_target_character() -> CrowdCharacter:
	for character in game.crowd.characters:
		if character != game.crowd.target_character:
			return character
	return null


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


## Simulates a finger: press (scope raises), wait for full zoom, put the aim
## on the point, let the camera settle, release to fire.
func _shoot_at(world_point: Vector2) -> void:
	var aim := game.aim
	aim._begin_scope(aim.get_canvas_transform() * world_point)
	_check(await _wait_can_fire(), "scope ready to fire before the shot")
	aim._aim_target = aim._clamp_aim(world_point)
	await _real(0.5)
	aim._handle_release()


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
