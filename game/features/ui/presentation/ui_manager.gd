class_name UIManager
extends CanvasLayer

const ContextMenuPanelScene = preload("res://game/features/ui/presentation/context_menu_panel.tscn")

var simulation: Node

@onready var hud: HUD = $HUD
@onready var message_log_panel: MessageLogPanel = $MessageLogPanel
@onready var time_controls_panel: TimeControlsPanel = $TimeControlsPanel
@onready var interaction_hint_panel: Control = $InteractionHintPanel
@onready var crosshair: FirstPersonCrosshair = $FirstPersonCrosshair

@onready var build_menu: BuildMenu = $BuildMenu
@onready var entrance_menu: Panel = $EntranceMenu
@onready var house_menu: Panel = $HouseMenu
@onready var school_menu: Panel = $SchoolMenu
@onready var materials_factory_menu: Panel = $MaterialsFactoryMenu
@onready var campfire_menu: CampfireMenu = $CampfireMenu
@onready var campfire_story_menu: Control = $CampfireStoryMenu
@onready var market_menu: MarketMenu = $MarketMenu
@onready var warehouse_menu: WarehouseMenu = $WarehouseMenu
@onready var pocket_take_menu: PocketTakeMenu = $PocketTakeMenu
@onready var building_menu: Panel = $BuildingMenu
@onready var workforce_menu: WorkforceMenu = $WorkforceMenu
@onready var research_menu: ResearchMenu = $ResearchMenu
@onready var campfire_orders_menu: CampfireOrdersMenu = $CampfireOrdersMenu
@onready var decision_menu: Control = $SurvivalDecisionPanel

var build_toggle_btn: Button
var message_panel: Control
var messages_modal: Control
var house_menu_title: Label
var house_spawn_button: Button
var entrance_menu_title: Label
var entrance_work_button: Button
var entrance_order_modal: Panel
var entrance_order_food_spin: SpinBox
var entrance_order_water_spin: SpinBox
var entrance_order_gloves_spin: SpinBox
var entrance_order_bucket_spin: SpinBox
var entrance_order_total_label: Label
var materials_factory_menu_title: Label
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
var building_cancel_construction_button: Button
var pocket_take_menu_title: Label


func setup(p_simulation: Node) -> void:
	simulation = p_simulation


func create_interface() -> void:
	if hud != null:
		build_toggle_btn = hud.build_toggle_btn
		if simulation != null and simulation.has_method("_toggle_global_build_menu"):
			build_toggle_btn.pressed.connect(Callable(simulation, "_toggle_global_build_menu"))

	_create_message_panel()
	_create_messages_modal()
	_create_time_controls()

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
	pass


func _create_messages_modal() -> void:
	pass


func _create_time_controls() -> void:
	if time_controls_panel != null and simulation != null:
		time_controls_panel.skip_night_requested.connect(Callable(simulation, "_skip_night"))
		time_controls_panel.skip_to_workday_start_requested.connect(Callable(simulation, "_skip_to_workday_start"))
		time_controls_panel.time_multiplier_changed.connect(Callable(simulation, "_set_time_multiplier"))


func _create_build_menu() -> void:
	if build_menu != null:
		build_menu.gui_input_received.connect(Callable(simulation, "_on_build_menu_gui_input"))
		build_menu.manage_citizen_pressed.connect(Callable(simulation, "_take_control_of_selected_citizen"))
		build_menu.daily_order_submenu_requested.connect(Callable(simulation, "_open_daily_order_submenu"))
		build_menu.personal_night_work_toggled.connect(Callable(simulation, "_toggle_selected_citizen_night_work"))
		build_menu.job_submenu_requested.connect(Callable(simulation, "_open_job_submenu"))
		build_menu.category_opened.connect(Callable(simulation, "_open_build_category"))
		build_menu.build_selected.connect(Callable(simulation, "_select_build_mode"))
		build_menu.role_selected.connect(Callable(simulation, "_set_selected_work_role"))
		if simulation != null and simulation.has_method("_refresh_build_menu"):
			simulation._refresh_build_menu()


func _create_entrance_menu() -> void:
	if entrance_menu != null:
		var menu: EntranceMenu = entrance_menu as EntranceMenu
		if menu != null:
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
	if house_menu != null:
		var menu: HouseMenu = house_menu as HouseMenu
		if menu != null:
			house_menu_title = menu.title_label
			house_spawn_button = menu.spawn_button
			house_spawn_button.pressed.connect(Callable(simulation, "_spawn_house_citizen"))
			menu.demolish_button.pressed.connect(func(): if simulation != null: simulation._mark_building_for_demolition(simulation.selected_house))


func _create_school_menu() -> void:
	if school_menu != null:
		var menu: SchoolMenu = school_menu as SchoolMenu
		if menu != null:
			menu.train_requested.connect(Callable(simulation, "_start_school_training"))
			menu.dev_toggled.connect(Callable(simulation, "_toggle_school_development"))
			menu.demolish_requested.connect(func():
				if simulation != null and simulation.selected_school != null:
					simulation._mark_building_for_demolition(simulation.selected_school)
					school_menu.visible = false
			)


func _create_materials_factory_menu() -> void:
	if materials_factory_menu != null:
		var menu: MaterialsFactoryMenu = materials_factory_menu as MaterialsFactoryMenu
		if menu != null:
			materials_factory_menu_title = menu.title_label


func _create_campfire_menu() -> void:
	if campfire_menu != null:
		var menu: CampfireMenu = campfire_menu
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
	if campfire_story_menu != null:
		campfire_story_menu.story_selected.connect(Callable(simulation, "_select_campfire_story"))
		campfire_story_menu.close_requested.connect(Callable(simulation, "_close_campfire_story_menu"))


func _create_market_menu() -> void:
	if market_menu != null:
		market_menu.sell_requested.connect(Callable(simulation, "_sell_resource"))
		market_menu.buy_tool_requested.connect(Callable(simulation, "_buy_tool"))
		market_menu.buy_equipment_requested.connect(Callable(simulation, "_buy_courier_equipment"))
		market_menu.buy_food_requested.connect(Callable(simulation, "_buy_food"))
		market_menu.close_requested.connect(Callable(simulation, "_close_context_menus"))


func _create_warehouse_menu() -> void:
	if warehouse_menu != null:
		warehouse_menu.accept_toggled.connect(Callable(simulation, "_toggle_warehouse_accept"))
		warehouse_menu.dump_requested.connect(Callable(simulation, "_dump_warehouse_resource"))
		warehouse_menu.cover_requested.connect(Callable(simulation, "_cover_warehouse_with_tarp"))
		warehouse_menu.demolish_requested.connect(func(): if simulation != null: simulation._mark_building_for_demolition(simulation.selected_warehouse))
		warehouse_menu.close_requested.connect(Callable(simulation, "_close_context_menus"))


func _create_pocket_take_menu() -> void:
	if pocket_take_menu != null:
		var menu: PocketTakeMenu = pocket_take_menu
		pocket_take_menu_title = menu.title_label
		menu.close_requested.connect(Callable(simulation, "_close_pocket_take_menu"))


func _create_building_menu() -> void:
	if building_menu != null:
		var menu: BuildingMenu = building_menu as BuildingMenu
		if menu != null:
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
	if workforce_menu != null:
		workforce_menu.close_requested.connect(Callable(simulation, "_close_workforce_menu"))
		workforce_menu.dismiss_requested.connect(Callable(simulation, "_remove_worker_from_role"))
		workforce_menu.assign_requested.connect(Callable(simulation, "_assign_unemployed_worker"))
		workforce_menu.register_requested.connect(Callable(simulation, "_enable_auto_for_citizen"))


func _create_research_menu() -> void:
	if research_menu != null:
		research_menu.close_requested.connect(Callable(simulation, "_hide_research_menu"))
		research_menu.start_requested.connect(Callable(simulation, "_start_research"))
		research_menu.cancel_requested.connect(Callable(simulation, "_cancel_research"))


func _create_campfire_orders_menu() -> void:
	if campfire_orders_menu != null:
		campfire_orders_menu.road_walking_toggled.connect(Callable(simulation, "_set_road_walking_order"))
		campfire_orders_menu.balanced_warehouse_toggled.connect(Callable(simulation, "_set_balanced_warehouse_mode"))
		campfire_orders_menu.night_work_toggled.connect(Callable(simulation, "_toggle_settlement_night_work"))
		campfire_orders_menu.double_time_toggled.connect(Callable(simulation, "_toggle_double_time_order"))
		campfire_orders_menu.cheer_pressed.connect(Callable(simulation, "_cheer_up_settlement"))
		campfire_orders_menu.close_requested.connect(Callable(simulation, "_close_campfire_orders_menu"))


func _create_survival_decision_menu() -> void:
	if decision_menu != null:
		if simulation != null and simulation.has_method("_resolve_event_decision"):
			decision_menu.choice_selected.connect(Callable(simulation, "_resolve_event_decision"))


func _create_crosshair() -> void:
	if crosshair != null:
		crosshair.visible = false
