class_name Crosshair
extends Node2D
## Sniper scope reticle, drawn once (moving a canvas item does not re-draw).

const RADIUS := 92.0
const GAP := 18.0
const COLOR := Color(0.95, 0.95, 0.95, 0.95)
const ACCENT := Color(0.95, 0.2, 0.2, 0.9)


func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, COLOR, 4.0)
	draw_arc(Vector2.ZERO, RADIUS * 0.55, 0.0, TAU, 48, Color(COLOR.r, COLOR.g, COLOR.b, 0.35), 2.0)
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(dir * GAP, dir * RADIUS, COLOR, 3.0)
		draw_line(dir * RADIUS, dir * (RADIUS + 14.0), COLOR, 5.0)
	draw_circle(Vector2.ZERO, 3.5, ACCENT)
