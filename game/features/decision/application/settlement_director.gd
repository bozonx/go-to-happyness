class_name SettlementDirector
extends RefCounted

var order_board := OrderBoard.new()
var _providers: Array[OrderProvider] = []


func configure(providers: Array[OrderProvider]) -> void:
	_providers = providers.duplicate()
	order_board.clear()


func tick(snapshot: WorldSnapshot) -> void:
	if snapshot == null:
		return
	order_board.clear_expired(snapshot.simulation_seconds)
	for provider in _providers:
		order_board.replace_issuer_orders(
			provider.id,
			provider.collect_orders(snapshot),
			snapshot.simulation_seconds
		)


func provider_count() -> int:
	return _providers.size()
