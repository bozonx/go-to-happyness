class_name ReservationLedger
extends RefCounted

## Shared claim store for contested content: a tree, a workbench slot, a unit of
## cargo. Directors allocate work globally, but two citizens can still race for the
## same physical target at the leaf level; a claim makes that arbitration explicit.
##
## Claims are keyed by an opaque resource key (StringName tag, entity id, Vector3,
## …) and carry a time-to-live so a crashed or abandoned task never wedges a target
## forever. The ledger is the single mutable seam the otherwise-immutable snapshot
## deliberately shares, because reservations are live cross-citizen state.

class _Claim extends RefCounted:
	var citizen_id: int
	var expires_at: float

	func _init(next_citizen_id: int, next_expires_at: float) -> void:
		citizen_id = next_citizen_id
		expires_at = next_expires_at


var _claims: Dictionary = {}


## Attempts to reserve `key` for `citizen_id`. Succeeds when the key is free, held
## by nobody live, or already held by the same citizen (re-affirming extends it).
func claim(
	key: Variant,
	citizen_id: int,
	simulation_seconds: float,
	ttl: float = 5.0
) -> bool:
	if citizen_id == 0:
		return false
	var existing := _live_claim(key, simulation_seconds)
	if existing != null and existing.citizen_id != citizen_id:
		return false
	_claims[key] = _Claim.new(citizen_id, simulation_seconds + maxf(0.0, ttl))
	return true


## Releases `key` only if `citizen_id` currently owns it, so a late release from a
## preempted task cannot free a target a different citizen has since claimed.
func release(key: Variant, citizen_id: int) -> void:
	var claim_data := _claims.get(key) as _Claim
	if claim_data != null and claim_data.citizen_id == citizen_id:
		_claims.erase(key)


func release_all(citizen_id: int) -> void:
	for key: Variant in _claims.keys():
		var claim_data := _claims[key] as _Claim
		if claim_data.citizen_id == citizen_id:
			_claims.erase(key)


func owner_of(key: Variant, simulation_seconds: float) -> int:
	var claim_data := _live_claim(key, simulation_seconds)
	return claim_data.citizen_id if claim_data != null else 0


## True when `citizen_id` may act on `key`: either it is free or already theirs.
func is_available_for(key: Variant, citizen_id: int, simulation_seconds: float) -> bool:
	var owner := owner_of(key, simulation_seconds)
	return owner == 0 or owner == citizen_id


func expire(simulation_seconds: float) -> void:
	for key: Variant in _claims.keys():
		if (_claims[key] as _Claim).expires_at <= simulation_seconds:
			_claims.erase(key)


func active_count() -> int:
	return _claims.size()


func _live_claim(key: Variant, simulation_seconds: float) -> _Claim:
	var claim_data := _claims.get(key) as _Claim
	if claim_data == null or claim_data.expires_at <= simulation_seconds:
		return null
	return claim_data
