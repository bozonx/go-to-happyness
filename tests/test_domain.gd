extends SceneTree


func _init() -> void:
	_test_settlement_economy()
	_test_clock_wraps_and_reports_elapsed_minutes()
	quit(0)


func _test_settlement_economy() -> void:
	var state := SettlementState.new()
	assert(state.can_afford_building("warehouse"))
	assert(state.pay_for_building("warehouse"))
	assert(state.wood == 20)
	assert(not state.can_afford_building("city_hall"))
	state.bricks = 35
	assert(state.pay_for_building("city_hall"))
	assert(state.bricks == 0)
	state.bricks = 15
	state.boards = 10
	assert(state.can_afford_research("brick_construction"))
	assert(state.pay_for_research("brick_construction"))
	assert(state.bricks == 0 and state.boards == 0)


func _test_clock_wraps_and_reports_elapsed_minutes() -> void:
	var clock := SimulationClock.new()
	clock.minutes = 1439.0
	assert(clock.advance(0.0, 1.0).is_empty())
	var elapsed := clock.advance(2.0, 1.0)
	assert(elapsed.size() == 2)
	assert(elapsed[0] == 0 and elapsed[1] == 1)
	assert(clock.hour() == 0 and clock.minute() == 1)
