class_name OutsideWorkRuntimePort
extends RefCounted

## Narrow runtime contract for settlement-scale outside-work orders.

var settlement: SettlementState
var random: RandomNumberGenerator
var outside_workers: Dictionary
var last_citizen_positions: Dictionary
var selected_builder_getter: Callable
var is_work_time: Callable
var update_interface: Callable
var courier_dispatcher_getter: Callable
var entrance_getter: Callable
var request_courier_dispatch: Callable
var absolute_game_minutes: Callable
var current_day_getter: Callable
var refresh_ai: Callable


func _init(
	p_settlement: SettlementState,
	p_random: RandomNumberGenerator,
	p_outside_workers: Dictionary,
	p_last_citizen_positions: Dictionary,
	p_selected_builder_getter: Callable,
	p_is_work_time: Callable,
	p_update_interface: Callable,
	p_courier_dispatcher_getter: Callable,
	p_entrance_getter: Callable,
	p_request_courier_dispatch: Callable,
	p_absolute_game_minutes: Callable,
	p_current_day_getter: Callable,
	p_refresh_ai: Callable
) -> void:
	settlement = p_settlement
	random = p_random
	outside_workers = p_outside_workers
	last_citizen_positions = p_last_citizen_positions
	selected_builder_getter = p_selected_builder_getter
	is_work_time = p_is_work_time
	update_interface = p_update_interface
	courier_dispatcher_getter = p_courier_dispatcher_getter
	entrance_getter = p_entrance_getter
	request_courier_dispatch = p_request_courier_dispatch
	absolute_game_minutes = p_absolute_game_minutes
	current_day_getter = p_current_day_getter
	refresh_ai = p_refresh_ai
