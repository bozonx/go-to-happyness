extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate() as Node
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _f in range(20):
		await physics_frame

	print("citizens=", simulation.citizens.size(), " ai=", simulation.citizen_ai)
	print("brain_count=", simulation.citizen_ai.brain_count(), " goal_count=", simulation.citizen_ai.goal_count())

	var c: Citizen = simulation.citizens[2]
	print("chosen citizen ai_id=", c.ai_id, " player=", c.is_player_controlled, " state=", c.state)
	c.global_position = Vector3(10.0, 0.0, 10.0)
	c.idle()
	SimHelper.assign_daily_order(simulation, c, "gather_food")
	print("after assign: has_daily=", c.has_daily_order(), " daily_role=", c.daily_order_role if c.has_daily_order() else "-")

	for step in range(8):
		for _f in range(15):
			await physics_frame
		var has_order: bool = simulation.citizen_ai.has_current_order(c.ai_id)
		print("t", step, " state=", c.state, " active_role=", c.active_role, " has_order=", has_order, " nav_failed=", c.navigation_failed, " pos=", c.global_position)

	quit(0)
