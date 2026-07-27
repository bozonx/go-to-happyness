class_name CitizenDailyOrderRuntimePort
extends RefCounted

## Explicit integration boundary for citizen daily order scheduling,
## overtime assignment and workday expiration.

var settlement: SettlementState
var citizens: Array
var day_cycle: SimulationDayCycle
var clock: SimulationClock
var building_registry: Variant
var runtime_seconds_getter: Callable
var is_work_time: Callable
var is_citizen_work_time: Callable
var absolute_game_minutes: Callable
var game_minutes_per_second: float
var citizen_ai_request_decision_refresh: Callable
