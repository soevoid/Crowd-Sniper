class_name CharacterDNA
extends RefCounted
## Structured trait data for one procedural character.
## Traits are stored as palette/style indices so they serialize cleanly
## and can be compared, mutated, and rendered without any art assets.

const HAIR_STYLES: Array[String] = ["bald", "short", "long", "bun", "mohawk"]
const HAIR_COLORS: Array[String] = ["black", "brown", "blonde", "red", "gray"]
const SKIN_TONES: Array[String] = ["light", "tan", "brown", "dark"]
const SHIRT_STYLES: Array[String] = ["tshirt", "jacket", "hoodie"]
const SHIRT_COLORS: Array[String] = ["blue", "red", "green", "yellow", "purple", "white"]
const PANTS_COLORS: Array[String] = ["gray", "navy", "brown", "black", "beige"]
const ACCESSORIES: Array[String] = ["none", "bag", "scarf"]

const HAIR_COLOR_VALUES := {
	"black": Color(0.12, 0.1, 0.1), "brown": Color(0.4, 0.26, 0.13),
	"blonde": Color(0.9, 0.78, 0.42), "red": Color(0.72, 0.25, 0.12),
	"gray": Color(0.75, 0.75, 0.75),
}
const SKIN_TONE_VALUES := {
	"light": Color(0.98, 0.85, 0.73), "tan": Color(0.9, 0.71, 0.53),
	"brown": Color(0.68, 0.47, 0.32), "dark": Color(0.45, 0.3, 0.2),
}
const SHIRT_COLOR_VALUES := {
	"blue": Color(0.25, 0.45, 0.85), "red": Color(0.85, 0.25, 0.25),
	"green": Color(0.28, 0.65, 0.35), "yellow": Color(0.92, 0.78, 0.25),
	"purple": Color(0.6, 0.35, 0.75), "white": Color(0.92, 0.92, 0.92),
}
const PANTS_COLOR_VALUES := {
	"gray": Color(0.5, 0.5, 0.55), "navy": Color(0.18, 0.22, 0.4),
	"brown": Color(0.45, 0.33, 0.22), "black": Color(0.15, 0.15, 0.17),
	"beige": Color(0.82, 0.75, 0.6),
}

## Trait registry: name -> number of possible values. Bool traits have 2.
## Order matters: LevelConfig.active_trait_count enables traits from the front,
## so early levels only vary the most visually readable traits.
const TRAIT_SPACE := [
	["shirt_color", 6],
	["hair_color", 5],
	["hat", 2],
	["glasses", 2],
	["hair_style", 5],
	["shirt_style", 3],
	["pants_color", 5],
	["skin_tone", 4],
	["accessory", 3],
]

var hair_style: String = "short"
var hair_color: String = "black"
var skin_tone: String = "light"
var shirt_style: String = "tshirt"
var shirt_color: String = "blue"
var pants_color: String = "gray"
var accessory: String = "none"
var glasses: bool = false
var hat: bool = false


static func trait_names() -> Array[String]:
	var names: Array[String] = []
	for entry in TRAIT_SPACE:
		names.append(entry[0])
	return names


static func random_trait_value(trait_name: String, rng: RandomNumberGenerator) -> Variant:
	match trait_name:
		"hair_style": return HAIR_STYLES[rng.randi_range(0, HAIR_STYLES.size() - 1)]
		"hair_color": return HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
		"skin_tone": return SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
		"shirt_style": return SHIRT_STYLES[rng.randi_range(0, SHIRT_STYLES.size() - 1)]
		"shirt_color": return SHIRT_COLORS[rng.randi_range(0, SHIRT_COLORS.size() - 1)]
		"pants_color": return PANTS_COLORS[rng.randi_range(0, PANTS_COLORS.size() - 1)]
		"accessory": return ACCESSORIES[rng.randi_range(0, ACCESSORIES.size() - 1)]
		"glasses": return rng.randf() < 0.35
		"hat": return rng.randf() < 0.3
	return null


static func random_dna(rng: RandomNumberGenerator) -> CharacterDNA:
	var dna := CharacterDNA.new()
	for trait_name in trait_names():
		dna.set_trait(trait_name, random_trait_value(trait_name, rng))
	return dna


func set_trait(trait_name: String, value: Variant) -> void:
	set(trait_name, value)


func get_trait(trait_name: String) -> Variant:
	return get(trait_name)


func clone() -> CharacterDNA:
	var copy := CharacterDNA.new()
	for trait_name in trait_names():
		copy.set_trait(trait_name, get_trait(trait_name))
	return copy


func equals(other: CharacterDNA, traits: Array[String]) -> bool:
	for trait_name in traits:
		if get_trait(trait_name) != other.get_trait(trait_name):
			return false
	return true


## Number of listed traits with identical values (used for similarity checks).
func shared_trait_count(other: CharacterDNA, traits: Array[String]) -> int:
	var count := 0
	for trait_name in traits:
		if get_trait(trait_name) == other.get_trait(trait_name):
			count += 1
	return count


func to_dict() -> Dictionary:
	var out := {}
	for trait_name in trait_names():
		out[trait_name] = get_trait(trait_name)
	return out
