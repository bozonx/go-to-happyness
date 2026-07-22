class_name HouseMenuController
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_house_menu() -> void:
	if simulation == null or simulation.selected_house == null:
		return
	var slots: int = simulation.selected_house.get_meta("spawn_slots", 0)
	simulation.house_menu.visible = true
	var capacity: int = int(simulation.selected_house.get_meta("housing_capacity", simulation.HOUSE_CAPACITY))
	var building_type: String = simulation.building_registry.building_type_for_node(simulation.selected_house)
	if building_type.is_empty():
		building_type = "house"
	var is_tent: bool = simulation.selected_house.has_meta("is_tent")
	var home_name := "Соломенная палатка" if building_type == "straw_tent" else ("Брезентовая палатка" if building_type == "tarp_tent" else ("Палатка" if building_type == "tent" else "House"))
	var unhoused: int = simulation._unhoused_citizen_count()
	var residents: int = capacity - slots
	if is_tent:
		simulation.house_menu_title.text = "%s\nResidents: %d/%d" % [home_name, residents, capacity]
	else:
		simulation.house_menu_title.text = "%s\nFree beds: %d/%d  Unhoused: %d" % [home_name, slots, capacity, unhoused]
	if simulation.house_spawn_button != null:
		var pending_demolition: bool = bool(simulation.selected_house.get_meta("pending_demolition", false))
		if is_tent:
			var ordered_today: bool = int(simulation.selected_house.get_meta("tent_order_day", -1)) == simulation.day_cycle.current_day
			simulation.house_spawn_button.disabled = slots <= 0 or ordered_today or pending_demolition
			simulation.house_spawn_button.text = "Already ordered today" if ordered_today else ("No free beds" if slots <= 0 else "Order a resident")
		else:
			simulation.house_spawn_button.disabled = slots <= 0 or unhoused > 0 or pending_demolition
			simulation.house_spawn_button.text = "House the initial residents first" if unhoused > 0 else ("No free beds" if slots <= 0 else "Order a resident")
	var settle_button: Button = simulation.house_menu.get_node_or_null("SettleUnhoused") as Button
	if settle_button == null:
		settle_button = Button.new()
		settle_button.name = "SettleUnhoused"
		settle_button.position = Vector2(16, 102)
		settle_button.size = Vector2(272, 30)
		settle_button.pressed.connect(simulation._settle_unhoused_resident)
		simulation.house_menu.add_child(settle_button)
	if is_tent:
		settle_button.visible = false
		settle_button.disabled = true
	else:
		settle_button.visible = true
		settle_button.text = "Settle unhoused resident"
		settle_button.disabled = slots <= 0 or unhoused <= 0 or bool(simulation.selected_house.get_meta("pending_demolition", false))
