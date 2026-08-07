class_name Backdrop
extends Node2D
## Placeholder environment: a city plaza drawn in one canvas item.

const PLAZA := Rect2(60, 400, 960, 1360)


func _draw() -> void:
	# Street base — extends past the design rect so the scoped camera can pan
	# to the play-area edges without showing void.
	draw_rect(Rect2(-200, -200, 1480, 2320), Color(0.13, 0.15, 0.19))
	# Plaza floor.
	draw_rect(PLAZA, Color(0.2, 0.22, 0.27))
	# Pavement grid.
	var line := Color(0.16, 0.18, 0.22)
	for i in range(1, 8):
		var y := PLAZA.position.y + PLAZA.size.y * i / 8.0
		draw_line(Vector2(PLAZA.position.x, y), Vector2(PLAZA.end.x, y), line, 3.0)
	for i in range(1, 5):
		var x := PLAZA.position.x + PLAZA.size.x * i / 5.0
		draw_line(Vector2(x, PLAZA.position.y), Vector2(x, PLAZA.end.y), line, 3.0)
	# Planters along the top edge.
	for i in 4:
		var x := 140.0 + i * 240.0
		draw_rect(Rect2(x, 340, 90, 40), Color(0.3, 0.24, 0.18))
		draw_circle(Vector2(x + 24, 340), 26.0, Color(0.2, 0.42, 0.24))
		draw_circle(Vector2(x + 60, 334), 30.0, Color(0.16, 0.36, 0.2))
	# Plaza edge highlight.
	draw_rect(PLAZA, Color(1, 1, 1, 0.05), false, 4.0)
