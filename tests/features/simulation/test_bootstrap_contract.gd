extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Guards composition-root invariants that ordinary gameplay tests do not make
## explicit: dependency order, feature-owned runtime state, and global cleanup.


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	assert(simulation.logistics_runtime != null)
	assert(simulation.logistics_runtime.pending_arrivals.is_empty())
	assert(simulation.logistics_runtime.queued_trades.is_empty())
	assert(simulation.event_service != null)
	assert(simulation.fire_management_service.event_service == simulation.event_service)

	# The first-person mode deliberately keeps simulation speed at one; set the
	# global explicitly to verify the scene lifecycle still restores it.
	Engine.time_scale = 3.0
	assert(is_equal_approx(Engine.time_scale, 3.0))
	await SimHelper.cleanup_simulation(self, simulation)
	await process_frame
	assert(is_equal_approx(Engine.time_scale, 1.0))
	quit(0)
