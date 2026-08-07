class_name CrowdManager
extends Node2D
## Spawns and owns the crowd. One _process loop moves every character
## (no per-character processing), and shot queries are simple rect tests.

var characters: Array[CrowdCharacter] = []
var target_character: CrowdCharacter
var _movement_speed := 0.0
var _time := 0.0


func build(data: LevelGenerator.LevelData) -> void:
	clear()
	_movement_speed = data.config.movement_speed
	set_process(_movement_speed > 0.0)
	for i in data.crowd_dnas.size():
		var character := CrowdCharacter.new()
		add_child(character)
		character.setup(data.crowd_dnas[i], data.positions[i], data.config.character_scale)
		characters.append(character)
		if i == data.target_index:
			target_character = character


func clear() -> void:
	for character in characters:
		character.queue_free()
	characters.clear()
	target_character = null


func _process(delta: float) -> void:
	_time += delta
	# Gentle idle wander around each home position; amplitude = movement_speed.
	for character in characters:
		var p := character.wander_phase
		var f := character.wander_freq
		character.position = character.home_position + Vector2(
			sin(_time * f.x + p) * _movement_speed,
			cos(_time * f.y + p * 1.7) * _movement_speed * 0.35)


## Topmost character whose body rect contains the point (front = greater y).
func character_at(point: Vector2) -> CrowdCharacter:
	var best: CrowdCharacter = null
	for character in characters:
		if character.visible and character.hit_rect().has_point(point):
			if best == null or character.position.y > best.position.y:
				best = character
	return best


## Brief panic: characters near the impact hop away from it.
func react_to_shot(point: Vector2) -> void:
	for character in characters:
		var offset := character.position - point
		var dist := offset.length()
		if dist < 340.0 and character != target_character:
			var dir := offset.normalized() if dist > 1.0 else Vector2.RIGHT
			var jump := dir * (1.0 - dist / 340.0) * 26.0
			var tween := create_tween()
			tween.tween_property(character, "position", character.position + jump, 0.1)
			tween.tween_property(character, "position", character.position, 0.25)


func dim_all_except(kept: CrowdCharacter) -> void:
	for character in characters:
		if character != kept:
			var tween := create_tween()
			tween.tween_property(character, "modulate", Color(0.45, 0.45, 0.5), 0.3)


func reset_dim() -> void:
	for character in characters:
		character.modulate = Color.WHITE
