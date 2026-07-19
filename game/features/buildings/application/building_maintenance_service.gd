class_name BuildingMaintenanceService
extends RefCounted

const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")

var building_registry: RefCounted
var settlement: RefCounted
var village_territory_service: RefCounted
var resource_pile_service: ResourcePileService

var callbacks: Dictionary = {}

func setup(
	building_registry_ref: RefCounted,
	settlement_ref: RefCounted,
	territory_service_ref: RefCounted,
	pile_service_ref: ResourcePileService,
	callbacks_dict: Dictionary = {}
) -> void:
	building_registry = building_registry_ref
	settlement = settlement_ref
	village_territory_service = territory_service_ref
	resource_pile_service = pile_service_ref
	callbacks = callbacks_dict

func apply_building_wear_and_repairs(destroy_callback: Callable) -> void:
	if building_registry == null or not building_registry.has_method("records"):
		return
	for record in building_registry.records():
		var building: Node3D = record.node
		if not is_instance_valid(building):
			continue
		var building_type := str(building.get_meta("building_type", ""))
		if bool(building.get_meta("ruined", false)):
			continue
		var era: int = BuildingCatalogScript.era_for(building_type)
		if era > 0: # Era.EARTH is 0
			continue
		var wear: float = 8.0 if era == -1 else 3.0 # Era.TENT is -1
		var condition := maxf(0.0, float(building.get_meta("condition", 100.0)) - wear)
		building.set_meta("condition", condition)
		building.set_meta("repair_needed", condition < 82.0)
		if condition <= 0.0:
			if destroy_callback.is_valid():
				destroy_callback.call(building, building_type)

func has_active_builder(citizens: Array) -> bool:
	for citizen_item in citizens:
		var citizen := citizen_item as Node3D
		if not is_instance_valid(citizen):
			continue
		var perm_role: String = str(citizen.get("permanent_role")) if "permanent_role" in citizen else ""
		var spec: String = str(citizen.get("specialization")) if "specialization" in citizen else ""
		if perm_role == "construction" or spec == "builder":
			return true
	return false

func destroy_building_to_pile(building: Node3D, building_type: String, citizens: Array, warehouse_positions: Array[Vector3], campfire_node: Node3D) -> void:
	var unregister_pockets: Callable = callbacks.get("unregister_pockets", Callable())
	if unregister_pockets.is_valid():
		unregister_pockets.call(building)

	var resources: Dictionary = BuildingCatalogScript.demolition_refund(building_type).duplicate(true)

	if building_type in ["warehouse", "straw_warehouse", "tarp_warehouse"]:
		var service_position: Vector3 = building.get_meta("service_position", building.global_position)
		var warehouse_index := warehouse_positions.find(service_position)
		var move_resources: Callable = callbacks.get("move_stored_resources", Callable())
		if move_resources.is_valid():
			move_resources.call(resources, warehouse_index)

	var refresh_living: Callable = callbacks.get("refresh_living_status", Callable())
	for citizen_item in citizens:
		var citizen := citizen_item as Node3D
		if not is_instance_valid(citizen):
			continue
		if citizen.get("home") == building:
			citizen.set("home", null)
			if refresh_living.is_valid():
				refresh_living.call(citizen)

	var return_supplies: Callable = callbacks.get("return_supplies", Callable())
	if return_supplies.is_valid():
		return_supplies.call(building)

	var remove_services: Callable = callbacks.get("remove_services", Callable())
	if remove_services.is_valid():
		remove_services.call(building, building_type)

	var removed_record: RefCounted = null
	if building_registry != null and building_registry.has_method("remove_node"):
		removed_record = building_registry.remove_node(building)

	if removed_record != null:
		var unregister_nav: Callable = callbacks.get("unregister_nav_footprint", Callable())
		if unregister_nav.is_valid():
			unregister_nav.call(removed_record.center, removed_record.footprint)
		if village_territory_service != null and village_territory_service.has_method("on_building_removed"):
			village_territory_service.on_building_removed(removed_record.cell)

	var refresh_boundary: Callable = callbacks.get("refresh_boundary", Callable())
	if refresh_boundary.is_valid():
		refresh_boundary.call()

	if settlement != null and settlement.buildings != null:
		settlement.buildings[building_type] = maxi(0, int(settlement.buildings.get(building_type, 1)) - 1)

	if campfire_node == null:
		var select_campfire: Callable = callbacks.get("select_best_campfire", Callable())
		if select_campfire.is_valid():
			select_campfire.call()

	if resource_pile_service != null:
		resource_pile_service.create_resource_pile(building.global_position, resources)

	building.queue_free()

	var refresh_nav_grid: Callable = callbacks.get("refresh_nav_grid", Callable())
	if refresh_nav_grid.is_valid():
		refresh_nav_grid.call()

	var update_workers: Callable = callbacks.get("update_workers", Callable())
	if update_workers.is_valid():
		update_workers.call()
