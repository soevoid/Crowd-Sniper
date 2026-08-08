@tool
class_name CrowdSpots
extends Node2D
## Container for manually approved standing positions. Each Marker2D child
## ("CrowdSpot01", "CrowdSpot02", ...) marks the exact ground point where a
## character's feet may be placed — pavement only, never grass, benches,
## fountains, or walls. GameManager reads these markers for level placement.
##
## Spots are drawn as orange discs in the editor for level design, and in
## game only while debug_draw is enabled — never during normal gameplay.

@export var debug_draw := false :
	set(value):
		debug_draw = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	queue_redraw()  # editor only: follow markers while they are dragged


func _draw() -> void:
	if not Engine.is_editor_hint() and not debug_draw:
		return
	for child in get_children():
		if child is Marker2D:
			draw_circle(child.position, 12.0, Color(1.0, 0.55, 0.1, 0.75))
			draw_arc(child.position, 20.0, 0.0, TAU, 24, Color(1.0, 0.55, 0.1, 0.9), 3.0)


## Feet positions of every CrowdSpot marker, in scene order.
func spot_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D:
			result.append(child.position)
	return result
