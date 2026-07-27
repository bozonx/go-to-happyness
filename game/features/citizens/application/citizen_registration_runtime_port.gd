class_name CitizenRegistrationRuntimePort
extends RefCounted

## Explicit integration boundary for civic registration, officer staffing
## checks and queue ticket generation.

var citizens: Array
var officer_post_radius: float
var employment_centre_building_getter: Callable
var employment_center_position_getter: Callable
var is_work_time: Callable
var update_workers: Callable
var registration_queue_counter_setter: Callable
