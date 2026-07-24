class_name SettlementUICallbacks
extends RefCounted

## Thin UI signal delegates extracted from SettlementGame.
## Each method forwards to the appropriate controller or service on the game instance.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func resolve_event_decision(choice_index: int) -> void:
	if game.survival_event_controller != null:
		game.survival_event_controller.resolve_event_decision(choice_index)


func toggle_school_development(role: String, pressed: bool) -> void:
	if game.school_menu_controller != null:
		game.school_menu_controller.toggle_school_development(role, pressed)


func start_school_training(role: String) -> void:
	if game.school_menu_controller != null:
		game.school_menu_controller.start_school_training(role)


func update_entrance_order_total(_value := 0.0) -> void:
	if game.entrance_menu_controller != null:
		game.entrance_menu_controller.update_entrance_order_total(_value)


func send_entrance_order() -> void:
	if game.entrance_menu_controller != null:
		game.entrance_menu_controller.send_entrance_order()


func hide_research_menu() -> void:
	if game.research_menu_controller != null:
		game.research_menu_controller.hide_research_menu()


func start_research(tech_id: String) -> void:
	if game.research_menu_controller != null:
		game.research_menu_controller.start_research(tech_id)


func cancel_research() -> void:
	if game.research_menu_controller != null:
		game.research_menu_controller.cancel_research()


func show_campfire_story_menu() -> void:
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.show_campfire_story_menu()


func close_campfire_story_menu() -> void:
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.close_campfire_story_menu()


func select_campfire_story(story_id: String) -> void:
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.select_campfire_story(story_id)


func close_campfire_orders_menu() -> void:
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.close_campfire_orders_menu()
	game.ui_manager.campfire_menu.visible = true


func set_balanced_warehouse_mode(enabled: bool) -> void:
	game.storage_routing_service.set_balanced_warehouse_mode(enabled)


func show_workforce_menu() -> void:
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.show_workforce_menu()


func close_workforce_menu() -> void:
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.close_workforce_menu()


func remove_worker_from_role(role: String) -> void:
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.remove_worker_from_role(role)


func enable_auto_for_citizen(citizen: Citizen) -> void:
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.enable_auto_for_citizen(citizen)


func buy_food(quantity: int, unit_price: int) -> void:
	game.trade_service.buy_food(quantity, unit_price)


func sell_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	game.trade_service.sell_resource(resource_type, quantity, unit_price)


func buy_tool(tool_id: String, price: int) -> void:
	game.trade_service.buy_tool(tool_id, price)


func buy_courier_equipment(courier: Citizen, equipment_id: String, price: int) -> void:
	game.trade_service.buy_courier_equipment(courier, equipment_id, price)


func toggle_warehouse_accept(accepted: bool, resource_type: String) -> void:
	if game.warehouse_menu_controller != null:
		game.warehouse_menu_controller.toggle_warehouse_accept(accepted, resource_type)


func dump_warehouse_resource(resource_type: String) -> void:
	if game.warehouse_menu_controller != null:
		game.warehouse_menu_controller.dump_warehouse_resource(resource_type)


func cover_warehouse_with_tarp() -> void:
	if game.warehouse_menu_controller != null:
		game.warehouse_menu_controller.cover_warehouse_with_tarp()
