class_name BulletHole
extends Node2D
## Impact marker left where a shot lands; fades out and frees itself.

func _ready() -> void:
	z_index = 900
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(0.08, 0.07, 0.06))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.25, 0.22, 0.2, 0.7), 4.0)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		draw_line(Vector2(cos(a), sin(a)) * 13.0, Vector2(cos(a), sin(a)) * 22.0, Color(0.15, 0.13, 0.12, 0.8), 3.0)
