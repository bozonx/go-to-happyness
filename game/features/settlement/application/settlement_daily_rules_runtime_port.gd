class_name SettlementDailyRulesRuntimePort
extends RefCounted

## Explicit integration boundary for the daily settlement update.

var settlement: SettlementState
var day_cycle: SimulationDayCycle
var citizens: Array
var trail_field: TrailFieldService
var event_service_getter: Callable
var citizen_needs_service: CitizenNeedsService
var canteen_getter: Callable
## Returns the current EnvironmentSnapshot; daily cold pressure is numeric.
var environment_getter: Callable
var add_message: Callable
var update_interface: Callable
var apply_building_wear_and_repairs: Callable
var decay_resource_piles: Callable
var total_housing_slots: Callable
var check_daily_departures: Callable
var stored_resources: Callable
var warehouse_capacity: Callable
