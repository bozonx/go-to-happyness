extends SceneTree

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests hero view toggle, citizen selection/possession, and B/T input keys.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)
	_test_direct_control_terrain_rules()

	# The game starts in hero view; R toggles between hero FPP and overview.
	assert(simulation.is_first_person)
	SimHelper.toggle_hero_view(simulation)
	assert(not simulation.is_first_person)
	SimHelper.toggle_hero_view(simulation)
	assert(simulation.is_first_person)
	assert(simulation.player_citizen == simulation.hero_citizen)
	SimHelper.select_citizen(simulation, simulation.citizens[1])
	SimHelper.take_control_of_selected_citizen(simulation)
	assert(simulation.player_citizen == simulation.citizens[1])
	SimHelper.toggle_hero_view(simulation)
	assert(simulation.player_citizen == simulation.hero_citizen)

	# B opens the global build menu in overview mode, not only in first-person.
	SimHelper.toggle_hero_view(simulation)
	assert(not simulation.is_first_person)
	var b_event := InputEventKey.new()
	b_event.keycode = KEY_B
	b_event.pressed = true
	SimHelper.unhandled_input(simulation, b_event)
	assert(simulation.ui_manager.build_menu.visible)
	assert(simulation.build_menu_is_global)
	var b_release := InputEventKey.new()
	b_release.keycode = KEY_B
	b_release.pressed = false
	SimHelper.unhandled_input(simulation, b_release)
	SimHelper.toggle_hero_view(simulation)
	assert(simulation.is_first_person)

	# T in first-person drops the controlled unit's pocket contents as a ground pile.
	simulation.pocket = {"wood": 3, "food": 2}
	var piles_before_drop: int = simulation.resource_piles.size()
	var t_event := InputEventKey.new()
	t_event.keycode = KEY_T
	t_event.pressed = true
	SimHelper.unhandled_input(simulation, t_event)
	assert(simulation.pocket.is_empty())
	assert(simulation.resource_piles.size() == piles_before_drop + 1)
	var dropped_pile: ResourcePileScript = simulation.resource_piles[simulation.resource_piles.size() - 1]
	assert(int(dropped_pile.resources.get("wood", 0)) == 3)
	assert(int(dropped_pile.resources.get("food", 0)) == 2)
	var t_release := InputEventKey.new()
	t_release.keycode = KEY_T
	t_release.pressed = false
	SimHelper.unhandled_input(simulation, t_release)

	await SimHelper.cleanup_simulation(self, simulation)
	quit(0)


func _test_direct_control_terrain_rules() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, 16)
	for z in range(-2, 3):
		for x in range(1, 4):
			assert(terrain.set_height(Vector2i(x, z), 2))
	var grid := NavGrid.new()
	grid.configure(1.0, 16)
	TerrainNavigationPublisher.publish(terrain, grid)
	var below_lip := Vector3(0.9, 0.0, 0.5)
	var above_lip := Vector3(1.1, 1.0, 0.5)
	assert(not PlayerController.direct_motion_allowed(grid, below_lip, above_lip, false), "ground input may not cross a terrace face")
	assert(PlayerController.direct_motion_allowed(grid, below_lip, above_lip, true), "a jump may cross a physically jumpable terrace lip")

	var recovery_terrain := TerrainGrid.new()
	recovery_terrain.configure(1.0, 16)
	assert(recovery_terrain.set_hole(Vector2i(0, 0), true))
	var recovery_grid := NavGrid.new()
	recovery_grid.configure(1.0, 16)
	TerrainNavigationPublisher.publish(recovery_terrain, recovery_grid)
	assert(PlayerController.direct_motion_allowed(recovery_grid, Vector3(0.5, 0.0, 0.5), Vector3(0.7, 0.0, 0.5), false), "direct control must move inside an invalid start cell")
	assert(PlayerController.direct_motion_allowed(recovery_grid, Vector3(0.9, 0.0, 0.5), Vector3(1.1, 0.0, 0.5), false), "direct control must be able to escape onto valid ground")
	assert(not PlayerController.direct_motion_allowed(recovery_grid, Vector3(7.9, 0.0, 0.5), Vector3(8.1, 0.0, 0.5), true), "airborne input may not cross the board rim")
