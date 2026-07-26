extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Verifies the complete campfire intent path and its routing-owned traffic
## effect: UI toggle -> settlement policy -> stronger desire-line accumulation.


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)
	var orders_menu: CampfireOrdersMenu = simulation.ui_manager.campfire_orders_menu
	var toggle := orders_menu.get_node("RoadWalkingToggle") as CheckButton
	assert(toggle != null and not toggle.disabled)

	var ordered_cell := Vector2i(21, 20)
	var normal_cell := Vector2i(21, 22)
	var ordered_before: float = simulation.trail_field.cell_strength(ordered_cell)
	var normal_before: float = simulation.trail_field.cell_strength(normal_cell)

	toggle.button_pressed = true
	assert(simulation.settlement.road_walking_order_enabled)
	simulation.world_navigation_controller.record_trail_movement(9001, Vector3(20.1, 0.0, 20.1))
	simulation.world_navigation_controller.record_trail_movement(9001, Vector3(21.1, 0.0, 20.1))

	toggle.button_pressed = false
	assert(not simulation.settlement.road_walking_order_enabled)
	simulation.world_navigation_controller.record_trail_movement(9002, Vector3(20.1, 0.0, 22.1))
	simulation.world_navigation_controller.record_trail_movement(9002, Vector3(21.1, 0.0, 22.1))

	var ordered_gain: float = simulation.trail_field.cell_strength(ordered_cell) - ordered_before
	var normal_gain: float = simulation.trail_field.cell_strength(normal_cell) - normal_before
	assert(is_equal_approx(ordered_gain, TrailFieldService.ROAD_WALKING_TRAFFIC_STRENGTH))
	assert(is_equal_approx(normal_gain, TrailFieldService.NORMAL_TRAFFIC_STRENGTH))
	assert(ordered_gain > normal_gain)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
