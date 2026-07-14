class_name CitizenAISystem
extends Node

## Runtime composition root for the native AI. The catalog grows through complete
## vertical slices; each slice owns its writes.

@export var snapshot_interval := 0.20
@export var director_interval := 1.0
@export var think_interval := 0.25
@export var max_thinks_per_frame := 32

const THINK_PHASE_BUCKETS := 16

var facade: AIWorldFacade
var director := SettlementDirector.new()
var reservations := ReservationLedger.new()
var latest_snapshot: WorldSnapshot
var _goals: Array[AICitizenGoal] = []
var _brains: Dictionary = {}
var _citizen_ids: Array[int] = []
var _next_think_at: Dictionary = {}
var _order_cache: Dictionary = {}
var _order_cache_dirty := true
var _order_cache_expires_at := INF
var _elapsed := 0.0
var _snapshot_elapsed := 0.0
var _director_elapsed := 0.0
var _snapshot_sequence := 0
var _think_cursor := 0


func configure(
	next_facade: AIWorldFacade,
	goals: Array[AICitizenGoal] = [],
	providers: Array[OrderProvider] = []
) -> bool:
	if next_facade == null:
		return false
	var initial_snapshot := next_facade.capture(_snapshot_sequence + 1)
	if initial_snapshot == null:
		return false
	_validate_runtime_configuration()
	facade = next_facade
	_goals = _unique_goals(goals)
	director.configure(_unique_providers(providers))
	_order_cache.clear()
	_order_cache_dirty = true
	_order_cache_expires_at = INF
	for brain: CitizenBrain in _brains.values():
		brain.configure_goals(_goals)
	_snapshot_sequence += 1
	_accept_snapshot(initial_snapshot)
	return true


func register_citizen(citizen_id: int, actuator: CitizenActuator) -> void:
	if (
		citizen_id <= 0
		or actuator == null
		or not actuator.is_valid()
		or actuator.citizen_id != citizen_id
		or _brains.has(citizen_id)
	):
		return
	_brains[citizen_id] = CitizenBrain.new(citizen_id, actuator, _goals)
	_citizen_ids.append(citizen_id)
	_next_think_at[citizen_id] = _elapsed + _think_phase_offset(citizen_id)
	_order_cache_dirty = true


func unregister_citizen(citizen_id: int) -> void:
	var brain := _brains.get(citizen_id) as CitizenBrain
	if brain != null:
		brain.shutdown()
	_brains.erase(citizen_id)
	_citizen_ids.erase(citizen_id)
	_next_think_at.erase(citizen_id)
	_order_cache.erase(citizen_id)
	_order_cache_dirty = true
	director.order_board.remove_citizen(citizen_id)
	reservations.release_all(citizen_id)
	_think_cursor = 0 if _citizen_ids.is_empty() else _think_cursor % _citizen_ids.size()


## Stops a single citizen's current AI task when an external invariant invalidates it.
func cancel_citizen_work(citizen_id: int) -> void:
	var brain := _brains.get(citizen_id) as CitizenBrain
	if brain != null:
		brain.cancel_current_task()
	reservations.release_all(citizen_id)
	director.order_board.remove_citizen(citizen_id)
	_order_cache.erase(citizen_id)
	_order_cache_dirty = true
	request_decision_refresh()


func brain_count() -> int:
	return _brains.size()


func goal_count() -> int:
	return _goals.size()


## Manual role changes must be visible on the next physics tick instead of
## waiting for the periodic director pass.
func request_decision_refresh() -> void:
	if facade == null:
		return
	_snapshot_elapsed = snapshot_interval
	_director_elapsed = director_interval


func _physics_process(delta: float) -> void:
	if facade == null:
		return
	_elapsed += delta
	_snapshot_elapsed += delta
	_director_elapsed += delta
	if latest_snapshot == null or _snapshot_elapsed >= snapshot_interval:
		if not _capture_snapshot():
			facade = null
			return
	if latest_snapshot == null:
		return
	reservations.expire(latest_snapshot.simulation_seconds)
	if _director_elapsed >= director_interval:
		_director_elapsed = fmod(_director_elapsed, director_interval)
		director.tick(latest_snapshot)
		_order_cache_dirty = true
	if _order_cache_dirty or latest_snapshot.simulation_seconds >= _order_cache_expires_at:
		_rebuild_order_cache()
	_tick_brains(delta)
	_think_due_brains()


func _capture_snapshot() -> bool:
	if facade == null:
		return false
	var next_sequence := _snapshot_sequence + 1
	var captured := facade.capture(next_sequence)
	if captured == null:
		return false
	_snapshot_sequence = next_sequence
	_accept_snapshot(captured)
	return true


func _accept_snapshot(captured: WorldSnapshot) -> void:
	latest_snapshot = captured
	# The ledger is persistent, live state; the facade builds a fresh snapshot each
	# cycle, so re-attach the single shared instance instead of a throwaway one.
	latest_snapshot.reservations = reservations
	_snapshot_elapsed = 0.0


func _rebuild_order_cache() -> void:
	# The winning order per citizen is scanned once per frame and shared by both the
	# per-frame behavior tick and the budgeted think pass, instead of twice each.
	_order_cache.clear()
	if latest_snapshot == null:
		return
	for citizen_id in _citizen_ids:
		var order := director.order_board.order_for(citizen_id, latest_snapshot.simulation_seconds)
		if order != null:
			_order_cache[citizen_id] = order
	_order_cache_expires_at = director.order_board.next_expiration_after(latest_snapshot.simulation_seconds)
	_order_cache_dirty = false


func _tick_brains(delta: float) -> void:
	if latest_snapshot == null:
		return
	for citizen_id in _citizen_ids:
		var brain := _brains.get(citizen_id) as CitizenBrain
		if brain == null:
			continue
		brain.tick(latest_snapshot, _order_cache.get(citizen_id), delta)


func _think_due_brains() -> void:
	if latest_snapshot == null or _citizen_ids.is_empty():
		return
	var inspected := 0
	var processed := 0
	while inspected < _citizen_ids.size() and processed < max_thinks_per_frame:
		if _think_cursor >= _citizen_ids.size():
			_think_cursor = 0
		var citizen_id := _citizen_ids[_think_cursor]
		_think_cursor += 1
		inspected += 1
		if _elapsed < float(_next_think_at.get(citizen_id, 0.0)):
			continue
		_next_think_at[citizen_id] = _elapsed + think_interval
		var brain := _brains.get(citizen_id) as CitizenBrain
		if brain != null:
			brain.think(latest_snapshot, _order_cache.get(citizen_id))
			processed += 1


func _validate_runtime_configuration() -> void:
	snapshot_interval = maxf(snapshot_interval, 0.001)
	director_interval = maxf(director_interval, 0.001)
	think_interval = maxf(think_interval, 0.001)
	max_thinks_per_frame = maxi(max_thinks_per_frame, 0)


func _think_phase_offset(citizen_id: int) -> float:
	var bucket := posmod(citizen_id, THINK_PHASE_BUCKETS)
	return think_interval * float(bucket) / float(THINK_PHASE_BUCKETS)


func _unique_goals(goals: Array[AICitizenGoal]) -> Array[AICitizenGoal]:
	var result: Array[AICitizenGoal] = []
	var ids: Dictionary = {}
	for goal in goals:
		if goal == null or goal.id.is_empty() or ids.has(goal.id):
			push_error("AI goal ids must be non-empty and unique")
			continue
		ids[goal.id] = true
		result.append(goal)
	return result


func _unique_providers(providers: Array[OrderProvider]) -> Array[OrderProvider]:
	var result: Array[OrderProvider] = []
	var ids: Dictionary = {}
	for provider in providers:
		if provider == null or provider.id.is_empty() or ids.has(provider.id):
			push_error("Order provider ids must be non-empty and unique")
			continue
		ids[provider.id] = true
		result.append(provider)
	return result
