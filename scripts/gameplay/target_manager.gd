class_name TargetManager
extends CanvasLayer
## Owns the "WANTED" presentation: fullscreen target intro at level start,
## then a persistent portrait card at the top of the screen.

signal intro_finished

const CARD_POS := Vector2(908, 150)
const INTRO_POS := Vector2(540, 900)

var _intro_running := false

@onready var dimmer: ColorRect = $Dimmer
@onready var wanted_label: Label = $WantedLabel
@onready var portrait_holder: Node2D = $PortraitHolder
@onready var card_frame: Panel = $CardFrame

var _portrait: CrowdCharacter


func show_target(dna: CharacterDNA, memory_time: float) -> void:
	_clear_portrait()
	_portrait = CrowdCharacter.new()
	portrait_holder.add_child(_portrait)
	_portrait.setup(dna, Vector2.ZERO, 1.0)

	# Fullscreen intro.
	_intro_running = true
	dimmer.visible = true
	dimmer.modulate.a = 1.0
	wanted_label.visible = true
	card_frame.visible = false
	portrait_holder.position = INTRO_POS + Vector2(0, 160)
	portrait_holder.scale = Vector2(3.0, 3.0)

	var tween := create_tween()
	tween.tween_interval(memory_time)
	tween.tween_callback(_shrink_to_card)


func _shrink_to_card() -> void:
	wanted_label.visible = false
	card_frame.visible = true
	var tween := create_tween().set_parallel()
	tween.tween_property(portrait_holder, "position", CARD_POS + Vector2(0, 84), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(portrait_holder, "scale", Vector2(0.82, 0.82), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(func () -> void:
		dimmer.visible = false
		_intro_running = false
		intro_finished.emit())


func hide_card() -> void:
	card_frame.visible = false
	portrait_holder.visible = false


func _clear_portrait() -> void:
	if _portrait != null and is_instance_valid(_portrait):
		_portrait.queue_free()
	_portrait = null
	portrait_holder.visible = true
