class_name TestDomainConstruction
extends RefCounted

const BuildingAvailabilityServiceScript = preload("res://game/features/buildings/application/building_availability_service.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")


static func run_all() -> void:
	_test_sawmill_rules()
	_test_construction_progress()
	_test_construction_reservation_blocks_other_spending()
	_test_construction_progress_limited_by_materials()
	_test_construction_service_cancellation()
	_test_completed_construction_cleans_temporary_ui()
	_test_demolition_service_completion()
	_test_building_registry()
	_test_school_and_seller_rules()
	_test_daily_order_construction_skill_cap()
	_test_building_availability_service()
	_test_building_research_service()
	_test_research_mechanics()


static func _test_sawmill_rules() -> void:
	var stock := SawmillRules.new_stock(5.0)
	stock.logs = 2
	stock = SawmillRules.advance(stock, 4.0, 4.0)
	assert(stock.logs == 1 and stock.boards == 1 and stock.process_time == 4.0)
	assert(not SawmillRules.should_worker_deliver(stock, true, 10.0, 4, 12.0))
	stock.boards = 4
	assert(SawmillRules.should_worker_deliver(stock, true, 17.0, 4, 12.0))
	assert(SawmillRules.should_worker_deliver(stock, false, 6.0, 4, 12.0))


static func _test_construction_progress() -> void:
	assert(is_equal_approx(ConstructionProgress.advance(0.25, 2.0, 4.0, 1.0), 0.75))
	assert(ConstructionProgress.advance(0.9, 4.0, 4.0, 1.0) == 1.0)


static func _test_construction_reservation_blocks_other_spending() -> void:
	var scene_root := Node3D.new()
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.settlement.apply_tent_start()
	runtime.settlement.add_warehouse("warehouse")
	runtime.settlement.add("branches", 4)
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.workers_changed = func() -> void: pass
	runtime.navigation_changed = func() -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)

	var site := service.start_site(Vector2i(1, 1), "campfire", Vector3(1, 0, 1))
	assert(runtime.settlement.construction_reserved_for_site(site.site_id, "branches") == 4)
	assert(runtime.settlement.available_amount("branches") == 0)
	assert(not runtime.settlement.can_afford_building("campfire"))
	assert(service.cancel_site(site.node))
	assert(runtime.settlement.construction_reserved_for_site(site.site_id, "branches") == 0)
	assert(runtime.settlement.available_amount("branches") == 4)
	scene_root.free()


static func _test_construction_progress_limited_by_materials() -> void:
	var scene_root := Node3D.new()
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.duration = 1.0
	runtime.builder_power = func(_site: Node3D) -> float: return 1.0
	runtime.builder_count = func(_site: Node3D) -> int: return 1
	runtime.set_status = func(_text: String) -> void: pass
	runtime.workers_changed = func() -> void: pass
	runtime.navigation_changed = func() -> void: pass
	runtime.building_completed = func(_cell: Vector2i, _type: String, _position: Vector3, _building: Node3D, _blueprint: Dictionary) -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)

	var site := service.start_site(Vector2i.ZERO, "campfire", Vector3.ZERO)
	site.progress = 0.0
	service.tick(10.0)
	assert(site.progress == 0.0)
	assert(service.accept_delivery(site.node, "branches", 2))
	site.progress = 0.0
	service.tick(10.0)
	assert(site.progress > 0.0 and site.progress <= 0.5)
	var remaining := int(site.required_materials.get("branches", 0)) - 2
	assert(service.accept_delivery(site.node, "branches", remaining))
	service.tick(10.0)
	assert(site.progress == 1.0)
	scene_root.free()


static func _test_construction_service_cancellation() -> void:
	var scene_root := Node3D.new()
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.workers_changed = func() -> void: pass
	runtime.navigation_changed = func() -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)

	var cell := Vector2i(2, 3)
	runtime.building_registry.reserve(cell, Vector3(2.0, 0.0, 3.0), Vector2i(5, 5))
	var site := service.start_site(cell, "campfire", Vector3(2.0, 0.0, 3.0))
	assert(service.has_site(site.node))
	var resource_type := str(site.required_materials.keys()[0])
	assert(service.accept_delivery(site.node, resource_type, 1))
	assert(int(site.delivered_materials[resource_type]) == 1)
	assert(service.cancel_site(site.node))
	assert(service.sites.is_empty() and runtime.building_registry.record_at_cell(cell) == null)
	scene_root.free()


static func _test_completed_construction_cleans_temporary_ui() -> void:
	var scene_root := Node3D.new()
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.duration = 1.0
	runtime.builder_power = func(_site: Node3D) -> float: return 1.0
	runtime.builder_count = func(_site: Node3D) -> int: return 1
	runtime.set_status = func(_text: String) -> void: pass
	runtime.workers_changed = func() -> void: pass
	runtime.building_completed = func(_cell: Vector2i, _type: String, _position: Vector3, _building: Node3D, _blueprint: Dictionary) -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)
	var site := service.start_site(Vector2i.ZERO, "warehouse", Vector3.ZERO)
	site.delivered_materials = site.required_materials.duplicate(true)
	service.tick(1.0)
	assert(site.node.get_node("SupplyLabel").is_queued_for_deletion())
	assert(site.node.get_node("ConstructionSelector").is_queued_for_deletion())
	scene_root.free()


static func _test_demolition_service_completion() -> void:
	var completed: Array[DemolitionSite] = []
	var runtime := DemolitionRuntime.new()
	runtime.duration = 3.0
	runtime.building_power = func(_building: Node3D) -> float: return 1.0
	runtime.is_ready = func(_site: DemolitionSite) -> bool: return true
	runtime.completed = func(site: DemolitionSite) -> void: completed.append(site)
	var service := DemolitionService.new()
	service.configure(runtime)
	var building := Node3D.new()
	assert(service.mark(building, "warehouse"))
	service.tick(3.0)
	assert(service.sites.is_empty() and completed.size() == 1 and completed[0].building_type == "warehouse")
	building.free()


static func _test_building_registry() -> void:
	var registry := BuildingRegistry.new()
	var first := registry.reserve(Vector2i(0, 0), Vector3.ZERO, Vector2i(2, 2))
	assert(first.cell == Vector2i(0, 0) and first.node == null)
	assert(not registry.is_footprint_clear(Vector3(1.0, 0.0, 0.0), Vector2i(2, 2), 0.0))
	assert(registry.is_footprint_clear(Vector3(4.0, 0.0, 0.0), Vector2i(2, 2), 0.0))

	var building := Node3D.new()
	building.set_meta("housing_capacity", 4)
	building.set_meta("service_position", Vector3(0.5, 0.0, 0.5))
	assert(registry.attach_node(Vector2i(0, 0), building) == first)
	assert(registry.housing_capacity() == 4)
	assert(registry.building_at_service_position(Vector3(0.5, 0.0, 0.5)) == building)

	registry.reserve(Vector2i(4, 0), Vector3(4.0, 0.0, 0.0), Vector2i(2, 2))
	assert(registry.cancel_reservation(Vector2i(4, 0)) != null)
	assert(registry.remove_node(building) == first and registry.records().is_empty())
	building.free()


static func _test_school_and_seller_rules() -> void:
	var seller := {"specialization": "seller", "permanent_role": "seller", "player_controlled": false, "blocked_by_storage": false}
	var world := {"hour": 9, "markets": 0}
	assert(not WorkforcePolicy.can_assign(seller, world))
	world.markets = 1
	assert(WorkforcePolicy.can_assign(seller, world))

	var citizen := Citizen.new()
	citizen.skills["farming"] = 0.5
	citizen.training_role = "farming"
	citizen.state = Citizen.State.STUDYING

	citizen.finish_school_day(false)
	assert(citizen.skills["farming"] == 0.5)
	assert(citizen.state == Citizen.State.IDLE)

	citizen.training_role = "farming"
	citizen.state = Citizen.State.STUDYING
	citizen.finish_school_day(true)
	assert(citizen.skills["farming"] > 0.5)
	citizen.free()


static func _test_daily_order_construction_skill_cap() -> void:
	var worker := Citizen.new()
	worker.assign_daily_order("construction", 1, 100.0)
	worker.skills = {"construction": Citizen.DAILY_CONSTRUCTION_SKILL_CAP - 0.00001}
	worker.active_role = "construction"
	worker.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	worker.satisfaction_tick = 10.0
	worker._update_satisfaction(0.0)
	assert(float(worker.skills.construction) <= Citizen.DAILY_CONSTRUCTION_SKILL_CAP)
	worker.clear_daily_order()
	worker.employment_state = Citizen.EmploymentState.EMPLOYED
	worker.active_role = "construction"
	worker.satisfaction_tick = 10.0
	worker._update_satisfaction(0.0)
	assert(float(worker.skills.construction) > Citizen.DAILY_CONSTRUCTION_SKILL_CAP)
	worker.free()


static func _test_building_availability_service() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	var service := BuildingAvailabilityServiceScript.new()
	service.configure(state)
	assert(service.is_category_available("tent"))
	assert(not service.is_category_available("earth"))
	var warehouse_menu: Dictionary = service.menu_state("warehouse")
	assert(bool(warehouse_menu.visible))
	assert(bool(warehouse_menu.enabled))
	assert(str(warehouse_menu.cost_text) == "free")
	var campfire_menu: Dictionary = service.menu_state("campfire")
	assert(bool(campfire_menu.visible))
	assert(bool(campfire_menu.enabled))
	assert(not bool(campfire_menu.affordable))
	var upgrade_menu: Dictionary = service.menu_state("campfire_lvl2")
	assert(not bool(upgrade_menu.visible))
	assert(upgrade_menu.reason == BuildingAvailabilityServiceScript.REASON_UPGRADE_ONLY)
	state.add_warehouse("warehouse")
	state.branches = 6
	var campfire_placement: Dictionary = service.placement_state("campfire")
	assert(bool(campfire_placement.allowed))
	assert(bool(campfire_placement.affordable))
	assert(service.cost_text("campfire") == "6/4 branches")
	state.branches = 8
	state.grass = 6
	var temporary_tent_placement: Dictionary = service.placement_state("tent")
	assert(bool(temporary_tent_placement.allowed))
	var cooking_campfire_placement: Dictionary = service.placement_state("cook_campfire")
	assert(bool(cooking_campfire_placement.allowed))
	state.branches = 0
	state.grass = 0
	var pocket := {"branches": 4}
	var pocket_campfire_menu: Dictionary = service.menu_state_with_inventory("campfire", pocket)
	assert(bool(pocket_campfire_menu.visible))
	assert(bool(pocket_campfire_menu.enabled))
	assert(bool(pocket_campfire_menu.affordable))
	var pocket_campfire_placement: Dictionary = service.placement_state_with_inventory("campfire", pocket)
	assert(bool(pocket_campfire_placement.allowed))
	assert(bool(pocket_campfire_placement.affordable))
	var partial_campfire_placement: Dictionary = service.placement_state_with_inventory("campfire", {"branches": 3})
	assert(bool(partial_campfire_placement.allowed))
	assert(not bool(partial_campfire_placement.affordable))


static func _test_building_research_service() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	state.add_warehouse("warehouse")
	state.buildings["campfire"] = 1
	state.branches = 8
	state.grass = 8
	var service := BuildingResearchServiceScript.new()
	service.configure(state)
	assert(service.visible_tech_ids().has("official"))
	var menu_state: Dictionary = service.menu_state("official", false)
	assert(bool(menu_state.visible))
	assert(not bool(menu_state.can_start))
	assert(menu_state.reason == BuildingResearchServiceScript.REASON_NO_WORKER)
	assert(service.start_research("official", 77))
	assert(state.active_research_tech_id == "official")
	assert(state.active_research_worker_id == 77)
	assert(state.branches == 4 and state.grass == 4)
	service.cancel_active(true)
	assert(state.active_research_tech_id.is_empty())
	assert(state.branches == 8 and state.grass == 8)
	assert(service.start_research("official", 77))
	service.advance_active(30.0, 1.0)
	assert(service.is_active_complete())
	var completion: Dictionary = service.complete_active()
	assert(completion.unlocked_target == "official")
	assert(completion.reward_skill == "official")
	assert(state.unlocked_systems.official)
	assert(state.active_research_tech_id.is_empty())

	assert(state.outside_work_reward_multiplier() == 1)
	state.branches = 6
	state.grass = 4
	state.money = 25
	assert(service.visible_tech_ids().has("outside_work_earnings"))
	assert(service.start_research("outside_work_earnings", 77))
	service.advance_active(25.0, 1.0)
	var earnings_completion: Dictionary = service.complete_active()
	assert(earnings_completion.unlocked_target == "outside_work_bonus")
	assert(state.unlocked_systems.outside_work_bonus)
	assert(state.outside_work_reward_multiplier() == 2)


static func _test_research_mechanics() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(state.active_research_tech_id.is_empty())
