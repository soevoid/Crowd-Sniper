class_name LevelConfig
extends Resource
## Pure-data difficulty model. Every gameplay parameter of a level is a number
## here, so a designer (or an analytics-driven tuner) can reshape difficulty
## without touching generator or gameplay code.

@export var level: int = 1
@export var crowd_count: int = 8
## How many DNA traits vary across the crowd (traits are enabled in
## CharacterDNA.TRAIT_SPACE order; inactive traits are uniform for everyone).
@export var target_trait_count: int = 2
## 0..1 — how much filler characters resemble the target on average.
@export var similarity: float = 0.2
## Decoys differ from the target in exactly `decoy_diff_traits` active traits.
@export var decoy_count: int = 0
@export var decoy_diff_traits: int = 1
## Idle wander amplitude in px (0 = static crowd).
@export var movement_speed: float = 0.0
@export var character_scale: float = 1.0
## Minimum distance between characters in px (at scale 1).
@export var spacing: float = 150.0
@export var ammo: int = 3
## 0 = no time limit (reserved for later levels).
@export var time_limit: float = 0.0
## Seconds the target is shown fullscreen before the hunt starts.
@export var target_memory_time: float = 1.5


## Hand-tuned configs for the first five levels (data presets, not code paths),
## then a smooth mathematical curve for endless procedural levels.
static func for_level(n: int) -> LevelConfig:
	var c := LevelConfig.new()
	c.level = n
	match n:
		1:  # Very easy, obvious target.
			c.crowd_count = 8
			c.target_trait_count = 2
			c.similarity = 0.2
			c.decoy_count = 0
			c.movement_speed = 0.0
		2:  # More people.
			c.crowd_count = 12
			c.target_trait_count = 2
			c.similarity = 0.25
			c.decoy_count = 0
		3:  # Two target traits must be matched to be sure.
			c.crowd_count = 13
			c.target_trait_count = 3
			c.similarity = 0.3
			c.decoy_count = 0
		4:  # Introduce similar decoys.
			c.crowd_count = 15
			c.target_trait_count = 3
			c.similarity = 0.35
			c.decoy_count = 2
		5:  # Dense crowd, several near-identical characters.
			c.crowd_count = 18
			c.target_trait_count = 4
			c.similarity = 0.45
			c.decoy_count = 3
		_:
			c.crowd_count = mini(40, int(7.0 + 1.4 * n))
			c.target_trait_count = mini(CharacterDNA.TRAIT_SPACE.size(), 3 + int(n / 4.0))
			c.similarity = minf(0.72, 0.25 + 0.022 * n)
			c.decoy_count = mini(6, 1 + int(n / 4.0))
			c.movement_speed = 0.0 if n < 6 else minf(46.0, 6.0 + (n - 6) * 2.5)
	c.character_scale = clampf(1.05 - 0.012 * n, 0.72, 1.0)
	c.spacing = clampf(170.0 - 2.5 * n, 118.0, 170.0)
	c.target_memory_time = clampf(1.6 - 0.015 * n, 1.0, 1.6)
	c.ammo = 3
	return c


func to_dict() -> Dictionary:
	return {
		"level": level,
		"crowd_count": crowd_count,
		"target_trait_count": target_trait_count,
		"similarity": similarity,
		"decoy_count": decoy_count,
		"movement_speed": movement_speed,
		"character_scale": character_scale,
		"spacing": spacing,
		"ammo": ammo,
		"time_limit": time_limit,
		"target_memory_time": target_memory_time,
	}
