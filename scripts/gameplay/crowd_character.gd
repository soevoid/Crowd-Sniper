class_name CrowdCharacter
extends Node2D
## One crowd member, rendered entirely with _draw() from its DNA — no textures,
## no physics body. Hit detection is a rect test done by CrowdManager, and all
## movement is driven externally, so idle characters cost nothing per frame.

const BODY_W := 76.0
const BODY_H := 180.0

var dna: CharacterDNA
var home_position: Vector2
var wander_phase: float
var wander_freq: Vector2

var _flash_color := Color(1, 1, 1, 0)


func setup(character_dna: CharacterDNA, pos: Vector2, char_scale: float) -> void:
	dna = character_dna
	position = pos
	home_position = pos
	scale = Vector2(char_scale, char_scale)
	wander_phase = randf() * TAU
	wander_freq = Vector2(randf_range(0.5, 1.1), randf_range(0.4, 0.9))
	z_index = int(pos.y / 10.0)
	queue_redraw()


## World-space rect used for shot hit-testing.
func hit_rect() -> Rect2:
	var size := Vector2(BODY_W, BODY_H) * scale.x
	return Rect2(global_position - Vector2(size.x * 0.5, size.y), size)


func flash(color: Color) -> void:
	_flash_color = color
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_flash, color, Color(color.r, color.g, color.b, 0.0), 0.45)


func _set_flash(c: Color) -> void:
	_flash_color = c
	queue_redraw()


func _draw() -> void:
	if dna == null:
		return
	# Origin = feet. Character occupies x in [-38, 38], y in [-180, 0].
	var skin: Color = CharacterDNA.SKIN_TONE_VALUES[dna.skin_tone]
	var shirt: Color = CharacterDNA.SHIRT_COLOR_VALUES[dna.shirt_color]
	var pants: Color = CharacterDNA.PANTS_COLOR_VALUES[dna.pants_color]
	var hair: Color = CharacterDNA.HAIR_COLOR_VALUES[dna.hair_color]

	# Ground shadow.
	draw_ellipse_approx(Vector2(0, -2), Vector2(34, 9), Color(0, 0, 0, 0.22))

	# Legs.
	draw_rect(Rect2(-16, -78, 13, 76), pants)
	draw_rect(Rect2(3, -78, 13, 76), pants)
	# Shoes.
	draw_rect(Rect2(-18, -8, 17, 8), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(1, -8, 17, 8), Color(0.1, 0.1, 0.1))

	# Torso.
	var torso := Rect2(-24, -140, 48, 64)
	draw_rect(torso, shirt)
	match dna.shirt_style:
		"jacket":
			var dark := shirt.darkened(0.35)
			draw_rect(Rect2(torso.position.x, torso.position.y, 10, torso.size.y), dark)
			draw_rect(Rect2(torso.end.x - 10, torso.position.y, 10, torso.size.y), dark)
			draw_line(Vector2(0, -140), Vector2(0, -76), dark, 3.0)
		"hoodie":
			draw_circle(Vector2(0, -138), 16.0, shirt.darkened(0.2))
	# Arms.
	draw_rect(Rect2(-32, -138, 8, 52), shirt.darkened(0.12))
	draw_rect(Rect2(24, -138, 8, 52), shirt.darkened(0.12))
	# Hands.
	draw_circle(Vector2(-28, -84), 5.0, skin)
	draw_circle(Vector2(28, -84), 5.0, skin)

	# Accessory.
	match dna.accessory:
		"bag":
			draw_line(Vector2(-22, -136), Vector2(20, -92), Color(0.35, 0.25, 0.15), 5.0)
			draw_rect(Rect2(12, -96, 16, 20), Color(0.35, 0.25, 0.15))
		"scarf":
			draw_rect(Rect2(-14, -146, 28, 10), Color(0.85, 0.3, 0.3))

	# Head.
	draw_circle(Vector2(0, -158), 18.0, skin)

	# Hair.
	match dna.hair_style:
		"short":
			draw_circle_arc_poly(Vector2(0, -158), 18.5, PI, TAU, hair)
		"long":
			draw_circle_arc_poly(Vector2(0, -158), 19.0, PI, TAU, hair)
			draw_rect(Rect2(-19, -158, 7, 26), hair)
			draw_rect(Rect2(12, -158, 7, 26), hair)
		"bun":
			draw_circle_arc_poly(Vector2(0, -158), 18.5, PI, TAU, hair)
			draw_circle(Vector2(0, -178), 7.0, hair)
		"mohawk":
			draw_rect(Rect2(-4, -182, 8, 24), hair)
		"bald":
			pass

	# Glasses.
	if dna.glasses:
		var gcol := Color(0.1, 0.1, 0.12)
		draw_arc(Vector2(-8, -158), 6.0, 0, TAU, 16, gcol, 2.5)
		draw_arc(Vector2(8, -158), 6.0, 0, TAU, 16, gcol, 2.5)
		draw_line(Vector2(-2, -158), Vector2(2, -158), gcol, 2.5)

	# Hat (drawn over hair).
	if dna.hat:
		var hat_col := Color(0.2, 0.3, 0.2)
		draw_rect(Rect2(-16, -184, 32, 12), hat_col)
		draw_rect(Rect2(-22, -174, 44, 5), hat_col.darkened(0.2))

	# Hit flash overlay.
	if _flash_color.a > 0.01:
		draw_rect(Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H), _flash_color)


func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


func draw_circle_arc_poly(center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
	var points := PackedVector2Array([center])
	for i in 17:
		var a := from + (to - from) * i / 16.0
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)
