class_name LevelGenerator
extends RefCounted
## Builds a full level (target DNA, decoy DNAs, filler DNAs, spawn positions)
## from a LevelConfig. Deterministic per seed for reproducible levels.

const PLAY_AREA := Rect2(90, 430, 900, 1290)


class LevelData:
	var config: LevelConfig
	var target_dna: CharacterDNA
	var crowd_dnas: Array[CharacterDNA] = []  # includes the target
	var target_index: int = -1
	var positions: Array[Vector2] = []


var _rng := RandomNumberGenerator.new()


func generate(config: LevelConfig, level_seed: int = -1) -> LevelData:
	if level_seed >= 0:
		_rng.seed = level_seed
	else:
		_rng.randomize()

	var data := LevelData.new()
	data.config = config

	var active_traits := _active_traits(config.target_trait_count)
	var base := CharacterDNA.random_dna(_rng)  # inactive traits: uniform crowd look

	data.target_dna = _variant_of(base, active_traits, 1.0)
	var dnas: Array[CharacterDNA] = []

	var decoy_count := mini(config.decoy_count, config.crowd_count - 1)
	for i in decoy_count:
		dnas.append(_make_decoy(data.target_dna, active_traits, config.decoy_diff_traits))

	var filler_count := config.crowd_count - 1 - decoy_count
	for i in filler_count:
		dnas.append(_make_filler(data.target_dna, base, active_traits, config.similarity))

	# Insert the target at a random position in the crowd list.
	data.target_index = _rng.randi_range(0, dnas.size())
	dnas.insert(data.target_index, data.target_dna)
	data.crowd_dnas = dnas

	data.positions = _spread_positions(config.crowd_count, config.spacing * config.character_scale)
	return data


func _active_traits(count: int) -> Array[String]:
	var names := CharacterDNA.trait_names()
	var active: Array[String] = []
	for i in mini(count, names.size()):
		active.append(names[i])
	return active


## Copy of `base` with the given traits re-rolled (randomize_chance per trait).
func _variant_of(base: CharacterDNA, traits: Array[String], randomize_chance: float) -> CharacterDNA:
	var dna := base.clone()
	for trait_name in traits:
		if _rng.randf() < randomize_chance:
			dna.set_trait(trait_name, CharacterDNA.random_trait_value(trait_name, _rng))
	return dna


## Decoy: matches the target except in exactly `diff_count` active traits.
func _make_decoy(target: CharacterDNA, active: Array[String], diff_count: int) -> CharacterDNA:
	var dna := target.clone()
	var pool := active.duplicate()
	pool.shuffle()
	var changed := 0
	for trait_name in pool:
		if changed >= maxi(1, diff_count):
			break
		var old_value: Variant = dna.get_trait(trait_name)
		for attempt in 8:
			var new_value: Variant = CharacterDNA.random_trait_value(trait_name, _rng)
			if new_value != old_value:
				dna.set_trait(trait_name, new_value)
				changed += 1
				break
	return dna


## Filler: per active trait, copies the target with probability `similarity`,
## otherwise rolls randomly. Never an exact match of the target.
func _make_filler(target: CharacterDNA, base: CharacterDNA, active: Array[String], similarity: float) -> CharacterDNA:
	for attempt in 16:
		var dna := base.clone()
		for trait_name in active:
			if _rng.randf() < similarity:
				dna.set_trait(trait_name, target.get_trait(trait_name))
			else:
				dna.set_trait(trait_name, CharacterDNA.random_trait_value(trait_name, _rng))
		if not dna.equals(target, active):
			return dna
	# Fallback: force one trait to differ.
	var fallback := target.clone()
	var trait_name: String = active[_rng.randi_range(0, active.size() - 1)]
	for attempt in 8:
		var new_value: Variant = CharacterDNA.random_trait_value(trait_name, _rng)
		if new_value != target.get_trait(trait_name):
			fallback.set_trait(trait_name, new_value)
			break
	return fallback


## Jittered-grid placement: guarantees spread coverage with bounded overlap,
## no physics needed. Cells are shuffled so density looks organic.
func _spread_positions(count: int, min_spacing: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var cols := maxi(1, int(PLAY_AREA.size.x / min_spacing))
	var rows := maxi(1, int(PLAY_AREA.size.y / min_spacing))
	while cols * rows < count:
		if cols <= rows: cols += 1
		else: rows += 1
	var cell := Vector2(PLAY_AREA.size.x / cols, PLAY_AREA.size.y / rows)

	var cells: Array[Vector2i] = []
	for cy in rows:
		for cx in cols:
			cells.append(Vector2i(cx, cy))
	cells.shuffle()

	var jitter := cell * 0.3
	for i in count:
		var c := cells[i]
		var center := PLAY_AREA.position + Vector2((c.x + 0.5) * cell.x, (c.y + 0.5) * cell.y)
		center += Vector2(_rng.randf_range(-jitter.x, jitter.x), _rng.randf_range(-jitter.y, jitter.y))
		positions.append(center)
	return positions
