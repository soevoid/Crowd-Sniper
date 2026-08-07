class_name ScopeOverlay
extends CanvasLayer
## Circular sniper scope overlay: darkened surround, lens rim, and a
## duplex-style reticle. Pure canvas drawing, redrawn only on viewport
## resize — no shaders, SubViewports, or textures (low-end Android friendly).

const SURROUND_COLOR := Color(0.01, 0.012, 0.02, 0.94)
const RIM_COLOR := Color(0.02, 0.02, 0.025, 1.0)
const LINE_COLOR := Color(0.05, 0.05, 0.06, 0.85)
const ACCENT := Color(0.9, 0.15, 0.1, 0.95)


func _ready() -> void:
	layer = 4
	var drawer := Drawer.new()
	add_child(drawer)
	get_viewport().size_changed.connect(drawer.queue_redraw)


class Drawer:
	extends Node2D

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var c := vs * 0.5
		var r := minf(vs.x, vs.y) * 0.47
		_draw_surround(c, r, vs.length() * 0.6)
		# Rim: thick dark ring plus soft inner shadows to sell lens depth.
		draw_arc(c, r + 5.0, 0.0, TAU, 96, ScopeOverlay.RIM_COLOR, 14.0)
		draw_arc(c, r - 8.0, 0.0, TAU, 96, Color(0, 0, 0, 0.3), 14.0)
		draw_arc(c, r - 20.0, 0.0, TAU, 96, Color(0, 0, 0, 0.12), 12.0)
		# Faint glass tint.
		draw_circle(c, r, Color(0.55, 0.7, 0.9, 0.03))
		_draw_reticle(c, r)

	## Ring of quads between the lens edge and past the screen corners.
	func _draw_surround(c: Vector2, inner_r: float, outer_r: float) -> void:
		const SEGMENTS := 64
		var quad := PackedVector2Array()
		quad.resize(4)
		for i in SEGMENTS:
			var d0 := Vector2.from_angle(TAU * i / SEGMENTS)
			var d1 := Vector2.from_angle(TAU * (i + 1) / SEGMENTS)
			quad[0] = c + d0 * inner_r
			quad[1] = c + d1 * inner_r
			quad[2] = c + d1 * outer_r
			quad[3] = c + d0 * outer_r
			draw_colored_polygon(quad, ScopeOverlay.SURROUND_COLOR)

	func _draw_reticle(c: Vector2, r: float) -> void:
		var lc := ScopeOverlay.LINE_COLOR
		# Fine cross through the center.
		draw_line(c + Vector2(-r * 0.94, 0), c + Vector2(r * 0.94, 0), lc, 2.0)
		draw_line(c + Vector2(0, -r * 0.94), c + Vector2(0, r * 0.94), lc, 2.0)
		# Heavy duplex posts toward the rim.
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + dir * r * 0.55, c + dir * r * 0.94, lc, 6.0)
		# Mil ticks near the center.
		for i in [1, 2]:
			var s: float = r * 0.15 * i
			draw_line(c + Vector2(s, -7), c + Vector2(s, 7), lc, 2.0)
			draw_line(c + Vector2(-s, -7), c + Vector2(-s, 7), lc, 2.0)
			draw_line(c + Vector2(-7, s), c + Vector2(7, s), lc, 2.0)
			draw_line(c + Vector2(-7, -s), c + Vector2(7, -s), lc, 2.0)
		# Center dot.
		draw_circle(c, 3.0, ScopeOverlay.ACCENT)
