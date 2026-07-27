class_name SettlementSurvivalRuntimePort
extends RefCounted

## Explicit integration boundary for hourly settlement survival rules.

var settlement: SettlementState
var day_cycle: SimulationDayCycle
var clock: SimulationClock
var citizens: Array
var random: RandomNumberGenerator
var weather_state: Variant
var building_registry: BuildingRegistry
var fire_management_service: FireManagementService
var tent_weather_getter: Callable
var entrance_stone_getter: Callable
var event_service_getter: Callable
var has_lit_communal_fire: Callable
var add_message: Callable
var is_citizen_work_time: Callable
var is_work_time: Callable
