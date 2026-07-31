class_name ProgressionPolicy
extends RefCounted

## How a map uses the progression its game declares. Progression itself is a host
## feature (eras live in `GameDefinition.progression`), so a pack never has to
## ship code to get it — it opts in, narrows it, pins it, or turns it off.
##
## The policy is authored in `map.json` under `start.progression` and is not
## namespaced by a module: whoever consumes eras reads the resolved
## `SessionProgression`, and the host resolves it once per session.

## Every era the game declares is available.
const MODE_INHERIT: StringName = &"inherit"
## Only `allowed_eras` are available.
const MODE_RESTRICTED: StringName = &"restricted"
## Exactly `default_era` is available and cannot be changed.
const MODE_FIXED: StringName = &"fixed"
## No progression at all: everything the game declares is treated as reached.
const MODE_DISABLED: StringName = &"disabled"

const MODES: Array[StringName] = [MODE_INHERIT, MODE_RESTRICTED, MODE_FIXED, MODE_DISABLED]

var mode: StringName = MODE_INHERIT
var allowed_eras: Array[StringName] = []
var default_era: StringName = &""


static func from_dict(source: Variant) -> ProgressionPolicy:
	var policy := ProgressionPolicy.new()
	if not source is Dictionary:
		return policy
	var data := source as Dictionary
	policy.mode = StringName(data.get("mode", policy.mode))
	for raw: Variant in data.get("allowed_eras", []):
		policy.allowed_eras.append(StringName(raw))
	policy.default_era = StringName(data.get("default_era", ""))
	return policy


func to_dict() -> Dictionary:
	return {
		"mode": String(mode),
		"allowed_eras": allowed_eras.map(func(era: StringName) -> String: return String(era)),
		"default_era": String(default_era),
	}


func is_default() -> bool:
	return mode == MODE_INHERIT and allowed_eras.is_empty() and default_era.is_empty()


## Checks the policy against the eras its game actually declares. Returning the
## errors instead of clamping is deliberate: a map that names an era its game
## dropped is an authoring mistake, and silently starting somewhere else hides it.
func validate(known_eras: Array[StringName]) -> Array[String]:
	var errors: Array[String] = []
	if mode not in MODES:
		errors.append("неизвестный режим прогрессии %s" % mode)
	# A game that declares no eras simply does not use progression, and a map may
	# legitimately be playable by both such a game and one that does. Reporting the
	# map's policy against an empty catalogue would forbid exactly that.
	if known_eras.is_empty():
		return errors
	for era_id: StringName in allowed_eras:
		if era_id not in known_eras:
			errors.append("карта разрешает неизвестную эру %s" % era_id)
	if mode == MODE_RESTRICTED and allowed_eras.is_empty():
		errors.append("режим restricted требует allowed_eras")
	if mode == MODE_FIXED and default_era.is_empty():
		errors.append("режим fixed требует default_era")
	if not default_era.is_empty() and default_era not in known_eras:
		errors.append("неизвестная стартовая эра %s" % default_era)
	if not default_era.is_empty() and not allowed_eras.is_empty() and default_era not in allowed_eras:
		errors.append("стартовая эра %s не входит в allowed_eras" % default_era)
	return errors
