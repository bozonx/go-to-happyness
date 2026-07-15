class_name WarehouseState
extends RefCounted

## Persistent inventory for a single physical warehouse.

const STORED_RESOURCES: Array[String] = [
	"branches", "grass", "water", "food", "hides", "goods",
	"logs", "wood", "soil", "clay", "boards", "stone", "bricks", "tarp"
]

const TYPE_CAPACITIES := {
	"warehouse": 24,
	"straw_warehouse": 48,
	"tarp_warehouse": 72,
}

## Total space units this warehouse can hold.
var capacity: int = 0
## resource_type -> max units this warehouse can hold of that resource.
var resource_limits: Dictionary = {}
## resource_type -> count stored in this warehouse only.
var resources: Dictionary = {}
## resource_type -> count reserved by in-flight deliveries to this warehouse.
var reserved: Dictionary = {}


func _init(p_capacity: int = 0) -> void:
	capacity = p_capacity
	for resource_type in STORED_RESOURCES:
		resources[resource_type] = 0
		reserved[resource_type] = 0
		resource_limits[resource_type] = float(p_capacity)


static func capacity_for_building_type(building_type: String, era: int) -> int:
	var explicit: int = TYPE_CAPACITIES.get(building_type, 0)
	if explicit > 0:
		return explicit
	## Era fallback for buildings that are not explicitly typed warehouses.
	var era_per_warehouse := {0: 32, 1: 48, 2: 70, 3: 100, 4: 120, 5: 150}
	return int(era_per_warehouse.get(era, 24))


func amount(resource_type: String) -> int:
	return int(resources.get(resource_type, 0))


func set_amount(resource_type: String, value: int) -> void:
	resources[resource_type] = value


## Tries to add `value` (positive or negative). Returns how many units could not be
## applied because the warehouse is full; negative values are always applied in full.
func add(resource_type: String, value: int, weights: Dictionary) -> int:
	if value < 0:
		var current := amount(resource_type)
		var removed := mini(-value, current)
		resources[resource_type] = current - removed
		return -value - removed
	if value == 0:
		return 0
	var can_fit := room_for(resource_type, weights)
	var accepted := mini(value, can_fit)
	resources[resource_type] = amount(resource_type) + accepted
	return value - accepted


func used_units(weights: Dictionary) -> float:
	var total := 0.0
	for resource_type in STORED_RESOURCES:
		total += amount(resource_type) * float(weights.get(resource_type, 1.0))
	return total


func committed_units(weights: Dictionary) -> float:
	var total := used_units(weights)
	for resource_type in STORED_RESOURCES:
		total += int(reserved.get(resource_type, 0)) * float(weights.get(resource_type, 1.0))
	return total


func free_units(weights: Dictionary) -> float:
	return maxf(0.0, float(capacity) - committed_units(weights))


func room_for(resource_type: String, weights: Dictionary) -> int:
	var weight := float(weights.get(resource_type, 1.0))
	if weight <= 0.0:
		return 1 << 30
	var reserved_count := int(reserved.get(resource_type, 0))
	var free := maxf(0.0, free_units(weights) - float(reserved_count) * weight)
	return maxi(0, int(floor(free / weight)))


func set_resource_limit(resource_type: String, limit_units: float) -> void:
	resource_limits[resource_type] = maxf(0.0, limit_units)


func resource_limit(resource_type: String) -> float:
	return float(resource_limits.get(resource_type, float(capacity)))


func reserve(resource_type: String, count: int, weights: Dictionary) -> bool:
	if count <= 0:
		return true
	if not STORED_RESOURCES.has(resource_type):
		return false
	if count > room_for(resource_type, weights):
		return false
	reserved[resource_type] = int(reserved.get(resource_type, 0)) + count
	return true


func release(resource_type: String, count: int) -> void:
	if count <= 0 or not STORED_RESOURCES.has(resource_type):
		return
	reserved[resource_type] = maxi(0, int(reserved.get(resource_type, 0)) - count)


func clear_reservations() -> void:
	for resource_type in STORED_RESOURCES:
		reserved[resource_type] = 0
