class_name AimController
extends Node2D
## Sniper-style touch aiming: press and hold to raise the scope, drag to move
## the crosshair (offset above the finger so it stays visible), release to
## fire. Emits `shot_fired` with the crosshair's world position.

signal aim_started
signal shot_fired(world_pos: Vector2)

## Crosshair floats above the finger so it is not covered by the hand.
const FINGER_OFFSET := Vector2(0, -170)
const FOLLOW_SPEED := 14.0
const SWAY_AMPLITUDE := 6.0

var enabled := false : set = set_enabled

var _aiming := false
var _aim_target := Vector2.ZERO
var _time := 0.0

@onready var crosshair: Node2D = $Crosshair
@onready var vignette: CanvasItem = $ScopeVignette


func _ready() -> void:
	crosshair.visible = false
	vignette.visible = false


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_stop_aim()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_aim(event.position)
		elif _aiming:
			_fire()
	elif event is InputEventScreenDrag and _aiming:
		_aim_target = event.position + FINGER_OFFSET


func _start_aim(pos: Vector2) -> void:
	_aiming = true
	_aim_target = pos + FINGER_OFFSET
	crosshair.position = _aim_target
	crosshair.visible = true
	vignette.visible = true
	set_process(true)
	aim_started.emit()


func _stop_aim() -> void:
	_aiming = false
	crosshair.visible = false
	vignette.visible = false
	set_process(false)


func _fire() -> void:
	var pos := crosshair.position
	_stop_aim()
	shot_fired.emit(pos)


func _process(delta: float) -> void:
	_time += delta
	# Smooth follow plus a subtle breathing sway for sniper feel.
	var sway := Vector2(
		sin(_time * 2.1) * SWAY_AMPLITUDE,
		cos(_time * 1.4) * SWAY_AMPLITUDE * 0.7)
	var goal := (_aim_target + sway).clamp(Vector2(20, 240), Vector2(1060, 1880))
	crosshair.position = crosshair.position.lerp(goal, 1.0 - exp(-FOLLOW_SPEED * delta))
