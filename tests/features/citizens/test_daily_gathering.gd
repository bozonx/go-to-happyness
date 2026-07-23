extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	assert(simulation.warehouse_positions.is_empty())
	var citizen: Citizen = simulation.hero_citizen
	citizen.set_player_controlled(false)
	var resources_by_role := {
		"gather_grass": "grass",
		"gather_branches": "branches",
	}
	for role in resources_by_role:
		SimHelper.assign_daily_order(simulation, citizen, role)
		var snapshot := SettlementAIWorldFacade.new(simulation).capture(1)
		var orders := DailyPlayerOrderProvider.new().collect_orders(snapshot)
		var citizen_orders := orders.filter(func(order: CitizenOrder): return order.citizen_id == citizen.ai_id)
		assert(citizen_orders.size() == 1)
		var order: CitizenOrder = citizen_orders[0]
		assert(order.kind == &"gathering")
		assert(order.payload.value(&"resource.type") == resources_by_role[role])
		assert(order.payload.value(&"warehouse.position") == order.payload.value(&"target.access_position"))

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
