class_name TradeOrder
extends RefCounted

const ENDPOINT_MARKET := &"market"
const ENDPOINT_STORAGE := &"storage"
const ENDPOINT_ENTRANCE_STONE := &"entrance_stone"

var trade: Dictionary = {}
var source := Vector3.ZERO
var destination := Vector3.ZERO
var source_endpoint := ENDPOINT_MARKET
var destination_endpoint := ENDPOINT_STORAGE
var outside_duration_minutes := 0.0
var return_at_minutes := -1.0


static func create(
	next_trade: Dictionary,
	next_source: Vector3,
	next_destination: Vector3,
	next_source_endpoint := ENDPOINT_MARKET,
	next_destination_endpoint := ENDPOINT_STORAGE
) -> RefCounted:
	var order := TradeOrder.new()
	order.trade = next_trade.duplicate(true)
	order.source = next_source
	order.destination = next_destination
	order.source_endpoint = next_source_endpoint
	order.destination_endpoint = next_destination_endpoint
	return order


static func entrance_purchase(next_trade: Dictionary, entrance_position: Vector3, delivery_position: Vector3) -> RefCounted:
	var order := create(next_trade, entrance_position, delivery_position, ENDPOINT_ENTRANCE_STONE, ENDPOINT_STORAGE)
	order.outside_duration_minutes = 120.0
	return order


func reserved_money() -> int:
	match str(trade.get("kind", "")):
		"buy_resource": return int(trade.get("quantity", 0)) * int(trade.get("price", 0))
		"buy_tool": return int(trade.get("price", 0))
		"buy_courier_equipment": return int(trade.get("price", 0))
		"buy_gloves": return int(trade.get("price", 0))
	return 0


func incoming_resource(resource_type: String) -> int:
	if str(trade.get("kind", "")) == "buy_resource" and str(trade.get("resource", "")) == resource_type:
		return int(trade.get("quantity", 0))
	return 0


func has_tool_order(tool_id: String) -> bool:
	return str(trade.get("kind", "")) == "buy_tool" and str(trade.get("tool", "")) == tool_id
