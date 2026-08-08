class_name CrowdCharacter
extends Node2D
## One crowd member, rendered with _draw() from its DNA — no physics body.
## Visuals are the approved character artwork (male/female PNG picked from the
## DNA's hair style); origin stays at the feet. Hit detection is a rect test
## done by CrowdManager, and all movement is driven externally, so idle
## characters cost nothing per frame.

const MALE_TEXTURE := preload("res://assets/characters/crowd_male_01.png")
const FEMALE_TEXTURE := preload("res://assets/characters/crowd_female_01.png")

## Approved on-screen size: 300 canvas px tall at scale 1 (feet at origin).
const SPRITE_H := 300.0
## Hit rect for shots (visible body, narrower than the full texture).
const BODY_W := 74.0
const BODY_H := 300.0

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


## The character artwork for this DNA (feminine hair styles use the female
## sprite — the only visual axis the two-texture art set can express).
static func texture_for(character_dna: CharacterDNA) -> Texture2D:
	return FEMALE_TEXTURE if character_dna.hair_style in ["long", "bun"] else MALE_TEXTURE


func _draw() -> void:
	if dna == null:
		return
	# Ground shadow.
	draw_ellipse_approx(Vector2(0, -4), Vector2(40, 11), Color(0, 0, 0, 0.22))
	# Body artwork, feet at the origin, native aspect ratio.
	var tex := texture_for(dna)
	var tex_size := Vector2(tex.get_size())
	var width := tex_size.x * SPRITE_H / tex_size.y
	draw_texture_rect(tex, Rect2(-width * 0.5, -SPRITE_H, width, SPRITE_H), false)
	# Hit flash overlay.
	if _flash_color.a > 0.01:
		draw_rect(Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H), _flash_color)


func draw_ellipse_approx(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
