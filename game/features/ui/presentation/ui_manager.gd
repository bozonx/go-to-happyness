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
	var panel := Panel.new()
	panel.set_anchors_preset(anchor)
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.gui_input.connect(input_handler)
	add_child(panel)
	return panel


func _create_message_panel() -> void:
	if simulation != null and simulation.has_method("_create_message_panel"):
		simulation._create_message_panel(self)


func _create_messages_modal() -> void:
	if simulation != null and simulation.has_method("_create_messages_modal"):
		simulation._create_messages_modal(self)


func _create_time_controls() -> void:
	if simulation != null and simulation.has_method("_create_time_controls"):
		simulation._create_time_controls(self)


func _create_build_menu() -> void:
	if simulation != null and simulation.has_method("_create_build_menu"):
		simulation._create_build_menu(self)


func _create_entrance_menu() -> void:
	if simulation != null and simulation.has_method("_create_entrance_menu"):
		simulation._create_entrance_menu(self)


func _create_house_menu() -> void:
	if simulation != null and simulation.has_method("_create_house_menu"):
		simulation._create_house_menu(self)


func _create_school_menu() -> void:
	if simulation != null and simulation.has_method("_create_school_menu"):
		simulation._create_school_menu(self)


func _create_materials_factory_menu() -> void:
	if simulation != null and simulation.has_method("_create_materials_factory_menu"):
		simulation._create_materials_factory_menu(self)


func _create_campfire_menu() -> void:
	if simulation != null and simulation.has_method("_create_campfire_menu"):
		simulation._create_campfire_menu(self)


func _create_campfire_story_menu() -> void:
	if simulation != null and simulation.has_method("_create_campfire_story_menu"):
		simulation._create_campfire_story_menu(self)


func _create_market_menu() -> void:
	if simulation != null and simulation.has_method("_create_market_menu"):
		simulation._create_market_menu(self)


func _create_warehouse_menu() -> void:
	if simulation != null and simulation.has_method("_create_warehouse_menu"):
		simulation._create_warehouse_menu(self)


func _create_pocket_take_menu() -> void:
	if simulation != null and simulation.has_method("_create_pocket_take_menu"):
		simulation._create_pocket_take_menu(self)


func _create_building_menu() -> void:
	if simulation != null and simulation.has_method("_create_building_menu"):
		simulation._create_building_menu(self)


func _create_workforce_menu() -> void:
	if simulation != null and simulation.has_method("_create_workforce_menu"):
		simulation._create_workforce_menu(self)


func _create_research_menu() -> void:
	if simulation != null and simulation.has_method("_create_research_menu"):
		simulation._create_research_menu(self)


func _create_campfire_orders_menu() -> void:
	if simulation != null and simulation.has_method("_create_campfire_orders_menu"):
		simulation._create_campfire_orders_menu(self)


func _create_survival_decision_menu() -> void:
	decision_menu = SurvivalDecisionPanelScene.instantiate()
	add_child(decision_menu)
	if simulation != null and simulation.has_method("_resolve_event_decision"):
		decision_menu.choice_selected.connect(Callable(simulation, "_resolve_event_decision"))


func _create_crosshair() -> void:
	crosshair = FirstPersonCrosshairScene.instantiate()
	crosshair.visible = false
	add_child(crosshair)
