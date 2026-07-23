class_name SchoolMenuController
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_school_menu() -> void:
	if simulation == null or simulation.selected_school == null:
		return
	simulation.ui_manager.build_menu.visible = false
	simulation.build_menu_is_global = false
	simulation.ui_manager.house_menu.visible = false
	simulation.ui_manager.building_menu.visible = false

	var student_label: String = simulation.selected_builder.role_label() if simulation.selected_builder != null else ""
	var can_manage: bool = simulation._player_can_manage_permanent_professions()
	var block_tooltip: String = simulation._permanent_profession_block_message()

	simulation.ui_manager.school_menu.update_state(student_label, can_manage, block_tooltip, simulation.school_developed_professions)
	simulation.ui_manager.school_menu.visible = true
	simulation._update_interface("School selected: configure morning study and retraining here.")


func toggle_school_development(role: String, pressed: bool) -> void:
	if not simulation._player_can_manage_permanent_professions():
		if simulation.workplace_labor_service != null:
			simulation.workplace_labor_service.show_labor_command_blocked()
		return
	simulation.school_service.set_profession_developed(role, pressed)
	if pressed:
		simulation._update_interface("School developed: all %ss will train in mornings." % role.capitalize())
	else:
		simulation._update_interface("Stopped school training for %ss." % role.capitalize())


func start_school_training(role: String) -> void:
	if not simulation._player_can_manage_permanent_professions():
		if simulation.workplace_labor_service != null:
			simulation.workplace_labor_service.show_labor_command_blocked()
		return
	if simulation.selected_builder == null or simulation.selected_school == null:
		return
	simulation.selected_builder.start_training(role, simulation.selected_school.global_position)
	simulation.ui_manager.school_menu.visible = false
	simulation._update_interface("Training started: 10 mornings in school, then regular work.")
