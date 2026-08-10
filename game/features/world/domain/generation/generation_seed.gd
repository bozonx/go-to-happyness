class_name GenerationSeed
extends RefCounted

## Per-stage randomness streams (procedural_map_generation.md §4.1).
##
## Every stage draws from its OWN generator, derived by a stable hash of
## `(seed, stage_id)`. That is the whole of the determinism contract: adding the
## lake stage must not move the coastline, and reordering two draws inside one
## stage must not reshape another. Global `randf()` is banned in
## `domain/generation` for exactly this reason — it couples every stage to every
## other through a single hidden cursor.

var base_seed := 0


func _init(next_seed: int = 0) -> void:
	base_seed = next_seed


## Stable across runs and machines: Godot's String hash is part of the engine's
## data format, not a per-process value like `Object.get_instance_id`.
func stream_seed(stage_id: StringName) -> int:
	return int(hash("gdmapgen/%d/%s" % [base_seed, stage_id]))


func rng(stage_id: StringName) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = stream_seed(stage_id)
	return generator


## fBm noise for a stage. The parameters are internals of a stage, never recipe
## fields — §3.1 keeps `octaves` and `lacunarity` out of the author's vocabulary.
func noise(stage_id: StringName, frequency: float, octaves: int = 4, gain: float = 0.5) -> FastNoiseLite:
	var field := FastNoiseLite.new()
	field.seed = stream_seed(stage_id)
	field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field.frequency = frequency
	field.fractal_type = FastNoiseLite.FRACTAL_FBM
	field.fractal_octaves = maxi(1, octaves)
	field.fractal_gain = gain
	field.fractal_lacunarity = 2.0
	return field


## A derived seed for retrying a structurally broken world (§6). Scalar target
## misses are corrected on the original seed and never call this function.
func derive(attempt: int) -> GenerationSeed:
	return GenerationSeed.new(int(hash("gdmapgen/retry/%d/%d" % [base_seed, attempt])))
