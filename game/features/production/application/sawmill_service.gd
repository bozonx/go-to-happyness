class_name SawmillService
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func stock_at(position: Vector3, now_seconds: float) -> Dictionary:
	var key: Vector2i = simulation._cell_from_position(position)
	if not simulation.sawmill_stocks.has(key):
		simulation.sawmill_stocks[key] = SawmillRules.new_stock(now_seconds)
	return simulation.sawmill_stocks[key]


func store(position: Vector3, stock: Dictionary) -> void:
	simulation.sawmill_stocks[simulation._cell_from_position(position)] = stock


func accept_logs(worker: Citizen, position: Vector3, amount: int, now_seconds: float) -> void:
	var stock := stock_at(position, now_seconds)
	stock.logs = int(stock.logs) + amount
	store(position, stock)
	decide_delivery(worker, position, now_seconds)


func tick(delta: float, now_seconds: float) -> void:
	for position: Vector3 in simulation.sawmill_positions:
		var stock := SawmillRules.advance(stock_at(position, now_seconds), delta, simulation.SAWMILL_PROCESS_DURATION)
		store(position, stock)


func decide_delivery(worker: Citizen, position: Vector3, now_seconds: float) -> void:
	# Boards remain at the sawmill until a courier collects them.
	if worker.permanent_role == "forestry":
		worker.idle()
		return
	simulation._assign_next_forestry_tree(worker)


func collect_boards(courier: Citizen, position: Vector3, now_seconds: float) -> void:
	var stock := stock_at(position, now_seconds)
	var amount := mini(int(stock.boards), courier.courier_capacity())
	stock.boards = int(stock.boards) - amount
	stock.last_courier_pickup = now_seconds
	store(position, stock)
	courier.collect_sawmill_boards(amount)


func position_with_boards(now_seconds: float) -> Vector3:
	var best_position := Vector3.INF
	var highest_board_count := 0
	for position: Vector3 in simulation.sawmill_positions:
		var board_count := int(stock_at(position, now_seconds).boards)
		if board_count > highest_board_count:
			highest_board_count = board_count
			best_position = position
	return best_position
