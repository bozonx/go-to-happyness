class_name SessionProgression
extends RefCounted

## Progression resolved for one session: which eras this game offers, which of
## them this map allows, and where the session starts.
##
## This is the host's answer to "packs contain no code": eras are engine
## functionality, authored as data in a game definition and narrowed by a map
## policy. A game that declares no eras gets an empty progression, and every
## consumer — menu, module, save — reads the same resolved record.

var enabled := true
## Eras the session may reach, in the order the game declared them.
var era_ids: Array[StringName] = []
## Where the session starts. Empty only when the game declares no eras at all.
var current_era: StringName = &""

var _definition: GameProgressionDefinition = null


static func resolve(
	definition: GameProgressionDefinition,
	policy: ProgressionPolicy,
	selected_era: StringName = &"",
) -> SessionProgression:
	var progression := SessionProgression.new()
	progression._definition = definition if definition != null else GameProgressionDefinition.new()
	var declared := progression._definition.era_ids()
	if declared.is_empty():
		return progression
	var effective := policy if policy != null else ProgressionPolicy.new()
	match effective.mode:
		ProgressionPolicy.MODE_DISABLED:
			# No progression means nothing is locked: the session starts at the most
			# advanced era the game declares rather than at a made-up "no era".
			progression.enabled = false
			progression.era_ids = declared
			progression.current_era = declared[-1]
			return progression
		ProgressionPolicy.MODE_FIXED:
			if effective.default_era.is_empty():
				progression.era_ids = declared
			else:
				progression.era_ids.append(effective.default_era)
		ProgressionPolicy.MODE_RESTRICTED:
			for era_id: StringName in declared:
				if era_id in effective.allowed_eras:
					progression.era_ids.append(era_id)
			if progression.era_ids.is_empty():
				progression.era_ids = declared
		_:
			progression.era_ids = declared
	# The player's pick wins, but only inside the policy. A pick the map does not
	# allow falls back to the map's own default before the first allowed era, so a
	# stale menu selection cannot silently reset an authored start.
	progression.current_era = progression._first_allowed(
		[selected_era, effective.default_era, progression.era_ids[0]])
	return progression


func _first_allowed(candidates: Array[StringName]) -> StringName:
	for candidate: StringName in candidates:
		if not candidate.is_empty() and candidate in era_ids:
			return candidate
	return era_ids[0] if not era_ids.is_empty() else &""


func is_empty() -> bool:
	return era_ids.is_empty()


## Whether the player may pick the starting era. A single allowed era is not a
## choice, and neither is a disabled progression.
func is_selectable() -> bool:
	return enabled and era_ids.size() > 1


## Position of an era in the game's declared order. This is the only number a
## module should key its own stage enum on; -1 means the game does not know it.
func rank_of(era_id: StringName) -> int:
	return _definition.rank_of(era_id) if _definition != null else -1


## Ranks of every allowed era, for modules that gate content by stage.
func allowed_ranks() -> Array[int]:
	var ranks: Array[int] = []
	for era_id: StringName in era_ids:
		var rank := rank_of(era_id)
		if rank >= 0:
			ranks.append(rank)
	return ranks


func current_rank() -> int:
	return maxi(0, rank_of(current_era))


func era(era_id: StringName) -> EraDefinition:
	return _definition.era_by_id(era_id) if _definition != null else null


func display_names() -> Dictionary:
	var names: Dictionary = {}
	if _definition == null:
		return names
	for era_definition: EraDefinition in _definition.eras:
		names[era_definition.id] = era_definition.display_name()
	return names
