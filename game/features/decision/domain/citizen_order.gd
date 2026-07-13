class_name CitizenOrder
extends RefCounted

## A director-issued assignment. The kind and payload describe what should be
## done; a Goal decides whether and when the citizen should act on it.

var id: int
var citizen_id: int
var kind: StringName
var issuer: StringName
var priority: float
var target_entity_id: int
var target_position: Vector3
var payload: AIFactSet
var issued_at: float
var expires_at: float


func _init(
	next_citizen_id: int = 0,
	next_kind: StringName = &"",
	next_issuer: StringName = &"",
	next_priority: float = 0.0,
	next_payload: AIFactSet = null
) -> void:
	citizen_id = next_citizen_id
	kind = next_kind
	issuer = next_issuer
	priority = next_priority
	target_entity_id = -1
	target_position = Vector3.INF
	payload = next_payload if next_payload != null else AIFactSet.new()
	issued_at = 0.0
	expires_at = -1.0


func is_expired(simulation_seconds: float) -> bool:
	return expires_at >= 0.0 and simulation_seconds >= expires_at
