extends Node2D
## Simple drawn crosshair that follows the pointer / last tap.

const RADIUS := 44.0
const GAP := 14.0
const THICKNESS := 4.0
const COLOR := Color(1.0, 1.0, 1.0, 0.9)

func _ready() -> void:
	move_to(get_viewport_rect().size * 0.5)

func move_to(pos: Vector2) -> void:
	position = pos
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, COLOR, THICKNESS)
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(dir * GAP, dir * (RADIUS + GAP), COLOR, THICKNESS)
	draw_circle(Vector2.ZERO, 4.0, COLOR)
