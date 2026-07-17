extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame

	assert(simulation.warehouse_positions.is_empty())
	var citizen: Citizen = simulation.hero_citizen
	citizen.set_player_controlled(false)
	var resources_by_role := {
		"gather_grass": "grass",
		"gather_branches": "branches",
	}
	for role in resources_by_role:
		simulation._assign_daily_order(citizen, role)
		var snapshot := SettlementAIWorldFacade.new(simulation).capture(1)
		var orders := DailyPlayerOrderProvider.new().collect_orders(snapshot)
		var citizen_orders := orders.filter(func(order: CitizenOrder): return order.citizen_id == citizen.ai_id)
		assert(citizen_orders.size() == 1)
		var order: CitizenOrder = citizen_orders[0]
		assert(order.kind == &"gathering")
		assert(order.payload.value(&"resource.type") == resources_by_role[role])
		assert(order.payload.value(&"warehouse.position") == order.payload.value(&"target.access_position"))

	root.remove_child(simulation)
	simulation.free()
	scene = null
	quit(0)
