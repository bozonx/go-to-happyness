class_name SawmillService
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func stock_at(position: Vector3) -> Dictionary:
	var key: Vector2i = simulation._cell_from_position(position)
	if not simulation.sawmill_stocks.has(key):
		simulation.sawmill_stocks[key] = {"logs": 0, "boards": 0, "process_time": 0.0, "last_courier_pickup": Time.get_ticks_msec() / 1000.0}
	return simulation.sawmill_stocks[key]


func store(position: Vector3, stock: Dictionary) -> void:
	simulation.sawmill_stocks[simulation._cell_from_position(position)] = stock


func accept_logs(worker: Citizen, position: Vector3, amount: int) -> void:
	var stock := stock_at(position)
	stock.logs = int(stock.logs) + amount
	store(position, stock)
	decide_delivery(worker, position)


func tick(delta: float) -> void:
	for position: Vector3 in simulation.sawmill_positions:
		var stock := stock_at(position)
		if int(stock.logs) <= 0:
			stock.process_time = 0.0
			store(position, stock)
			continue
		if float(stock.process_time) <= 0.0:
			stock.process_time = simulation.SAWMILL_PROCESS_DURATION
		stock.process_time = float(stock.process_time) - delta
		if float(stock.process_time) <= 0.0:
			stock.logs = int(stock.logs) - 1
			stock.boards = int(stock.boards) + 1
			stock.process_time = simulation.SAWMILL_PROCESS_DURATION if int(stock.logs) > 0 else 0.0
		store(position, stock)


func decide_delivery(worker: Citizen, position: Vector3) -> void:
	var stock := stock_at(position)
	var boards := int(stock.boards)
	var courier_late: bool = Time.get_ticks_msec() / 1000.0 - float(stock.last_courier_pickup) >= simulation.COURIER_LATE_SECONDS
	if boards > 0 and (not simulation._has_courier() or (boards >= simulation.SAWMILL_WORKER_DELIVERY_THRESHOLD and courier_late)):
		var amount := mini(boards, simulation.SAWMILL_WORKER_DELIVERY_THRESHOLD)
		stock.boards = boards - amount
		store(position, stock)
		worker.deliver_sawmill_boards(amount)
		return
	simulation._assign_next_forestry_tree(worker)


func collect_boards(courier: Citizen, position: Vector3) -> void:
	var stock := stock_at(position)
	var amount := int(stock.boards)
	stock.boards = 0
	stock.last_courier_pickup = Time.get_ticks_msec() / 1000.0
	store(position, stock)
	courier.collect_sawmill_boards(amount)


func position_with_boards() -> Vector3:
	var best_position := Vector3.INF
	var highest_board_count := 0
	for position: Vector3 in simulation.sawmill_positions:
		var board_count := int(stock_at(position).boards)
		if board_count > highest_board_count:
			highest_board_count = board_count
			best_position = position
	return best_position
