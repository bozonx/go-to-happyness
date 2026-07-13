class_name FarmingOrderProvider
extends OrderProvider

## Farming has one fixed workplace per permanent employee. The provider owns
## availability and shift checks; couriers continue to own product delivery.


func _init() -> void:
	super(&"workforce.farming")


func collect_orders(snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	var orders: Array[CitizenOrder] = []
	if snapshot == null:
		return orders
	var citizen_ids := snapshot.citizen_ids()
	citizen_ids.sort()
	for citizen_id in citizen_ids:
		var citizen := snapshot.citizen(citizen_id)
		if citizen == null or not bool(citizen.facts.value(&"work.farming.worker", false)):
			continue
		var in_progress := bool(citizen.facts.value(&"work.farming.in_progress", false))
		if not in_progress and not bool(citizen.facts.value(&"work.farming.can_start", false)):
			continue
		var farm_position: Variant = citizen.facts.value(&"work.farming.position", Vector3.INF)
		var warehouse_position: Variant = citizen.facts.value(&"work.farming.warehouse_position", Vector3.INF)
		if not (farm_position is Vector3) or farm_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
			continue
		var order := CitizenOrder.new(
			citizen_id,
			&"farming",
			id,
			0.50,
			AIFactSet.new({
				&"work.farm_position": farm_position,
				&"work.warehouse_position": warehouse_position,
			})
		)
		order.target_position = farm_position
		orders.append(order)
	return orders
