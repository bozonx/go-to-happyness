class_name ZoneEffects
extends RefCounted

## Effects section of an overlay area (design_docs/engine/active_zones.md §4.2).
##
## An effect is a correction to something **the engine already computes**: the
## weight of a cell in NavGrid and the line of sight. Nothing else may become an
## effect — damage, money, score, reputation and temperature are rules subscribed
## to `area_entered`, not fields here. Without that line the list starts growing
## by one entry per genre, which is exactly the mistake the previous zone model
## was rebuilt to undo.

## Movement cost multiplier for the cells of the overlay: forest, mud, a ford,
## rubble. 1.0 is "no change"; below 1.0 is a road-like speedup.
const KEY_COST := &"cost"
## How much of the line of sight the overlay cuts, 0…1. 1.0 is a full block
## (smoke, a dense canopy); a fraction is haze.
const KEY_VISION := &"vision"
## How well someone standing inside is hidden, 0…1: bushes, tall grass, shadow.
const KEY_CONCEAL := &"conceal"

const KEYS: Array[StringName] = [KEY_COST, KEY_VISION, KEY_CONCEAL]

const DEFAULTS: Dictionary = {
	KEY_COST: 1.0,
	KEY_VISION: 0.0,
	KEY_CONCEAL: 0.0,
}

## Bounds used by both the validator and the inspector, so a slider and a
## hand-written file cannot disagree about what is allowed.
const RANGES: Dictionary = {
	KEY_COST: Vector2(0.1, 10.0),
	KEY_VISION: Vector2(0.0, 1.0),
	KEY_CONCEAL: Vector2(0.0, 1.0),
}


static func is_known(key: StringName) -> bool:
	return key in KEYS


static func default_of(key: StringName) -> float:
	return float(DEFAULTS.get(key, 0.0))


## True when the value equals the default, i.e. the effect does nothing and has
## no business being written to the file.
static func is_neutral(key: StringName, value: float) -> bool:
	return is_equal_approx(value, default_of(key))


static func clamp_value(key: StringName, value: float) -> float:
	var range_of: Vector2 = RANGES.get(key, Vector2(0.0, 1.0))
	return clampf(value, range_of.x, range_of.y)


## Combines the effects of every overlay covering one cell. Cost multiplies,
## vision and conceal take the strongest — associative and order-free, which is
## what invariant §7.10 demands: the order of records in a file must not matter.
static func combine(effect_dicts: Array) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for raw in effect_dicts:
		if not (raw is Dictionary):
			continue
		var effects: Dictionary = raw
		if effects.has(KEY_COST):
			result[KEY_COST] = float(result[KEY_COST]) * float(effects[KEY_COST])
		if effects.has(KEY_VISION):
			result[KEY_VISION] = maxf(float(result[KEY_VISION]), float(effects[KEY_VISION]))
		if effects.has(KEY_CONCEAL):
			result[KEY_CONCEAL] = maxf(float(result[KEY_CONCEAL]), float(effects[KEY_CONCEAL]))
	return result


static func blocks_vision(effects: Dictionary) -> bool:
	return float(effects.get(KEY_VISION, 0.0)) >= 1.0


## Parses the JSON section, dropping unknown keys and clamping values. Unknown
## keys are reported by the validator rather than kept: a typo that silently
## survives into the file is a bug the author cannot see.
static func parse(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (raw is Dictionary):
		return result
	for raw_key in (raw as Dictionary):
		var key := StringName(raw_key)
		if is_known(key):
			result[key] = clamp_value(key, float((raw as Dictionary)[raw_key]))
		else:
			# Keep the spelling long enough for blueprint validation to reject it.
			# Serialization never writes unknown keys.
			result[key] = (raw as Dictionary)[raw_key]
	return result


static func unknown_keys(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Dictionary:
		for key in (raw as Dictionary):
			if not is_known(StringName(key)):
				result.append(String(key))
	return result


static func to_json(effects: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in KEYS:
		if effects.has(key) and not is_neutral(key, float(effects[key])):
			result[String(key)] = float(effects[key])
	return result


static func display_name(key: StringName) -> String:
	match key:
		KEY_COST: return "Цена прохода"
		KEY_VISION: return "Перекрывает обзор"
		KEY_CONCEAL: return "Скрывает"
		_: return String(key)


static func hint_of(key: StringName) -> String:
	match key:
		KEY_COST: return "Множитель веса клетки: лес, грязь, брод, завалы."
		KEY_VISION: return "Сколько обзора срезано, 1.0 — насквозь не видно."
		KEY_CONCEAL: return "Насколько скрыт тот, кто внутри."
		_: return ""
