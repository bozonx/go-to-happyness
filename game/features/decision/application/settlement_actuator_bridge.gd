class_name SettlementActuatorBridge
extends RefCounted

## Handles citizen execution signals and bridges them to domain and application services.

var canteen_service: RefCounted
var courier_dispatcher: RefCounted
var construction: RefCounted
var settlement: RefCounted
var building_registry: RefCounted
var storage_delivery_service: RefCounted
var factory_service: RefCounted
var sawmills: RefCounted
var water_collector_service: RefCounted
var excavation_service: RefCounted
var citizen_needs_service: RefCounted
var trade_service: RefCounted

var resource_piles: Array = []
var game_minutes_query := Callable()
var runtime_seconds_query := Callable()

var update_interface_fn := Callable()
var request_courier_dispatch_fn := Callable()
var request_decision_refresh_fn := Callable()
var refresh_living_statuses_fn := Callable()
var drop_resource_pile_fn := Callable()
var fire_state_query := Callable()
var apply_fire_state_fn := Callable()


func configure(
	canteen_svc: RefCounted,
	dispatcher: RefCounted,
	construction_svc: RefCounted,
	settlement_ref: RefCounted,
	registry: RefCounted,
	storage_svc: RefCounted,
	factory_svc: RefCounted,
	sawmills_svc: RefCounted,
	water_svc: RefCounted,
	excavation_svc: RefCounted,
	needs_svc: RefCounted,
	trade_svc: RefCounted,
	piles: Array,
	minutes_fn: Callable,
	runtime_fn: Callable,
	ui_fn: Callable,
	dispatch_fn: Callable,
	refresh_ai_fn: Callable,
	refresh_living_fn: Callable,
	drop_pile_fn: Callable,
	fire_query_fn: Callable,
	apply_fire_fn: Callable
) -> void:
	canteen_service = canteen_svc
	courier_dispatcher = dispatcher
	construction = construction_svc
	settlement = settlement_ref
	building_registry = registry
	storage_delivery_service = storage_svc
	factory_service = factory_svc
	sawmills = sawmills_svc
	water_collector_service = water_svc
	excavation_service = excavation_svc
	citizen_needs_service = needs_svc
	trade_service = trade_svc
	resource_piles = piles
	game_minutes_query = minutes_fn
	runtime_seconds_query = runtime_fn
	update_interface_fn = ui_fn
	request_courier_dispatch_fn = dispatch_fn
	request_decision_refresh_fn = refresh_ai_fn
	refresh_living_statuses_fn = refresh_living_fn
	drop_resource_pile_fn = drop_pile_fn
	fire_state_query = fire_query_fn
	apply_fire_state_fn = apply_fire_fn


func wire_citizen(citizen: Node3D) -> void:
	if not is_instance_valid(citizen):
		return
	citizen.resource_delivered.connect(on_resource_delivered)
	citizen.resource_dropped.connect(on_resource_dropped)
	citizen.construction_material_delivered.connect(on_construction_material_delivered)
	citizen.building_supply_delivered.connect(on_building_supply_delivered)
	citizen.excavation_cycle.connect(on_excavation_cycle)
	citizen.resource_ready.connect(on_resource_ready)
	citizen.logs_delivered.connect(on_logs_delivered)
	citizen.sawmill_boards_collected.connect(on_sawmill_boards_collected)
	citizen.dew_collected.connect(on_dew_collected)
	citizen.meal_finished.connect(on_meal_finished)
	citizen.relief_finished.connect(on_relief_finished)
	citizen.leisure_finished.connect(on_leisure_finished)
	citizen.canteen_delivery_finished.connect(on_canteen_delivery_finished)
	citizen.factory_cycle.connect(on_factory_cycle)
	citizen.trade_delivery_finished.connect(on_trade_delivery_finished)


func on_meal_finished(citizen: Node3D) -> void:
	if canteen_service != null:
		canteen_service.on_meal_finished(citizen)


func on_canteen_delivery_finished(worker: Node3D, amount: int) -> void:
	if courier_dispatcher != null:
		courier_dispatcher.complete_for(worker)
	if canteen_service != null:
		canteen_service.on_canteen_delivery_finished(worker, amount)


func on_construction_material_delivered(courier: Node3D, site_node: Node3D, resource_type: String, amount: int) -> void:
	if construction != null:
		if not construction.accept_delivery(site_node, resource_type, amount):
			if settlement != null:
				settlement.add(resource_type, amount)
			var site: Variant = construction.site_for_node(site_node)
			if site != null:
				site.reserved_materials[resource_type] = maxi(0, int(site.reserved_materials.get(resource_type, 0)) - amount)
				if settlement != null:
					settlement.release_for_construction(site.site_id, resource_type, amount)
			if update_interface_fn.is_valid():
				update_interface_fn.call("Construction site is full; courier returned %d %s to storage." % [amount, resource_type])
	if courier_dispatcher != null:
		courier_dispatcher.complete_for(courier)
	if request_courier_dispatch_fn.is_valid():
		request_courier_dispatch_fn.call()
	if request_decision_refresh_fn.is_valid():
		request_decision_refresh_fn.call()


func on_building_supply_delivered(courier: Node3D, target: Node3D, supply_kind: String, resource_type: String, amount: int) -> void:
	if courier_dispatcher != null:
		courier_dispatcher.complete_for(courier)
	if not is_instance_valid(target):
		if settlement != null:
			settlement.add(resource_type, amount)
		return
	match supply_kind:
		"firewood":
			if fire_state_query.is_valid() and apply_fire_state_fn.is_valid():
				var fire_state: Variant = fire_state_query.call(target)
				var minutes: int = int(game_minutes_query.call()) if game_minutes_query.is_valid() else 0
				fire_state.add_delivered(amount, minutes)
				apply_fire_state_fn.call(target, fire_state)
				if refresh_living_statuses_fn.is_valid():
					refresh_living_statuses_fn.call()
		"repair":
			if building_registry != null:
				var repair_record: Variant = building_registry.record_for_node(target)
				var repair_state: Variant = repair_record.runtime_state() if repair_record != null else null
				if repair_state != null:
					repair_state.repair_reserved = false
					repair_state.condition = minf(100.0, repair_state.condition + 18.0)
					repair_state.repair_needed = repair_state.condition < 82.0
					repair_state.apply_to_node(target)
		"pile":
			if settlement != null:
				settlement.add(resource_type, amount)
			for index in resource_piles.size():
				if resource_piles[index].node == target:
					resource_piles[index].reserved[resource_type] = maxi(0, int(resource_piles[index].reserved.get(resource_type, 0)) - amount)
					break


func on_resource_delivered(worker: Node3D, resource_type: String, amount: int) -> void:
	if storage_delivery_service != null:
		storage_delivery_service.on_resource_delivered(worker, resource_type, amount)


func on_resource_dropped(worker: Node3D, resource_type: String, amount: int) -> void:
	if drop_resource_pile_fn.is_valid():
		drop_resource_pile_fn.call(worker.global_position, resource_type, amount)
	if update_interface_fn.is_valid():
		update_interface_fn.call("Worker dropped %d %s in a ground pile after the order was interrupted." % [amount, resource_type])


func on_factory_cycle(worker: Node3D, factory: Node3D) -> void:
	if factory_service != null:
		factory_service.on_factory_cycle(worker, factory)


func on_resource_ready(worker: Node3D, resource_type: String, amount: int) -> void:
	if worker is Citizen:
		(worker as Citizen).register_pending_resource(resource_type, amount)
	if request_courier_dispatch_fn.is_valid():
		request_courier_dispatch_fn.call()


func on_logs_delivered(worker: Node3D, sawmill_position: Vector3, amount: int) -> void:
	if sawmills != null:
		var runtime: float = float(runtime_seconds_query.call()) if runtime_seconds_query.is_valid() else 0.0
		sawmills.accept_logs(worker, sawmill_position, amount, runtime)
	if request_courier_dispatch_fn.is_valid():
		request_courier_dispatch_fn.call()


func on_sawmill_boards_collected(courier: Node3D, sawmill_position: Vector3) -> void:
	if sawmills != null:
		var runtime: float = float(runtime_seconds_query.call()) if runtime_seconds_query.is_valid() else 0.0
		sawmills.collect_boards(courier, sawmill_position, runtime)
	if request_courier_dispatch_fn.is_valid():
		request_courier_dispatch_fn.call()


func on_dew_collected(courier: Node3D, collector_position: Vector3) -> void:
	if water_collector_service != null and courier is Citizen:
		var citizen := courier as Citizen
		var amount: int = int(water_collector_service.collect_water(collector_position, citizen.courier_capacity()))
		citizen.collect_dew(amount)
	if request_courier_dispatch_fn.is_valid():
		request_courier_dispatch_fn.call()


func on_excavation_cycle(worker: Node3D, site_node: Node3D, efficiency: float) -> void:
	if excavation_service != null:
		excavation_service.on_excavation_cycle(worker, site_node, efficiency)


func on_relief_finished(citizen: Node3D) -> void:
	if citizen_needs_service != null and citizen is Citizen:
		citizen_needs_service.fulfill_toilet((citizen as Citizen).ai_id)


func on_leisure_finished(citizen: Node3D) -> void:
	if citizen_needs_service != null and citizen is Citizen:
		citizen_needs_service.fulfill_rest((citizen as Citizen).ai_id)


func on_trade_delivery_finished(worker: Node3D) -> void:
	if trade_service != null and worker is Citizen:
		trade_service.on_trade_delivery_finished(worker as Citizen)
	if courier_dispatcher != null and worker is Citizen:
		courier_dispatcher.complete_for(worker as Citizen)
