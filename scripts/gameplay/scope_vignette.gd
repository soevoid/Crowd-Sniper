class_name ScopeVignette
extends Node2D
## Fullscreen darkening while aiming — sells the "looking through a scope"
## tension without shaders. Drawn as one translucent rect.

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1080, 1920), Color(0.02, 0.03, 0.06, 0.28))
