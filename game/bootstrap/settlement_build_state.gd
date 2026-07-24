class_name SettlementBuildState
extends RefCounted

## Build-mode, placement selection, and build-menu navigation state.
## Extracted from SettlementGame to reduce its field count.

var selected_cell := Vector2i(0, 0)
var selected_world_position := Vector3.ZERO
var build_mode := ""
var build_rotation_quarters := 0
var selected_builder: Citizen
var selected_building: Node3D
var dig_mode := false
var build_category := ""
var build_menu_is_job_menu := false
var build_menu_is_daily_order_menu := false
var build_menu_is_global := false
