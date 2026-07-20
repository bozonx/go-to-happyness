class_name UIManager
extends CanvasLayer

const FirstPersonCrosshairScene = preload("res://game/features/ui/presentation/first_person_crosshair.tscn")
const TimeControlsPanelScene = preload("res://game/features/ui/presentation/time_controls_panel.tscn")
const MessageLogPanelScene = preload("res://game/features/ui/presentation/message_log_panel.tscn")
const InteractionHintPanelScene = preload("res://game/features/ui/presentation/interaction_hint_panel.tscn")
const SurvivalDecisionPanelScene = preload("res://game/features/settlement/presentation/survival_decision_panel.tscn")
const CampfireStoryMenuScene = preload("res://game/features/settlement/presentation/campfire_story_menu.tscn")
const CampfireOrdersMenuScene = preload("res://game/features/settlement/presentation/campfire_orders_menu.tscn")
const ResearchMenuScene = preload("res://game/features/settlement/presentation/research_menu.tscn")
const WorkforceMenuScene = preload("res://game/features/decision/presentation/workforce_menu.tscn")
const PocketTakeMenuScene = preload("res://game/features/citizens/presentation/pocket_take_menu.tscn")
const HUDScene = preload("res://game/features/ui/presentation/hud.tscn")
const BuildMenuScene = preload("res://game/features/buildings/presentation/build_menu.tscn")
const BuildingMenuScene = preload("res://game/features/buildings/presentation/building_menu.tscn")
const HouseMenuScene = preload("res://game/features/buildings/presentation/house_menu.tscn")
const SchoolMenuScene = preload("res://game/features/buildings/presentation/school_menu.tscn")
const CampfireMenuScene = preload("res://game/features/buildings/presentation/campfire_menu.tscn")
const WarehouseMenuScene = preload("res://game/features/logistics/presentation/warehouse_menu.tscn")
const MarketMenuScene = preload("res://game/features/logistics/presentation/market_menu.tscn")
const MaterialsFactoryMenuScene = preload("res://game/features/production/presentation/materials_factory_menu.tscn")
const EntranceMenuScene = preload("res://game/features/settlement/presentation/entrance_menu.tscn")
const ContextMenuPanelScene = preload("res://game/features/ui/presentation/context_menu_panel.tscn")

var simulation: Node

var hud: HUD
var build_toggle_btn: Button
var message_panel: Control
var message_log_panel: MessageLogPanel
var messages_modal: Control
var interaction_hint_panel: Control
var build_menu: BuildMenu
var house_menu: Panel
var house_menu_title: Label
var house_spawn_button: Button
var entrance_menu: Panel
var entrance_menu_title: Label
var entrance_work_button: Button
var entrance_order_modal: Panel
var entrance_order_food_spin: SpinBox
var entrance_order_water_spin: SpinBox
var entrance_order_gloves_spin: SpinBox
var entrance_order_bucket_spin: SpinBox
var entrance_order_total_label: Label
var school_menu: Panel
var materials_factory_menu: Panel
var materials_factory_menu_title: Label
var campfire_menu: CampfireMenu
var workforce_menu: WorkforceMenu
var research_menu: ResearchMenu
var market_menu: MarketMenu
var warehouse_menu: WarehouseMenu
var building_menu: Panel
var building_menu_title: Label
var building_cook_button: Button
var building_teacher_button: Button
var building_seller_button: Button
var building_accept_workers_button: Button
var building_dismiss_worker_button: Button
var building_upgrade_button: Button
var building_demolish_button: Button
var building_close_button: Button
var building_overtime_button: CheckButton
var building_relight_button: Button
var campfire_story_menu: Control
var building_cancel_construction_button: Button
var decision_menu: Control
var time_controls_panel: TimeControlsPanel
var pocket_take_menu: PocketTakeMenu
var pocket_take_menu_title: Label
var campfire_orders_menu: CampfireOrdersMenu
var crosshair: FirstPersonCrosshair


func setup(p_simulation: Node) -> void:
	simulation = p_simulation


func create_interface() -> void:
	hud = HUDScene.instantiate()
	add_child(hud)
	build_toggle_btn = hud.build_toggle_btn
	if simulation != null and simulation.has_method("_toggle_global_build_menu"):
		build_toggle_btn.pressed.connect(Callable(simulation, "_toggle_global_build_menu"))

	_create_message_panel()
	_create_messages_modal()
	_create_time_controls()

	interaction_hint_panel = InteractionHintPanelScene.instantiate()
	add_child(interaction_hint_panel)

	_create_build_menu()
	_create_entrance_menu()
	_create_house_menu()
	_create_school_menu()
	_create_materials_factory_menu()
	_create_campfire_menu()
	_create_campfire_story_menu()
	_create_market_menu()
	_create_warehouse_menu()
	_create_pocket_take_menu()
	_create_building_menu()
	_create_workforce_menu()
	_create_research_menu()
	_create_campfire_orders_menu()
	_create_survival_decision_menu()
	_create_crosshair()


func create_context_menu_panel(anchor: int, offsets: Vector4, input_handler: Callable) -> Panel:
	var panel := ContextMenuPanelScene.instantiate() as Panel
	panel.set_anchors_preset(anchor)
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	panel.visible = false
	panel.gui_input.connect(input_handler)
	add_child(panel)
	return panel


func _create_message_panel() -> void:
	message_log_panel = MessageLogPanelScene.instantiate()
	add_child(message_log_panel)


func _create_messages_modal() -> void:
	pass


func _create_time_controls() -> void:
	time_controls_panel = TimeControlsPanelScene.instantiate()
	add_child(time_controls_panel)
	time_controls_panel.skip_night_requested.connect(Callable(simulation, "_skip_night"))
	time_controls_panel.skip_to_workday_start_requested.connect(Callable(simulation, "_skip_to_workday_start"))
	time_controls_panel.time_multiplier_changed.connect(Callable(simulation, "_set_time_multiplier"))


func _create_build_menu() -> void:
	var menu: BuildMenu = BuildMenuScene.instantiate()
	add_child(menu)
	build_menu = menu
	menu.gui_input_received.connect(Callable(simulation, "_on_build_menu_gui_input"))
	menu.manage_citizen_pressed.connect(Callable(simulation, "_take_control_of_selected_citizen"))
	menu.daily_order_submenu_requested.connect(Callable(simulation, "_open_daily_order_submenu"))
	menu.personal_night_work_toggled.connect(Callable(simulation, "_toggle_selected_citizen_night_work"))
	menu.job_submenu_requested.connect(Callable(simulation, "_open_job_submenu"))
	menu.category_opened.connect(Callable(simulation, "_open_build_category"))
	menu.build_selected.connect(Callable(simulation, "_select_build_mode"))
	menu.role_selected.connect(Callable(simulation, "_set_selected_work_role"))
	if simulation != null and simulation.has_method("_refresh_build_menu"):
		simulation._refresh_build_menu()


func _create_entrance_menu() -> void:
	var menu: EntranceMenu = EntranceMenuScene.instantiate()
	add_child(menu)
	entrance_menu = menu
	entrance_menu_title = menu.title_label
	entrance_work_button = menu.entrance_work_button
	entrance_order_modal = menu.entrance_order_modal
	entrance_order_food_spin = menu.entrance_order_food_spin
	entrance_order_water_spin = menu.entrance_order_water_spin
	entrance_order_gloves_spin = menu.entrance_order_gloves_spin
	entrance_order_bucket_spin = menu.entrance_order_bucket_spin
	entrance_order_total_label = menu.entrance_order_total_label
	menu.modal_gui_input_received.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			entrance_order_modal.visible = false
	)
	menu.get_node("CreateOrderButton").pressed.connect(Callable(simulation, "_show_entrance_order_modal"))
	entrance_work_button.pressed.connect(Callable(simulation, "_send_selected_resident_to_outside_work"))
	menu.get_node("CloseButton").pressed.connect(Callable(simulation, "_close_context_menus"))
	entrance_order_food_spin.value_changed.connect(Callable(simulation, "_update_entrance_order_total"))
	entrance_order_water_spin.value_changed.connect(Callable(simulation, "_update_entrance_order_total"))
	entrance_order_gloves_spin.value_changed.connect(Callable(simulation, "_update_entrance_order_total"))
	entrance_order_bucket_spin.value_changed.connect(Callable(simulation, "_update_entrance_order_total"))
	entrance_order_modal.get_node("SendButton").pressed.connect(Callable(simulation, "_send_entrance_order"))
	entrance_order_modal.get_node("CloseButton").pressed.connect(Callable(simulation, "_hide_entrance_order_modal"))


func _create_house_menu() -> void:
	var menu: HouseMenu = HouseMenuScene.instantiate()
	add_child(menu)
	house_menu = menu
	house_menu_title = menu.title_label
	house_spawn_button = menu.spawn_button
	house_spawn_button.pressed.connect(Callable(simulation, "_spawn_house_citizen"))
	menu.demolish_button.pressed.connect(func(): simulation._mark_building_for_demolition(simulation.selected_house))


func _create_school_menu() -> void:
	var menu: SchoolMenu = SchoolMenuScene.instantiate()
	add_child(menu)
	school_menu = menu
	menu.train_requested.connect(Callable(simulation, "_start_school_training"))
	menu.dev_toggled.connect(Callable(simulation, "_toggle_school_development"))
	menu.demolish_requested.connect(func():
		if simulation.selected_school != null:
			simulation._mark_building_for_demolition(simulation.selected_school)
			school_menu.visible = false
	)


func _create_materials_factory_menu() -> void:
	var menu: MaterialsFactoryMenu = MaterialsFactoryMenuScene.instantiate()
	add_child(menu)
	materials_factory_menu = menu
	materials_factory_menu_title = menu.title_label


func _create_campfire_menu() -> void:
	var menu: CampfireMenu = CampfireMenuScene.instantiate()
	add_child(menu)
	campfire_menu = menu
	menu.workday_hours_changed.connect(Callable(simulation, "_set_workday_hours"))
	menu.advance_button.pressed.connect(Callable(simulation, "_on_campfire_advance_pressed"))
	menu.orders_button.pressed.connect(Callable(simulation, "_show_campfire_orders_menu"))
	menu.upgrade_button.pressed.connect(Callable(simulation, "_handle_campfire_primary_action"))
	menu.occupancy_button.pressed.connect(Callable(simulation, "_show_workforce_menu"))
	menu.research_button.pressed.connect(Callable(simulation, "_show_research_menu"))
	menu.research_post_button.pressed.connect(Callable(simulation, "_handle_civic_post_assignment"))
	menu.occupy_position_button.pressed.connect(Callable(simulation, "_occupy_selected_campfire_position"))
	menu.accept_button.pressed.connect(Callable(simulation, "_toggle_campfire_acceptance"))
	menu.dismiss_button.pressed.connect(Callable(simulation, "_dismiss_campfire_worker"))
	menu.overtime_button.toggled.connect(Callable(simulation, "_toggle_campfire_worker_overtime"))
	menu.close_btn.pressed.connect(Callable(simulation, "_close_context_menus"))
	menu.story_button.pressed.connect(Callable(simulation, "_show_campfire_story_menu"))


func _create_campfire_story_menu() -> void:
	campfire_story_menu = CampfireStoryMenuScene.instantiate()
	add_child(campfire_story_menu)
	campfire_story_menu.story_selected.connect(Callable(simulation, "_select_campfire_story"))
	campfire_story_menu.close_requested.connect(Callable(simulation, "_close_campfire_story_menu"))


func _create_market_menu() -> void:
	var menu: MarketMenu = MarketMenuScene.instantiate()
	add_child(menu)
	market_menu = menu
	market_menu.sell_requested.connect(Callable(simulation, "_sell_resource"))
	market_menu.buy_tool_requested.connect(Callable(simulation, "_buy_tool"))
	market_menu.buy_equipment_requested.connect(Callable(simulation, "_buy_courier_equipment"))
	market_menu.buy_food_requested.connect(Callable(simulation, "_buy_food"))
	market_menu.close_requested.connect(Callable(simulation, "_close_context_menus"))


func _create_warehouse_menu() -> void:
	var menu: WarehouseMenu = WarehouseMenuScene.instantiate()
	add_child(menu)
	warehouse_menu = menu
	warehouse_menu.accept_toggled.connect(Callable(simulation, "_toggle_warehouse_accept"))
	warehouse_menu.dump_requested.connect(Callable(simulation, "_dump_warehouse_resource"))
	warehouse_menu.cover_requested.connect(Callable(simulation, "_cover_warehouse_with_tarp"))
	warehouse_menu.demolish_requested.connect(func(): simulation._mark_building_for_demolition(simulation.selected_warehouse))
	warehouse_menu.close_requested.connect(Callable(simulation, "_close_context_menus"))


func _create_pocket_take_menu() -> void:
	var menu: PocketTakeMenu = PocketTakeMenuScene.instantiate()
	add_child(menu)
	pocket_take_menu = menu
	pocket_take_menu_title = menu.title_label
	menu.close_requested.connect(Callable(simulation, "_close_pocket_take_menu"))


func _create_building_menu() -> void:
	var menu: BuildingMenu = BuildingMenuScene.instantiate()
	add_child(menu)
	building_menu = menu
	building_menu_title = menu.title_label
	building_cook_button = menu.cook_button
	building_teacher_button = menu.teacher_button
	building_seller_button = menu.seller_button
	building_accept_workers_button = menu.accept_workers_button
	building_dismiss_worker_button = menu.dismiss_worker_button
	building_overtime_button = menu.overtime_button
	building_relight_button = menu.relight_button
	building_upgrade_button = menu.upgrade_button
	building_demolish_button = menu.demolish_button
	building_close_button = menu.close_button
	building_cancel_construction_button = menu.cancel_construction_button
	building_cook_button.pressed.connect(Callable(simulation, "_assign_cook_at_campfire"))
	building_teacher_button.pressed.connect(Callable(simulation, "_assign_teacher_at_school"))
	building_seller_button.pressed.connect(Callable(simulation, "_assign_seller_at_market"))
	building_accept_workers_button.pressed.connect(Callable(simulation, "_toggle_selected_workplace_acceptance"))
	building_dismiss_worker_button.pressed.connect(Callable(simulation, "_dismiss_selected_workplace_worker"))
	building_overtime_button.toggled.connect(Callable(simulation, "_toggle_worker_overtime"))
	building_relight_button.pressed.connect(Callable(simulation, "_relight_selected_fire"))
	building_upgrade_button.pressed.connect(Callable(simulation, "_upgrade_selected_building"))
	building_demolish_button.pressed.connect(Callable(simulation, "_demolish_selected_building"))
	building_close_button.pressed.connect(Callable(simulation, "_close_context_menus"))
	building_cancel_construction_button.pressed.connect(Callable(simulation, "_cancel_selected_construction"))


func _create_workforce_menu() -> void:
	workforce_menu = WorkforceMenuScene.instantiate()
	add_child(workforce_menu)
	workforce_menu.close_requested.connect(Callable(simulation, "_close_workforce_menu"))
	workforce_menu.dismiss_requested.connect(Callable(simulation, "_remove_worker_from_role"))
	workforce_menu.assign_requested.connect(Callable(simulation, "_assign_unemployed_worker"))
	workforce_menu.register_requested.connect(Callable(simulation, "_enable_auto_for_citizen"))


func _create_research_menu() -> void:
	research_menu = ResearchMenuScene.instantiate()
	add_child(research_menu)
	research_menu.close_requested.connect(Callable(simulation, "_hide_research_menu"))
	research_menu.start_requested.connect(Callable(simulation, "_start_research"))
	research_menu.cancel_requested.connect(Callable(simulation, "_cancel_research"))


func _create_campfire_orders_menu() -> void:
	campfire_orders_menu = CampfireOrdersMenuScene.instantiate()
	add_child(campfire_orders_menu)
	campfire_orders_menu.road_walking_toggled.connect(Callable(simulation, "_set_road_walking_order"))
	campfire_orders_menu.balanced_warehouse_toggled.connect(Callable(simulation, "_set_balanced_warehouse_mode"))
	campfire_orders_menu.night_work_toggled.connect(Callable(simulation, "_toggle_settlement_night_work"))
	campfire_orders_menu.double_time_toggled.connect(Callable(simulation, "_toggle_double_time_order"))
	campfire_orders_menu.cheer_pressed.connect(Callable(simulation, "_cheer_up_settlement"))
	campfire_orders_menu.close_requested.connect(Callable(simulation, "_close_campfire_orders_menu"))


func _create_survival_decision_menu() -> void:
	decision_menu = SurvivalDecisionPanelScene.instantiate()
	add_child(decision_menu)
	if simulation != null and simulation.has_method("_resolve_event_decision"):
		decision_menu.choice_selected.connect(Callable(simulation, "_resolve_event_decision"))


func _create_crosshair() -> void:
	crosshair = FirstPersonCrosshairScene.instantiate()
	crosshair.visible = false
	add_child(crosshair)
