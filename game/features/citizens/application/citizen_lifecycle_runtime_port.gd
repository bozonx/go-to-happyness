class_name CitizenLifecycleRuntimePort
extends RefCounted

## Explicit integration boundary for citizen arrival, departure and registration lifecycle.

var citizens: Array
var pending_arrivals: Array
var arrival_greeters: Dictionary
var arrival_waiting_greeters: Dictionary
var arrival_escort_ids: Dictionary
var entrance_stone_getter: Callable
var entrance_anchor_position: Callable
var employment_center_position: Callable
var is_work_time: Callable
var update_interface: Callable
var show_house_menu: Callable
var add_citizen: Callable
var refresh_living_status: Callable
var request_courier_dispatch: Callable
var citizen_for_ai_id: Callable
var terrain_height_at: Callable
var citizen_ai_unregister: Callable
var citizen_ai_cancel_work: Callable
var canteen_service_remove_citizen: Callable
var citizen_needs_service_remove_citizen: Callable
var courier_dispatcher_complete_for: Callable
var selected_house_getter: Callable
var day_cycle_current_day_getter: Callable
