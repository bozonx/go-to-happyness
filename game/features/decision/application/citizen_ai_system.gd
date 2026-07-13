class_name CitizenAISystem
extends Node

## Runtime composition root for the native AI. It is live from phase one, while
## its goal catalog and order providers intentionally remain empty.

@export var snapshot_interval := 0.20
@export var director_interval := 1.0
@export var think_interval := 0.25
@export var max_thinks_per_frame := 32

var facade: AIWorldFacade
var director := SettlementDirector.new()
var latest_snapshot: WorldSnapshot
var _goals: Array[AICitizenGoal] = []
var _brains: Dictionary = {}
var _citizen_ids: Array[int] = []
var _next_think_at: Dictionary = {}
var _elapsed := 0.0
var _snapshot_elapsed := 0.0
var _director_elapsed := 0.0
var _snapshot_sequence := 0
var _think_cursor := 0


func configure(
	next_facade: AIWorldFacade,
	goals: Array[AICitizenGoal] = [],
	providers: Array[OrderProvider] = []
) -> void:
	facade = next_facade
	_goals = goals.duplicate()
	director.configure(providers)
	_capture_snapshot()


func register_citizen(citizen_id: int, actuator: CitizenActuator) -> void:
	if citizen_id == 0 or actuator == null or _brains.has(citizen_id):
		return
	_brains[citizen_id] = CitizenBrain.new(citizen_id, actuator, _goals)
	_citizen_ids.append(citizen_id)
	_next_think_at[citizen_id] = _elapsed


func unregister_citizen(citizen_id: int) -> void:
	var brain := _brains.get(citizen_id) as CitizenBrain
	if brain != null:
		brain.shutdown()
	_brains.erase(citizen_id)
	_citizen_ids.erase(citizen_id)
	_next_think_at.erase(citizen_id)
	director.order_board.remove_citizen(citizen_id)
	_think_cursor = 0 if _citizen_ids.is_empty() else _think_cursor % _citizen_ids.size()


func brain_count() -> int:
	return _brains.size()


func goal_count() -> int:
	return _goals.size()


func _physics_process(delta: float) -> void:
	if facade == null:
		return
	_elapsed += delta
	_snapshot_elapsed += delta
	_director_elapsed += delta
	if latest_snapshot == null or _snapshot_elapsed >= snapshot_interval:
		_capture_snapshot()
	if _director_elapsed >= director_interval:
		_director_elapsed = fmod(_director_elapsed, director_interval)
		director.tick(latest_snapshot)
	_tick_brains(delta)
	_think_due_brains()


func _capture_snapshot() -> void:
	if facade == null:
		return
	_snapshot_sequence += 1
	latest_snapshot = facade.capture(_snapshot_sequence)
	_snapshot_elapsed = 0.0


func _tick_brains(delta: float) -> void:
	if latest_snapshot == null:
		return
	for citizen_id in _citizen_ids:
		var brain := _brains.get(citizen_id) as CitizenBrain
		if brain == null:
			continue
		brain.tick(
			latest_snapshot,
			director.order_board.order_for(citizen_id, latest_snapshot.simulation_seconds),
			delta
		)


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
			brain.think(
				latest_snapshot,
				director.order_board.order_for(citizen_id, latest_snapshot.simulation_seconds)
			)
			processed += 1
