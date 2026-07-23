class_name UIManager
extends CanvasLayer

const ContextMenuPanelScene = preload("res://game/features/ui/presentation/context_menu_panel.tscn")
const UITheme = preload("res://game/features/ui/presentation/theme/ui_theme.tres")
const UIEvents = preload("res://game/features/ui/application/ui_events.gd")

var simulation: Node
var events: UIEvents = UIEvents.new()


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


func _ready() -> void:
	for child in get_children():
		if child is Control:
			(child as Control).theme = UITheme



func setup(p_simulation: Node) -> void:
	simulation = p_simulation
	if simulation != null:
		bind_events(simulation)


func bind_events(target: Node) -> void:
	_connect_event(events.global_build_menu_toggled, target, "_toggle_global_build_menu")
	_connect_event(events.skip_night_requested, target, "_skip_night")
	_connect_event(events.skip_to_workday_start_requested, target, "_skip_to_workday_start")
	_connect_event(events.time_multiplier_changed, target, "_set_time_multiplier")

	_connect_event(events.build_menu_gui_input, target, "_on_build_menu_gui_input")
	_connect_event(events.manage_citizen_requested, target, "_take_control_of_selected_citizen")
	_connect_event(events.daily_order_submenu_requested, target, "_open_daily_order_submenu")
	_connect_event(events.personal_night_work_toggled, target, "_toggle_selected_citizen_night_work")
	_connect_event(events.job_submenu_requested, target, "_open_job_submenu")
	_connect_event(events.category_opened, target, "_open_build_category")
	_connect_event(events.build_selected, target, "_select_build_mode")
	_connect_event(events.role_selected, target, "_set_selected_work_role")

	_connect_event(events.send_resident_outside_requested, target, "_send_selected_resident_to_outside_work")
	_connect_event(events.send_entrance_order_requested, target, "_send_entrance_order")
	_connect_event(events.context_menus_close_requested, target, "_close_context_menus")
	_connect_event(events.entrance_order_total_update_requested, target, "_update_entrance_order_total")

	_connect_event(events.spawn_house_citizen_requested, target, "_spawn_house_citizen")
	_connect_event(events.house_demolish_requested, target, "_demolish_selected_house")

	_connect_event(events.school_train_requested, target, "_start_school_training")
	_connect_event(events.school_dev_toggled, target, "_toggle_school_development")
	_connect_event(events.school_demolish_requested, target, "_demolish_selected_school")

	_connect_event(events.workday_hours_changed, target, "_set_workday_hours")
	_connect_event(events.campfire_advance_pressed, target, "_on_campfire_advance_pressed")
	_connect_event(events.campfire_orders_menu_show_requested, target, "_show_campfire_orders_menu")
	_connect_event(events.campfire_primary_action_requested, target, "_handle_campfire_primary_action")
	_connect_event(events.workforce_menu_show_requested, target, "_show_workforce_menu")
	_connect_event(events.research_menu_show_requested, target, "_show_research_menu")
	_connect_event(events.civic_post_assignment_requested, target, "_handle_civic_post_assignment")
	_connect_event(events.occupy_campfire_position_requested, target, "_occupy_selected_campfire_position")
	_connect_event(events.campfire_acceptance_toggled, target, "_toggle_campfire_acceptance")
	_connect_event(events.dismiss_campfire_worker_requested, target, "_dismiss_campfire_worker")
	_connect_event(events.campfire_worker_overtime_toggled, target, "_toggle_campfire_worker_overtime")
	_connect_event(events.campfire_story_menu_show_requested, target, "_show_campfire_story_menu")
	_connect_event(events.campfire_story_selected, target, "_select_campfire_story")
	_connect_event(events.campfire_story_menu_close_requested, target, "_close_campfire_story_menu")

	_connect_event(events.sell_resource_requested, target, "_sell_resource")
	_connect_event(events.buy_tool_requested, target, "_buy_tool")
	_connect_event(events.buy_equipment_requested, target, "_buy_courier_equipment")
	_connect_event(events.buy_food_requested, target, "_buy_food")

	_connect_event(events.warehouse_accept_toggled, target, "_toggle_warehouse_accept")
	_connect_event(events.dump_warehouse_resource_requested, target, "_dump_warehouse_resource")
	_connect_event(events.cover_warehouse_requested, target, "_cover_warehouse_with_tarp")
	_connect_event(events.warehouse_demolish_requested, target, "_demolish_selected_warehouse")

	_connect_event(events.pocket_take_menu_close_requested, target, "_close_pocket_take_menu")

	_connect_event(events.cook_assigned, target, "_assign_cook_at_campfire")
	_connect_event(events.teacher_assigned, target, "_assign_teacher_at_school")
	_connect_event(events.seller_assigned, target, "_assign_seller_at_market")
	_connect_event(events.workplace_acceptance_toggled, target, "_toggle_selected_workplace_acceptance")
	_connect_event(events.workplace_worker_dismissed, target, "_dismiss_selected_workplace_worker")
	_connect_event(events.worker_overtime_toggled, target, "_toggle_worker_overtime")
	_connect_event(events.relight_fire_requested, target, "_relight_selected_fire")
	_connect_event(events.upgrade_building_requested, target, "_upgrade_selected_building")
	_connect_event(events.demolish_building_requested, target, "_demolish_selected_building")
	_connect_event(events.cancel_construction_requested, target, "_cancel_selected_construction")

	_connect_event(events.workforce_menu_close_requested, target, "_close_workforce_menu")
	_connect_event(events.remove_worker_role_requested, target, "_remove_worker_from_role")
	_connect_event(events.assign_unemployed_worker_requested, target, "_assign_unemployed_worker")
	_connect_event(events.enable_auto_citizen_requested, target, "_enable_auto_for_citizen")

	_connect_event(events.research_menu_hide_requested, target, "_hide_research_menu")
	_connect_event(events.start_research_requested, target, "_start_research")
	_connect_event(events.cancel_research_requested, target, "_cancel_research")

	_connect_event(events.road_walking_order_set, target, "_set_road_walking_order")
	_connect_event(events.balanced_warehouse_mode_set, target, "_set_balanced_warehouse_mode")
	_connect_event(events.settlement_night_work_toggled, target, "_toggle_settlement_night_work")
	_connect_event(events.double_time_order_toggled, target, "_toggle_double_time_order")
	_connect_event(events.cheer_up_settlement_requested, target, "_cheer_up_settlement")
	_connect_event(events.campfire_orders_menu_close_requested, target, "_close_campfire_orders_menu")

	_connect_event(events.event_decision_choice_selected, target, "_resolve_event_decision")


func _connect_event(sig: Signal, target: Node, method_name: String) -> void:
	if target != null and target.has_method(method_name):
		var callable := Callable(target, method_name)
		if not sig.is_connected(callable):
			sig.connect(callable)


func create_interface() -> void:
	if hud != null:
		build_toggle_btn = hud.build_toggle_btn
		build_toggle_btn.pressed.connect(func(): events.global_build_menu_toggled.emit())

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
	if time_controls_panel != null:
		time_controls_panel.skip_night_requested.connect(func(): events.skip_night_requested.emit())
		time_controls_panel.skip_to_workday_start_requested.connect(func(): events.skip_to_workday_start_requested.emit())
		time_controls_panel.time_multiplier_changed.connect(func(mult: float): events.time_multiplier_changed.emit(mult))


func _create_build_menu() -> void:
	if build_menu != null:
		build_menu.gui_input_received.connect(func(ev): events.build_menu_gui_input.emit(ev))
		build_menu.manage_citizen_pressed.connect(func(): events.manage_citizen_requested.emit())
		build_menu.daily_order_submenu_requested.connect(func(): events.daily_order_submenu_requested.emit())
		build_menu.personal_night_work_toggled.connect(func(): events.personal_night_work_toggled.emit())
		build_menu.job_submenu_requested.connect(func(): events.job_submenu_requested.emit())
		build_menu.category_opened.connect(func(cat): events.category_opened.emit(cat))
		build_menu.build_selected.connect(func(b_id): events.build_selected.emit(b_id))
		build_menu.role_selected.connect(func(r_id, is_daily): events.role_selected.emit(r_id, is_daily))
		if simulation != null:
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

			menu.work_outside_requested.connect(func(): events.send_resident_outside_requested.emit())
			menu.send_order_requested.connect(func(): events.send_entrance_order_requested.emit())
			menu.close_requested.connect(func(): events.context_menus_close_requested.emit())

			entrance_order_food_spin.value_changed.connect(func(_val): events.entrance_order_total_update_requested.emit())
			entrance_order_water_spin.value_changed.connect(func(_val): events.entrance_order_total_update_requested.emit())
			entrance_order_gloves_spin.value_changed.connect(func(_val): events.entrance_order_total_update_requested.emit())
			entrance_order_bucket_spin.value_changed.connect(func(_val): events.entrance_order_total_update_requested.emit())


func _create_house_menu() -> void:
	if house_menu != null:
		var menu: HouseMenu = house_menu as HouseMenu
		if menu != null:
			house_menu_title = menu.title_label
			house_spawn_button = menu.spawn_button
			menu.spawn_requested.connect(func(): events.spawn_house_citizen_requested.emit())
			menu.demolish_requested.connect(func(): events.house_demolish_requested.emit())


func _create_school_menu() -> void:
	if school_menu != null:
		var menu: SchoolMenu = school_menu as SchoolMenu
		if menu != null:
			menu.train_requested.connect(func(): events.school_train_requested.emit())
			menu.dev_toggled.connect(func(): events.school_dev_toggled.emit())
			menu.demolish_requested.connect(func():
				events.school_demolish_requested.emit()
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
		menu.workday_hours_changed.connect(func(h): events.workday_hours_changed.emit(h))
		menu.advance_button.pressed.connect(func(): events.campfire_advance_pressed.emit())
		menu.orders_button.pressed.connect(func(): events.campfire_orders_menu_show_requested.emit())
		menu.upgrade_button.pressed.connect(func(): events.campfire_primary_action_requested.emit())
		menu.occupancy_button.pressed.connect(func(): events.workforce_menu_show_requested.emit())
		menu.research_button.pressed.connect(func(): events.research_menu_show_requested.emit())
		menu.research_post_button.pressed.connect(func(): events.civic_post_assignment_requested.emit())
		menu.occupy_position_button.pressed.connect(func(): events.occupy_campfire_position_requested.emit())
		menu.accept_button.pressed.connect(func(): events.campfire_acceptance_toggled.emit())
		menu.dismiss_button.pressed.connect(func(): events.dismiss_campfire_worker_requested.emit())
		menu.overtime_button.toggled.connect(func(enabled: bool): events.campfire_worker_overtime_toggled.emit(enabled))
		menu.close_btn.pressed.connect(func(): events.context_menus_close_requested.emit())
		menu.story_button.pressed.connect(func(): events.campfire_story_menu_show_requested.emit())


func _create_campfire_story_menu() -> void:
	if campfire_story_menu != null:
		campfire_story_menu.story_selected.connect(func(story_id): events.campfire_story_selected.emit(story_id))
		campfire_story_menu.close_requested.connect(func(): events.campfire_story_menu_close_requested.emit())


func _create_market_menu() -> void:
	if market_menu != null:
		market_menu.sell_requested.connect(func(res_id): events.sell_resource_requested.emit(res_id))
		market_menu.buy_tool_requested.connect(func(): events.buy_tool_requested.emit())
		market_menu.buy_equipment_requested.connect(func(): events.buy_equipment_requested.emit())
		market_menu.buy_food_requested.connect(func(): events.buy_food_requested.emit())
		market_menu.close_requested.connect(func(): events.context_menus_close_requested.emit())


func _create_warehouse_menu() -> void:
	if warehouse_menu != null:
		warehouse_menu.accept_toggled.connect(func(): events.warehouse_accept_toggled.emit())
		warehouse_menu.dump_requested.connect(func(): events.dump_warehouse_resource_requested.emit())
		warehouse_menu.cover_requested.connect(func(): events.cover_warehouse_requested.emit())
		warehouse_menu.demolish_requested.connect(func(): events.warehouse_demolish_requested.emit())
		warehouse_menu.close_requested.connect(func(): events.context_menus_close_requested.emit())


func _create_pocket_take_menu() -> void:
	if pocket_take_menu != null:
		var menu: PocketTakeMenu = pocket_take_menu
		pocket_take_menu_title = menu.title_label
		menu.close_requested.connect(func(): events.pocket_take_menu_close_requested.emit())


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

			menu.cook_assigned.connect(func(): events.cook_assigned.emit())
			menu.teacher_assigned.connect(func(): events.teacher_assigned.emit())
			menu.seller_assigned.connect(func(): events.seller_assigned.emit())
			menu.acceptance_toggled.connect(func(): events.workplace_acceptance_toggled.emit())
			menu.worker_dismissed.connect(func(): events.workplace_worker_dismissed.emit())
			menu.overtime_toggled.connect(func(): events.worker_overtime_toggled.emit())
			menu.relight_requested.connect(func(): events.relight_fire_requested.emit())
			menu.upgrade_requested.connect(func(): events.upgrade_building_requested.emit())
			menu.demolish_requested.connect(func(): events.demolish_building_requested.emit())
			menu.close_requested.connect(func(): events.context_menus_close_requested.emit())
			menu.cancel_construction_requested.connect(func(): events.cancel_construction_requested.emit())


func _create_workforce_menu() -> void:
	if workforce_menu != null:
		workforce_menu.close_requested.connect(func(): events.workforce_menu_close_requested.emit())
		workforce_menu.dismiss_requested.connect(func(): events.remove_worker_role_requested.emit())
		workforce_menu.assign_requested.connect(func(): events.assign_unemployed_worker_requested.emit())
		workforce_menu.register_requested.connect(func(): events.enable_auto_citizen_requested.emit())


func _create_research_menu() -> void:
	if research_menu != null:
		research_menu.close_requested.connect(func(): events.research_menu_hide_requested.emit())
		research_menu.start_requested.connect(func(): events.start_research_requested.emit())
		research_menu.cancel_requested.connect(func(): events.cancel_research_requested.emit())


func _create_campfire_orders_menu() -> void:
	if campfire_orders_menu != null:
		campfire_orders_menu.road_walking_toggled.connect(func(): events.road_walking_order_set.emit())
		campfire_orders_menu.balanced_warehouse_toggled.connect(func(): events.balanced_warehouse_mode_set.emit())
		campfire_orders_menu.night_work_toggled.connect(func(): events.settlement_night_work_toggled.emit())
		campfire_orders_menu.double_time_toggled.connect(func(): events.double_time_order_toggled.emit())
		campfire_orders_menu.cheer_pressed.connect(func(): events.cheer_up_settlement_requested.emit())
		campfire_orders_menu.close_requested.connect(func(): events.campfire_orders_menu_close_requested.emit())


func _create_survival_decision_menu() -> void:
	if decision_menu != null:
		decision_menu.choice_selected.connect(func(idx): events.event_decision_choice_selected.emit(idx))


func _create_crosshair() -> void:
	if crosshair != null:
		crosshair.visible = false
