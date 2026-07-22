class_name SawmillService
extends RefCounted

var _sawmill_stocks: Dictionary = {}
var _sawmill_positions: Array[Vector3] = []
var _process_duration: float = 4.0
var _cell_from_position: Callable = Callable()


func configure(stocks: Dictionary, positions: Array[Vector3], process_duration: float, cell_from_position: Callable) -> void:
	_sawmill_stocks = stocks
	_sawmill_positions = positions
	_process_duration = process_duration
	_cell_from_position = cell_from_position


func stock_at(position: Vector3, now_seconds: float) -> Dictionary:
	var key: Vector2i = _cell_from_position.call(position)
	if not _sawmill_stocks.has(key):
		_sawmill_stocks[key] = SawmillRules.new_stock(now_seconds)
	return _sawmill_stocks[key]


func store(position: Vector3, stock: Dictionary) -> void:
	_sawmill_stocks[_cell_from_position.call(position)] = stock


func accept_logs(worker: Citizen, position: Vector3, amount: int, now_seconds: float) -> void:
	var stock := stock_at(position, now_seconds)
	stock.logs = int(stock.logs) + amount
	store(position, stock)
	decide_delivery(worker, position, now_seconds)


func tick(delta: float, now_seconds: float) -> void:
	for position: Vector3 in _sawmill_positions:
		var stock := SawmillRules.advance(stock_at(position, now_seconds), delta, _process_duration)
		store(position, stock)


func decide_delivery(worker: Citizen, position: Vector3, now_seconds: float) -> void:
	# Boards remain at the sawmill until a courier collects them.
	worker.idle()


func collect_boards(courier: Citizen, position: Vector3, now_seconds: float) -> void:
	var stock := stock_at(position, now_seconds)
	var amount := mini(int(stock.boards), courier.courier_capacity())
	stock.boards = int(stock.boards) - amount
	stock.last_courier_pickup = now_seconds
	store(position, stock)
	courier.collect_sawmill_boards(amount)


func return_boards(position: Vector3, amount: int, now_seconds: float) -> void:
	if amount <= 0:
		return
	var stock := stock_at(position, now_seconds)
	stock.boards = int(stock.boards) + amount
	store(position, stock)


func position_with_boards(now_seconds: float) -> Vector3:
	var best_position := Vector3.INF
	var highest_board_count := 0
	for position: Vector3 in _sawmill_positions:
		var board_count := int(stock_at(position, now_seconds).boards)
		if board_count > highest_board_count:
			highest_board_count = board_count
			best_position = position
	return best_position
