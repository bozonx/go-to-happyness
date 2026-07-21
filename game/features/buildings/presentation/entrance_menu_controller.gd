class_name EntranceMenuController
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_entrance_menu() -> void:
	if simulation == null or not is_instance_valid(simulation.selected_entrance):
		return
	var resident_name: String = simulation.selected_builder.role_label() if is_instance_valid(simulation.selected_builder) else "no resident selected"
	simulation.entrance_menu_title.text = "Entrance sign\nEmergency orders. Outside work: %s" % resident_name
	if is_instance_valid(simulation.entrance_work_button):
		simulation.entrance_work_button.tooltip_text = "Requires a Courier. The resident leaves for one full day and returns with %s coins." % outside_work_reward_text()
	if simulation.entrance_highlight != null:
		simulation.entrance_highlight.visible = true
	simulation.entrance_menu.visible = true


func show_entrance_order_modal() -> void:
	simulation.entrance_menu.visible = false
	simulation.entrance_order_modal.visible = true
	update_entrance_order_total()


func hide_entrance_order_modal() -> void:
	simulation.entrance_order_modal.visible = false
	simulation.entrance_menu.visible = true


func update_entrance_order_total(_value := 0.0) -> void:
	var total: int = (
		int(simulation.entrance_order_food_spin.value) * simulation.FOOD_PURCHASE_PRICE
		+ int(simulation.entrance_order_water_spin.value) * simulation.ENTRANCE_WATER_PRICE
		+ int(simulation.entrance_order_gloves_spin.value) * simulation.ENTRANCE_GLOVE_PRICE
		+ int(simulation.entrance_order_bucket_spin.value) * simulation.ENTRANCE_BUCKET_PRICE
	)
	var available: int = simulation.trade_service.available_trade_money()
	simulation.entrance_order_total_label.text = "Total: %d / %d coins" % [total, available]


func send_entrance_order() -> void:
	var food := int(simulation.entrance_order_food_spin.value)
	var water := int(simulation.entrance_order_water_spin.value)
	var gloves := int(simulation.entrance_order_gloves_spin.value)
	var bucket := int(simulation.entrance_order_bucket_spin.value)
	var total: int = (
		food * simulation.FOOD_PURCHASE_PRICE
		+ water * simulation.ENTRANCE_WATER_PRICE
		+ gloves * simulation.ENTRANCE_GLOVE_PRICE
		+ bucket * simulation.ENTRANCE_BUCKET_PRICE
	)
	if total <= 0:
		return
	if total > simulation.trade_service.available_trade_money():
		simulation._update_interface("Not enough available coins for this order.")
		return
	if food > 0:
		simulation.trade_service.buy_entrance_food(food, simulation.FOOD_PURCHASE_PRICE)
	for _i in range(gloves):
		simulation.trade_service.buy_entrance_gloves(simulation.ENTRANCE_GLOVE_PRICE)
	if water > 0:
		simulation.trade_service.buy_entrance_resource("water", water, simulation.ENTRANCE_WATER_PRICE)
	for _i in range(bucket):
		simulation.trade_service.buy_entrance_tool("bucket", simulation.ENTRANCE_BUCKET_PRICE)
	simulation._update_interface("Entrance order placed: %d food, %d water, %d gloves, %d buckets." % [food, water, gloves, bucket])
	hide_entrance_order_modal()


func outside_work_reward_text() -> String:
	if simulation.settlement != null and simulation.settlement.is_research_completed("outside_work_earnings"):
		return "%d" % simulation.OUTSIDE_WORK_UPGRADE_REWARD
	return "%d-%d" % [simulation.OUTSIDE_WORK_BASE_REWARD_MIN, simulation.OUTSIDE_WORK_BASE_REWARD_MAX]
