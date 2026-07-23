extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var home := Node3D.new()
	home.position = Vector3(12.0, 0.0, 12.0)
	home.set_meta("spawn_slots", 0)
	simulation.add_child(home)
	simulation.building_registry.reserve(Vector2i(12, 12), home.position, Vector2i.ONE)
	simulation.building_registry.attach_node(Vector2i(12, 12), home)

	var resident: Citizen = simulation.citizens[1]
	resident.home = home
	var demolition_site := DemolitionSite.new(home, "tent")
	assert(not simulation._demolition_ready(demolition_site), "Demolition must wait when a resident has no replacement home")
	assert(resident.home == home)

	var replacement := Node3D.new()
	replacement.position = Vector3(16.0, 0.0, 12.0)
	replacement.set_meta("spawn_slots", 1)
	simulation.add_child(replacement)
	simulation.building_registry.reserve(Vector2i(16, 12), replacement.position, Vector2i.ONE)
	simulation.building_registry.attach_node(Vector2i(16, 12), replacement)
	assert(simulation._demolition_ready(demolition_site), "Demolition should continue after every resident can be relocated")
	assert(resident.home == replacement)
	assert(int(replacement.get_meta("spawn_slots")) == 0)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
