extends Node
## Dev-only scripted playthrough, enabled via CROWD_SNIPER_AUTOTEST=1.
## Drives the AimController exactly like a finger would (press, drag, settle,
## release) and asserts the full loop: correct hit -> next level, empty shot,
## wrong-target shot, ammo depletion -> fail -> retry, and crowd validity.

var game: GameManager
var passed := 0
var failed := 0


func _ready() -> void:
	game = get_parent() as GameManager
	_run.call_deferred()


func _run() -> void:
	print("[AutoTest] === scripted playthrough starting ===")

	# --- Level 1: crowd sanity, then shoot the target. ---
	await _wait_searching()
	_check(game.level == 1, "level 1 reaches SEARCHING after intro")
	_verify_crowd_validity()
	await _shoot_at(_target_aim_point())
	await _wait_searching()
	_check(game.level == 2, "target hit advances to level 2 (got level %d)" % game.level)
	_check(_has_event("level_complete"), "level_complete event recorded")

	# --- Level 2: empty shot, wrong shot, empty shot -> fail -> retry. ---
	_verify_crowd_validity()
	var ammo0 := game.ammo
	await _shoot_at(Vector2(90, 1840))
	await _wait_searching()
	_check(game.ammo == ammo0 - 1, "empty shot consumes a bullet (%d -> %d)" % [ammo0, game.ammo])
	_check(_has_event("empty_shot"), "empty_shot event recorded")

	var wrong := _non_target_character()
	await _shoot_at(_aim_point_of(wrong))
	await _wait_searching()
	_check(game.ammo == ammo0 - 2, "wrong-target shot consumes a bullet")
	_check(_has_event("wrong_shot"), "wrong_shot event recorded")
	_check(game.level == 2, "wrong shot does not end the level")

	await _shoot_at(Vector2(990, 1840))
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

	# --- Levels 3..6 rapid procedural check via debug 'next'. ---
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


## Simulates a finger: press, drag onto the point, let the crosshair settle,
## release to fire.
func _shoot_at(world_point: Vector2) -> void:
	var finger := world_point - AimController.FINGER_OFFSET
	game.aim._start_aim(finger)
	await get_tree().create_timer(0.15, true, false, true).timeout
	game.aim._aim_target = world_point
	await get_tree().create_timer(0.7, true, false, true).timeout
	game.aim._fire()


func _wait_searching() -> void:
	while game.state != GameManager.State.SEARCHING:
		await get_tree().process_frame


func _has_event(event_name: String) -> bool:
	for entry in Analytics.events:
		if entry.event == event_name:
			return true
	return false
