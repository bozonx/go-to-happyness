class_name StorageState
extends RefCounted

## Warehouse and backpack storage for settlement resources.
## Manages physical inventories, capacity, delivery reservations,
## and the transition from starter backpack to warehouse storage.

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const STORED_RESOURCES = ResourceIds.ALL
const STORAGE_WEIGHTS = ResourceIds.STORAGE_WEIGHTS

## Per-warehouse inventories. Each WarehouseState holds the contents of one
## physical warehouse; the scalar resource properties above aggregate across
## all of them.
var warehouses: Array[WarehouseState] = []
var warehouse_types: Array[String] = []

## Physical resources before the first warehouse live in the starter backpack.
## The backpack is a special non-replenishable ground pile shown separately in HUD.
var backpack: Dictionary[StringName, int] = {}
## Backward-compatible alias used by tests and UI during the refactor.
var virtual_stock: Dictionary:
	get: return backpack
## Becomes true the first time any warehouse is completed and never reverts.
var warehouse_ever_built: bool = false
var warehouse_tarp_covered: bool = false
## In balanced mode the warehouse with the lowest fill percentage for a
## resource is chosen; otherwise the nearest eligible warehouse wins.
var balanced_warehouse_mode: bool = false


func storage_weight(resource_type: String) -> float:
	return float(STORAGE_WEIGHTS.get(resource_type, 1.0))


func can_cover_warehouse_with_tarp() -> bool:
	return not warehouse_tarp_covered and amount(ResourceIds.TARP) > 0


func cover_warehouse_with_tarp() -> bool:
	if not can_cover_warehouse_with_tarp():
		return false
	_set_resource_aggregate(ResourceIds.TARP, amount(ResourceIds.TARP) - 1)
	warehouse_tarp_covered = true
	return true


func add_warehouse(building_type: String, era_res: Array[String], era: int) -> void:
	var capacity := WarehouseState.capacity_for_building_type(building_type, era)
	var warehouse := WarehouseState.new(capacity)
	_ensure_warehouse_accepts_era_resources(warehouse, era_res)
	warehouses.append(warehouse)
	warehouse_types.append(building_type)


func _ensure_warehouse_accepts_era_resources(warehouse: WarehouseState, era_res: Array[String]) -> void:
	for resource_type in era_res:
		warehouse.set_accepted(resource_type, true)


func refresh_warehouse_accepted_resources(era_res: Array[String]) -> void:
	for warehouse in warehouses:
		_ensure_warehouse_accepts_era_resources(warehouse, era_res)


func storage_capacity(_warehouse_count: int) -> int:
	var total := 0
	for warehouse in warehouses:
		total += warehouse.capacity
	return total


func storage_used_units() -> float:
	var total := 0.0
	for warehouse in warehouses:
		total += warehouse.used_units(STORAGE_WEIGHTS)
	return total


func storage_committed_units() -> float:
	var total := 0.0
	for warehouse in warehouses:
		total += warehouse.committed_units(STORAGE_WEIGHTS)
	return total


func storage_free_units(_warehouse_count: int) -> float:
	return maxf(0.0, float(storage_capacity(warehouses.size())) - storage_committed_units())


func warehouse_accepts(index: int, resource_type: String) -> bool:
	if index < 0 or index >= warehouses.size():
		return false
	return warehouses[index].accepts(resource_type)


func set_warehouse_accepted(index: int, resource_type: String, accepted: bool) -> void:
	if index < 0 or index >= warehouses.size():
		return
	warehouses[index].set_accepted(resource_type, accepted)


## Moves up to `count` units of the resource out of the given warehouse.
## Returns how many units were actually removed.
func dump_warehouse_resource(index: int, resource_type: String, count: int) -> int:
	if index < 0 or index >= warehouses.size():
		return 0
	return warehouses[index].dump_resource(resource_type, count)


func storage_room_for(resource_type: String) -> int:
	if not STORED_RESOURCES.has(resource_type):
		return 1 << 30
	var total := 0
	for warehouse in warehouses:
		total += warehouse.room_for(resource_type, STORAGE_WEIGHTS)
	return total


func storage_can_accept(resource_type: String, count: int) -> bool:
	return storage_room_for(resource_type) >= count


## Pick the best warehouse that can hold `count` units of the resource.
## In balanced mode the warehouse with the lowest fill percentage for this
## resource is chosen; otherwise the nearest eligible warehouse wins.
func find_warehouse_index(from_position: Vector3, resource_type: String, count: int, positions: Array[Vector3]) -> int:
	if warehouses.is_empty() or positions.is_empty() or count <= 0:
		return -1
	var candidates: Array[int] = []
	for i in range(warehouses.size()):
		if i >= positions.size():
			continue
		if warehouses[i].room_for(resource_type, STORAGE_WEIGHTS) < count:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	if balanced_warehouse_mode:
		var best_index := candidates[0]
		var best_ratio := INF
		for i in candidates:
			var capacity := maxi(1, warehouses[i].capacity)
			var ratio := float(warehouses[i].amount(resource_type)) / float(capacity)
			if ratio < best_ratio:
				best_ratio = ratio
				best_index = i
		return best_index
	var best_index := -1
	var best_distance := INF
	for i in candidates:
		var distance := from_position.distance_squared_to(positions[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func reserve_warehouse_room(index: int, resource_type: String, count: int) -> bool:
	if index < 0 or index >= warehouses.size():
		return false
	return warehouses[index].reserve(resource_type, count, STORAGE_WEIGHTS)


func release_warehouse_reservation(index: int, resource_type: String, count: int) -> void:
	if index < 0 or index >= warehouses.size():
		return
	warehouses[index].release(resource_type, count)


func warehouse_room_for(index: int, resource_type: String) -> int:
	if index < 0 or index >= warehouses.size():
		return 0
	return warehouses[index].room_for(resource_type, STORAGE_WEIGHTS)


## Returns an availability code matching SettlementState.StorageAvailability values.
## 0 = OK, 1 = UNKNOWN_RESOURCE, 2 = NO_WAREHOUSE, 3 = NO_ROOM
func storage_availability_for(resource_type: String, count: int, warehouse_count: int) -> int:
	if count <= 0:
		return 0
	if not STORED_RESOURCES.has(resource_type):
		return 1
	if warehouse_count <= 0:
		return 2
	return 0 if storage_room_for(resource_type) >= count else 3


func can_make_room_for(resource_type: String, count: int, _warehouse_count: int) -> bool:
	return storage_room_for(resource_type) >= count


func reserve_storage_room_for(resource_type: String, count: int, warehouse_count: int) -> bool:
	if count <= 0 or not STORED_RESOURCES.has(resource_type):
		return count <= 0
	if warehouse_count <= 0:
		return false
	for i in range(min(warehouse_count, warehouses.size())):
		if reserve_warehouse_room(i, resource_type, count):
			return true
	return false


func _set_resource_aggregate(resource_type: String, value: int) -> void:
	if not warehouse_ever_built:
		backpack[resource_type] = value
		return
	for i in range(warehouses.size()):
		warehouses[i].set_amount(resource_type, value if i == 0 else 0)


func amount(resource_type: String) -> int:
	if not warehouse_ever_built:
		return int(backpack.get(resource_type, 0))
	var total := 0
	for warehouse in warehouses:
		total += warehouse.amount(resource_type)
	return total


func backpack_amount(resource_type: String) -> int:
	return int(backpack.get(resource_type, 0))


func warehouse_amount(resource_type: String, index: int) -> int:
	if index < 0 or index >= warehouses.size():
		return 0
	return warehouses[index].amount(resource_type)


## Add resources to a specific warehouse by index. Returns how many could not fit.
## Callers typically reserve the room first; this helper releases a matching
## reservation so the cargo actually fits.
func add_to_warehouse(resource_type: String, value: int, index: int) -> int:
	if not warehouse_ever_built:
		return value
	if index < 0 or index >= warehouses.size():
		return value
	if value > 0:
		warehouses[index].release(resource_type, value)
	return warehouses[index].add(resource_type, value, STORAGE_WEIGHTS)


## Default delivery behaviour: fill warehouses sequentially and remove from them
## sequentially. Keeps the first warehouses stocked until they are full, then spills
## into the next ones. Excess is silently discarded to preserve the no-overflow
## invariant; callers that need overflow handling should use add_to_warehouse.
func add(resource_type: String, value: int) -> void:
	if not warehouse_ever_built:
		backpack[resource_type] = int(backpack.get(resource_type, 0)) + value
		return
	if warehouses.is_empty():
		# Resources received while no physical warehouse exists fall back to the backpack
		# rather than being silently lost; this matches demolition edge cases.
		backpack[resource_type] = maxi(0, int(backpack.get(resource_type, 0)) + value)
		return
	if value >= 0:
		_distribute_add(resource_type, value)
	else:
		_distribute_remove(resource_type, -value)


## Used for debug/cheat grants: pull every warehouse toward the average amount of
## the given resource. Never overfills a warehouse; excess is returned as overflow.
func add_cheat(resource_type: String, value: int) -> int:
	if value <= 0:
		add(resource_type, value)
		return 0
	if not warehouse_ever_built or warehouses.is_empty():
		return value
	# Cheat resources are only bounded by the physical warehouse capacity and accept filters.
	var total_room := 0
	for warehouse in warehouses:
		total_room += warehouse.room_for(resource_type, STORAGE_WEIGHTS)
	var to_add := mini(value, total_room)
	if to_add <= 0:
		return value
	var remaining := to_add
	while remaining > 0:
		var target := _find_least_stocked_warehouse(resource_type)
		if target < 0:
			break
		var accepted := warehouses[target].add(resource_type, remaining, STORAGE_WEIGHTS)
		var added := remaining - accepted
		remaining = accepted
		if added == 0:
			break
	return value - to_add + remaining


func _distribute_add(resource_type: String, value: int) -> void:
	var remaining := value
	for warehouse in warehouses:
		remaining = warehouse.add(resource_type, remaining, STORAGE_WEIGHTS)
		if remaining <= 0:
			break


func _distribute_remove(resource_type: String, value: int) -> void:
	var remaining := value
	for warehouse in warehouses:
		var current := warehouse.amount(resource_type)
		var removed := mini(remaining, current)
		warehouse.set_amount(resource_type, current - removed)
		remaining -= removed
		if remaining <= 0:
			break


func _find_least_stocked_warehouse(resource_type: String) -> int:
	var best := -1
	var best_amount := INF
	for i in range(warehouses.size()):
		if not warehouses[i].accepts(resource_type):
			continue
		var count := warehouses[i].amount(resource_type)
		if count < best_amount:
			best_amount = count
			best = i
	return best


## Fills the least-stocked warehouse up to `percent` of its capacity.
## Only warehouses below the threshold are considered; repeated calls move to
## the next least-stocked qualifying warehouse. Resources are added evenly,
## prioritising types that are currently low in the chosen warehouse.
## Returns a dictionary with `filled` (bool) and `overflow` (resource -> leftover).
func fill_least_warehouse_cheat(percent: float, era_res: Array[String]) -> Dictionary:
	var result := {"filled": false, "overflow": {}}
	if not warehouse_ever_built or warehouses.is_empty():
		return result
	var threshold := clampf(percent / 100.0, 0.0, 1.0)
	var candidates: Array[int] = []
	for i in range(warehouses.size()):
		var warehouse := warehouses[i]
		var used := warehouse.used_units(STORAGE_WEIGHTS)
		if used >= float(warehouse.capacity) * threshold:
			continue
		var accepts_any := false
		for resource_type in era_res:
			if warehouse.accepts(resource_type):
				accepts_any = true
				break
		if not accepts_any:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return result
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return warehouses[a].used_units(STORAGE_WEIGHTS) < warehouses[b].used_units(STORAGE_WEIGHTS)
	)
	var target_index := candidates[0]
	var target := warehouses[target_index]
	result["target_index"] = target_index
	var accepted_era_res: Array[String] = []
	for resource_type in era_res:
		if target.accepts(resource_type):
			accepted_era_res.append(resource_type)
	if accepted_era_res.is_empty():
		return result
	var fill_target := float(target.capacity) * threshold
	var free_units := maxf(0.0, fill_target - target.used_units(STORAGE_WEIGHTS))
	if free_units <= 0.0:
		return result
	var share := free_units / float(accepted_era_res.size())
	for resource_type in accepted_era_res:
		var weight := storage_weight(resource_type)
		if weight <= 0.0:
			continue
		var current_units := float(target.amount(resource_type)) * weight
		var needed_units := maxf(0.0, share - current_units)
		var grant_count := int(floor(needed_units / weight))
		if grant_count <= 0:
			continue
		var leftover := target.add(resource_type, grant_count, STORAGE_WEIGHTS)
		if leftover > 0:
			result.overflow[resource_type] = leftover
		result.filled = true
	return result


func _find_least_used_warehouse() -> int:
	var best := 0
	var best_used := warehouses[0].used_units(STORAGE_WEIGHTS)
	for i in range(1, warehouses.size()):
		var used := warehouses[i].used_units(STORAGE_WEIGHTS)
		if used < best_used:
			best_used = used
			best = i
	return best


func total_stored_resources() -> int:
	var total := 0
	if not warehouse_ever_built:
		for value in backpack.values():
			total += int(value)
	else:
		for warehouse in warehouses:
			for resource_type in STORED_RESOURCES:
				total += warehouse.amount(resource_type)
	return total


func uses_virtual_storage() -> bool:
	return not warehouse_ever_built


func migrate_backpack_to_warehouse() -> Dictionary:
	warehouse_ever_built = true
	var overflow := {}
	if warehouses.is_empty():
		overflow = backpack.duplicate()
	else:
		for resource_type in STORED_RESOURCES:
			var backpack_count := int(backpack.get(resource_type, 0))
			var remaining := backpack_count
			for warehouse in warehouses:
				remaining = warehouse.add(resource_type, remaining, STORAGE_WEIGHTS)
				if remaining <= 0:
					break
			if remaining > 0:
				overflow[resource_type] = remaining
	backpack.clear()
	return overflow


## Backward-compatible alias kept during the refactor.
func migrate_virtual_to_warehouse(_warehouse_count: int) -> Dictionary:
	return migrate_backpack_to_warehouse()
