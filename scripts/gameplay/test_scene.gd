extends Node2D
## MCP integration test scene: tap the red target, avoid the gray civilians.

@onready var crowd: Node2D = $Crowd
@onready var target: ColorRect = $Target
@onready var crosshair: Node2D = $Crosshair

func _ready() -> void:
	print("[TestScene] Ready. Viewport: ", get_viewport_rect().size, ". Tap the red target.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventMouseMotion:
		crosshair.move_to(event.position)

func _handle_tap(pos: Vector2) -> void:
	crosshair.move_to(pos)
	if target.get_global_rect().has_point(pos):
		print("[TestScene] HIT: target eliminated at ", pos)
		_flash(target)
		return
	for npc in crowd.get_children():
		if npc is ColorRect and npc.get_global_rect().has_point(pos):
			print("[TestScene] MISS: hit civilian ", npc.name, " at ", pos)
			_flash(npc)
			return
	print("[TestScene] MISS: nothing at ", pos)

func _flash(rect: ColorRect) -> void:
	var tween := create_tween()
	rect.modulate = Color(3.0, 3.0, 3.0)
	tween.tween_property(rect, "modulate", Color.WHITE, 0.3)
