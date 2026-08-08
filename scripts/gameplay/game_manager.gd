class_name GameManager
extends Node2D
## Level/state orchestration only: INTRO -> SEARCHING -> RESOLVING -> next.
## Generation lives in LevelGenerator, crowd in CrowdManager, input in
## AimController, presentation in TargetManager/HUD.

enum State { INTRO, SEARCHING, RESOLVING }

var state: State = State.INTRO
var level: int = 1
var ammo: int = 3
var current_config: LevelConfig
var current_target_dna: CharacterDNA

var _generator := LevelGenerator.new()
var _shots_used := 0
var _search_start_ms := 0

@onready var crowd: CrowdManager = $Crowd
@onready var aim: AimController = $AimController
@onready var target_manager: TargetManager = $TargetManager
@onready var hud: HUD = $HUD
@onready var debug_panel: DebugPanel = $DebugPanel
@onready var camera: Camera2D = $Camera
@onready var effects: Node2D = $Effects
@onready var flash_rect: ColorRect = $FlashLayer/Flash


func _ready() -> void:
	aim.camera = camera
	aim.hud = hud
	aim.ui_blockers = [hud.is_point_on_blocking_ui, debug_panel.is_point_on_ui]
	aim.shot_fired.connect(_on_shot_fired)
	target_manager.intro_finished.connect(_on_intro_finished)
	debug_panel.restart_requested.connect(func () -> void: start_level(level))
	debug_panel.next_level_requested.connect(func () -> void: start_level(level + 1))
	debug_panel.regenerate_requested.connect(func () -> void: start_level(level))
	debug_panel.attach(self)
	# Dev-only hooks (no effect unless the env vars are set).
	var start_env := OS.get_environment("CROWD_SNIPER_START_LEVEL")
	start_level(int(start_env) if start_env.is_valid_int() else 1)
	if OS.get_environment("CROWD_SNIPER_AUTOTEST") == "1":
		add_child(load("res://scripts/dev/autotest.gd").new())
	if OS.get_environment("CROWD_SNIPER_FPS_PROBE") == "1":
		var probe := Timer.new()
		probe.wait_time = 2.0
		probe.autostart = true
		probe.timeout.connect(func () -> void:
			print("[FPSProbe] fps=%d chars=%d" % [Engine.get_frames_per_second(), crowd.characters.size()]))
		add_child(probe)


func start_level(n: int) -> void:
	Engine.time_scale = 1.0
	level = n
	current_config = LevelConfig.for_level(n)
	ammo = current_config.ammo
	_shots_used = 0
	state = State.INTRO
	aim.enabled = false
	aim.reset_view()  # new level: recenter behind the intro card

	var data := _generator.generate(current_config)
	current_target_dna = data.target_dna
	crowd.build(data)

	hud.set_level(n)
	hud.set_ammo(ammo, current_config.ammo)
	target_manager.show_target(data.target_dna, current_config.target_memory_time)
	Analytics.log_event("level_start", current_config.to_dict())


func _on_intro_finished() -> void:
	if state != State.INTRO:
		return
	state = State.SEARCHING
	aim.enabled = true
	_search_start_ms = Time.get_ticks_msec()


func _on_shot_fired(pos: Vector2) -> void:
	if state != State.SEARCHING:
		return
	state = State.RESOLVING
	aim.enabled = false
	_shots_used += 1

	_spawn_bullet_hole(pos)
	_screen_flash()
	crowd.react_to_shot(pos)

	var hit := crowd.character_at(pos)
	Analytics.log_event("shot", {"pos": [pos.x, pos.y], "hit": hit != null})

	if hit == crowd.target_character:
		_on_target_hit(hit)
	elif hit != null:
		_on_wrong_hit(hit)
	else:
		_on_empty_shot()


func _on_target_hit(target: CrowdCharacter) -> void:
	var search_ms := Time.get_ticks_msec() - _search_start_ms
	Analytics.log_event("target_found", {"search_time_ms": search_ms})
	Analytics.log_event("level_complete", {"level": level, "shots_used": _shots_used, "search_time_ms": search_ms})

	if OS.has_feature("mobile"):
		Input.vibrate_handheld(60)
	target.flash(Color(1.0, 0.2, 0.15, 0.85))
	hud.show_message("TARGET HIT", Color(1.0, 0.35, 0.25), 1.3)

	# Cinematic slow-motion while the kill is highlighted.
	Engine.time_scale = 0.18
	crowd.dim_all_except(target)
	var fall := create_tween()
	fall.tween_property(target, "rotation", 0.5 * (1 if randf() < 0.5 else -1), 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await _real_time(1.5)
	Engine.time_scale = 1.0
	start_level(level + 1)


func _on_wrong_hit(character: CrowdCharacter) -> void:
	Analytics.log_event("wrong_shot", {"dna": character.dna.to_dict()})
	character.flash(Color(1.0, 0.55, 0.1, 0.8))
	_consume_bullet()
	if ammo > 0:
		hud.show_message("WRONG TARGET", Color(1.0, 0.6, 0.2))
		await _real_time(0.7)
		_resume_search()


func _on_empty_shot() -> void:
	Analytics.log_event("empty_shot", {})
	_consume_bullet()
	if ammo > 0:
		hud.show_message("MISS", Color(0.85, 0.85, 0.9))
		await _real_time(0.6)
		_resume_search()


func _consume_bullet() -> void:
	ammo -= 1
	hud.set_ammo(ammo, current_config.ammo)
	if ammo <= 0:
		_fail_level()


func _fail_level() -> void:
	Analytics.log_event("level_fail", {"level": level, "shots_used": _shots_used})
	hud.show_message("TARGET ESCAPED", Color(0.9, 0.2, 0.2), 1.4)
	crowd.dim_all_except(crowd.target_character)
	crowd.target_character.flash(Color(0.2, 0.9, 0.4, 0.5))
	await _real_time(2.0)
	start_level(level)  # retry the same level number with a fresh crowd


func _resume_search() -> void:
	state = State.SEARCHING
	aim.enabled = true


func _spawn_bullet_hole(pos: Vector2) -> void:
	var hole := BulletHole.new()
	hole.position = pos
	effects.add_child(hole)


func _screen_flash() -> void:
	flash_rect.modulate.a = 0.5
	var tween := create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.12)


## Waits in real time regardless of Engine.time_scale (for slow-mo sequences).
func _real_time(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, true, false, true).timeout
