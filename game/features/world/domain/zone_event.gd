class_name ZoneEvent
extends RefCounted

## A zone event published by the engine and consumed by a rules layer
## (design_docs/engine/active_zones.md §14).
##
## Mirrors `SimulationDayEvent`: a plain value object, no scene references, no
## behaviour. The engine publishes only what it itself does — presence — and
## knows nothing about who listens. Every event carries the address and type of
## its source so a rule can act without reaching into the world or the registry.
##
## `subject_kind` and `subject_id` are the address; `owner_area` is set when the
## source is a point that belongs to an area, so a rule can ask "which room was
## this slot reserved in". `ai_id` and `tags` describe the acting entity; for
## events without one (a flag change) `ai_id` is 0 and `tags` empty.

enum Kind {
	AREA_ENTERED, ## an agent's cell entered a region/room footprint
	AREA_EXITED, ## an agent's cell left a region/room footprint
	SLOT_RESERVED, ## a slot reservation was issued (future)
	SLOT_RELEASED, ## a slot reservation was released (future)
	OWNER_CHANGED, ## a zone's owner tag changed (future)
	ZONE_FLAG_CHANGED, ## a zone flag/counter changed (future)
}

enum SubjectKind { AREA, ANCHOR, ROUTE }

var kind: int
var subject_kind: int = SubjectKind.AREA
var subject_id: StringName = &""
## The area a point source belongs to, when the subject is an anchor. Empty for
## an area source — it is its own owner.
var owner_area: StringName = &""
var ai_id: int = 0
var tags: Array[StringName] = []


func _init(next_kind: int, next_subject_kind: int, next_subject_id: StringName) -> void:
	kind = next_kind
	subject_kind = next_subject_kind
	subject_id = next_subject_id


static func area_entered(area_id: StringName, actor_ai_id: int, actor_tags: Array[StringName] = []) -> ZoneEvent:
	var event := ZoneEvent.new(Kind.AREA_ENTERED, SubjectKind.AREA, area_id)
	event.ai_id = actor_ai_id
	event.tags = actor_tags
	return event


static func area_exited(area_id: StringName, actor_ai_id: int, actor_tags: Array[StringName] = []) -> ZoneEvent:
	var event := ZoneEvent.new(Kind.AREA_EXITED, SubjectKind.AREA, area_id)
	event.ai_id = actor_ai_id
	event.tags = actor_tags
	return event
