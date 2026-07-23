class_name CampfireMenuController
extends RefCounted

const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const S = preload("res://game/features/ui/domain/game_strings.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_campfire_menu() -> void:
	if simulation == null:
		return
	simulation.ui_manager.build_menu.visible = false
	simulation.build_menu_is_global = false
	simulation.selection_marker.visible = false
	simulation.build_mode = ""
	simulation.ui_manager.campfire_menu.visible = true
	refresh_campfire_menu()


func show_campfire_story_menu() -> void:
	if simulation == null:
		return
	if simulation.settlement.era != SettlementStateScript.Era.TENT:
		simulation._update_interface("Campfire stories are only part of the Tent Era.")
		return
	if simulation.clock.hour() < 20:
		simulation._update_interface("Campfire stories can only be chosen after 20:00.")
		return
	if not simulation.settlement.campfire_story_effect.is_empty():
		simulation._update_interface("Tonight's story has already been chosen: %s." % simulation.settlement.campfire_story_effect.capitalize())
		return
	simulation.ui_manager.campfire_menu.visible = false
	simulation.ui_manager.campfire_story_menu.visible = true


func close_campfire_story_menu() -> void:
	if simulation == null:
		return
	if simulation.ui_manager.campfire_story_menu != null:
		simulation.ui_manager.campfire_story_menu.visible = false
	simulation.ui_manager.campfire_menu.visible = true


func select_campfire_story(story_id: String) -> void:
	if simulation == null:
		return
	if simulation.daily_rules_service != null:
		simulation.daily_rules_service.set_campfire_story(story_id, simulation.day_cycle.current_day + 1)
	else:
		simulation.settlement.campfire_story_effect = story_id
	simulation.ui_manager.campfire_story_menu.visible = false
	var message := ""
	match story_id:
		"optimistic": message = "Optimistic stories chosen: wellbeing will recover faster tonight."
		"teaching": message = "Teaching tales chosen: a resident may learn something overnight."
		"plan": message = "Plan for tomorrow chosen: gathering work will be faster tomorrow."
	simulation._update_interface(message)


func show_campfire_orders_menu() -> void:
	if simulation == null or simulation.ui_manager.campfire_orders_menu == null:
		return
	simulation.ui_manager.campfire_menu.visible = false

	var hour: int = simulation.clock.hour()
	var can_cheer: bool = hour >= 6 and not simulation.settlement.cheer_up_used_today
	var can_order_night_work: bool = simulation._has_night_work_candidates()
	var settlement_night_active: bool = simulation._has_overtime_source("settlement")
	var double_time_active: bool = simulation.settlement.double_time_order_day == simulation.day_cycle.current_day

	var balanced_warehouse_disabled: bool = simulation.warehouse_positions.is_empty()
	var road_walking_disabled: bool = simulation.settlement.era != SettlementStateScript.Era.TENT

	var cheer_tooltip: String = "Already used today. Available again tomorrow at 06:00." if simulation.settlement.cheer_up_used_today else ("Available once each morning after 06:00." if not can_cheer else "Raise wellbeing by 5%%.")
	if not can_cheer and not simulation.settlement.cheer_up_used_today:
		cheer_tooltip = "Available once each morning after 06:00."

	var state := {
		"road_walking_enabled": simulation.settlement.road_walking_order_enabled,
		"road_walking_disabled": road_walking_disabled,
		"road_walking_tooltip": "Available in the Tent Era." if road_walking_disabled else "Residents trample trails faster. Route selection is unchanged.",

		"balanced_warehouse_enabled": simulation.settlement.balanced_warehouse_mode,
		"balanced_warehouse_disabled": balanced_warehouse_disabled,
		"balanced_warehouse_tooltip": "Build a warehouse first." if balanced_warehouse_disabled else "Spread each good evenly between warehouses instead of filling the nearest one.",

		"cheer_disabled": not can_cheer,
		"cheer_tooltip": cheer_tooltip,

		"night_work_enabled": settlement_night_active,
		"night_work_disabled": not settlement_night_active and not can_order_night_work,
		"night_work_tooltip": "No active workers can receive this order." if not can_order_night_work else "Affected workers continue through the night and next workday. Raises fatigue and lowers satisfaction.",

		"double_time_enabled": double_time_active,
		"double_time_tooltip": "All residents walk twice as fast today. Fatigue accumulates 50%% faster and satisfaction drops." if not double_time_active else "Active. Residents are marching at double speed."
	}

	simulation.ui_manager.campfire_orders_menu.update_state(state)
	simulation.ui_manager.campfire_orders_menu.visible = true


func close_campfire_orders_menu() -> void:
	if simulation == null:
		return
	if simulation.ui_manager.campfire_orders_menu != null:
		simulation.ui_manager.campfire_orders_menu.visible = false
	simulation.ui_manager.campfire_menu.visible = true


func refresh_campfire_menu() -> void:
	if simulation == null or simulation.selected_campfire == null:
		return
	var era_str: String = simulation._era_name()
	var fire_state: Variant = simulation._fire_state_for(simulation.selected_campfire)
	var fuel_current: int = fire_state.total_committed_fuel()
	var title_text := S.CAMPFIRE_ERA_FORMAT % [era_str, fuel_current, simulation.FIRE_SUPPLY_TARGET]

	var housing_slots: int = simulation._total_housing_slots()
	var era_info: Array = build_campfire_era_requirements(housing_slots)
	var req_text: String = era_info[0]
	var can_advance: bool = era_info[1]

	var unhoused: int = simulation._unhoused_citizen_count()
	if unhoused > 0:
		req_text += "\nProblems:\n- Unhoused residents: %d. Settle them in a home before inviting anyone new.\n" % unhoused
	if not simulation._officer_exists():
		req_text += S.CAMPFIRE_NO_OFFICER_HINT

	var upgrade_state := {"visible": false, "text": "", "disabled": false, "tooltip": ""}
	var selected_type: String = simulation.building_registry.building_type_for_node(simulation.selected_campfire) if is_instance_valid(simulation.selected_campfire) else ""
	var next_upgrade: String = simulation.settlement.next_building_upgrade(selected_type)
	if is_instance_valid(simulation.selected_campfire) and not simulation._is_fire_lit(simulation.selected_campfire):
		var relight_state: Variant = simulation._fire_state_for(simulation.selected_campfire)
		upgrade_state["visible"] = true
		upgrade_state["text"] = "Relight with flint and steel"
		upgrade_state["disabled"] = relight_state.fuel <= 0
		upgrade_state["tooltip"] = "Deliver branches before relighting." if upgrade_state["disabled"] else "Use the permanent flint and steel."
	else:
		upgrade_state["visible"] = not next_upgrade.is_empty()
		upgrade_state["text"] = "Upgrade to %s" % str(BuildingCatalogScript.definition_for(next_upgrade).get("name", next_upgrade))
		upgrade_state["disabled"] = not simulation.settlement.can_upgrade_building(selected_type)
		upgrade_state["tooltip"] = "" if not upgrade_state["disabled"] else "Research the next level and gather its resources."

	var is_center: bool = is_instance_valid(simulation.selected_campfire) and simulation.building_registry.building_type_for_node(simulation.selected_campfire) in simulation.OFFICIAL_WORKPLACE_TYPES
	var researcher: Variant = simulation._daily_researcher_at(simulation.selected_campfire)
	var research_post_disabled: bool = not simulation.settlement.is_research_completed("official") or researcher == null
	var research_post_state := {
		"visible": is_center and not simulation._officer_exists(),
		"text": "Promote daily researcher to officer",
		"disabled": research_post_disabled,
		"tooltip": "Research the officer profession, then select a daily researcher working at this campfire." if research_post_disabled else "Promote this researcher to a permanent officer role.",
	}
	var controlled_unit_nearby: bool = simulation.is_first_person and is_instance_valid(simulation.player_citizen) and is_center and simulation.player_citizen.global_position.distance_to(simulation._nearest_service_position(simulation.selected_campfire, simulation.player_citizen.global_position)) <= simulation.OFFICER_POST_RADIUS
	var can_be_official: bool = simulation.settlement.is_research_completed("official")
	var player_role: String = simulation.player_citizen.permanent_role if is_instance_valid(simulation.player_citizen) else ""
	var occupy_disabled: bool = can_be_official and simulation._officer_exists() and player_role != "official"
	var occupy_state := {
		"visible": controlled_unit_nearby,
		"text": S.CAMPFIRE_OCCUPY_OFFICIAL if can_be_official else S.CAMPFIRE_OCCUPY_RESEARCHER,
		"disabled": occupy_disabled,
		"tooltip": S.CAMPFIRE_OFFICIAL_TAKEN if occupy_disabled else "",
	}
	var officer: Variant = simulation._workplace_worker(simulation.selected_campfire) if is_center else null
	var campfire_night_order_used: bool = is_instance_valid(simulation.selected_campfire) and int(simulation.selected_campfire.get_meta("night_work_order_day", -1)) == simulation.day_cycle.current_day
	var overtime_state := {
		"visible": is_center and officer != null,
		"disabled": false,
		"pressed": campfire_night_order_used,
		"tooltip": "Work through the night and the next workday.",
	}

	var state := {
		"title_text": title_text,
		"requirements_text": req_text,
		"advance_disabled": not can_advance,
		"upgrade": upgrade_state,
		"research_post": research_post_state,
		"occupy_position": occupy_state,
		"overtime": overtime_state,
	}
	if is_center and officer != null:
		state["close_btn_y"] = 746.0
	simulation.ui_manager.campfire_menu.update_state(state)
	if simulation.workforce_menu_controller != null:
		simulation.workforce_menu_controller.refresh_campfire_occupancy_button()


func build_campfire_era_requirements(housing_slots: int) -> Array:
	if simulation == null:
		return ["", false]
	var req_text := ""
	var can_advance := false
	var next_era := SettlementStateScript.Era.TENT

	match simulation.settlement.era:
		SettlementStateScript.Era.TENT:
			next_era = SettlementStateScript.Era.EARTH
			var tools_ok: bool = simulation.settlement._has_tools(["axe", "hand_saw", "shovel", "bucket"])
			var earth_research_ok: bool = simulation.settlement.is_research_completed("earth_buildings")
			req_text = "Requirements for Earth Era:\n"
			req_text += "- Tools (axe, saw, shovel, bucket): %s\n" % ("OK" if tools_ok else "Missing")
			req_text += "- Earth buildings research: %s\n" % ("OK" if earth_research_ok else "Missing")
			can_advance = simulation.settlement.can_advance_to(next_era, simulation.citizens.size(), housing_slots)

		SettlementStateScript.Era.EARTH:
			next_era = SettlementStateScript.Era.CLAY
			var has_assembly: bool = simulation.settlement.has_building("earth_assembly")
			var has_smithy: bool = simulation.settlement.has_building("smithy")
			var has_mkt: bool = simulation.settlement.has_building("earth_market")
			var pop_ok: bool = housing_slots >= simulation.citizens.size()
			var clay_ok: bool = simulation.settlement.available_amount("clay") >= 5
			var money_ok: bool = simulation.settlement.money >= 5
			var trade_ok: bool = simulation.settlement.trade_sales >= 3
			var shovel_ok: bool = simulation.settlement._has_tools(["shovel"])
			req_text = "Requirements for Clay Era:\n"
			req_text += "- Earth Assembly built: %s\n" % ("Yes" if has_assembly else "No")
			req_text += "- Smithy built: %s\n" % ("Yes" if has_smithy else "No")
			req_text += "- Earth market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Housing slots (needs %d): %d (%s)\n" % [simulation.citizens.size(), housing_slots, "OK" if pop_ok else "Need more"]
			req_text += "- Clay (needs 5): %d (%s)\n" % [simulation.settlement.amount("clay"), "OK" if clay_ok else "Need more"]
			req_text += "- Money (needs 5): %d (%s)\n" % [simulation.settlement.money, "OK" if money_ok else "Need more"]
			req_text += "- Trade sales (needs 3): %d (%s)\n" % [simulation.settlement.trade_sales, "OK" if trade_ok else "Need more"]
			req_text += "- Tool Shovel owned: %s\n" % ("Yes" if shovel_ok else "No")
			can_advance = simulation.settlement.can_advance_to(next_era, simulation.citizens.size(), housing_slots)

		SettlementStateScript.Era.CLAY:
			next_era = SettlementStateScript.Era.WOOD
			var has_lodge: bool = simulation.settlement.has_building("clay_lodge")
			var has_mkt: bool = simulation.settlement.has_building("clay_market")
			var water_ok: bool = simulation.settlement.amount(ResourceIds.WATER) >= simulation.citizens.size()
			var logs_ok: bool = simulation.settlement.available_amount(ResourceIds.LOGS) >= 10
			var money_ok: bool = simulation.settlement.money >= 10
			req_text = "Requirements for Wood Era:\n"
			req_text += "- Clay lodge built: %s\n" % ("Yes" if has_lodge else "No")
			req_text += "- Clay market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Water (needs %d): %d (%s)\n" % [simulation.citizens.size(), simulation.settlement.amount(ResourceIds.WATER), "OK" if water_ok else "Need more"]
			req_text += "- Logs (needs 10): %d (%s)\n" % [simulation.settlement.amount(ResourceIds.LOGS), "OK" if logs_ok else "Need more"]
			req_text += "- Money (needs 10): %d (%s)\n" % [simulation.settlement.money, "OK" if money_ok else "Need more"]
			can_advance = simulation.settlement.can_advance_to(next_era, simulation.citizens.size(), housing_slots)

		SettlementStateScript.Era.WOOD:
			next_era = SettlementStateScript.Era.STONE
			var has_th: bool = simulation.settlement.has_building("wood_town_hall")
			var has_mkt: bool = simulation.settlement.has_building("wood_market")
			var has_sm: bool = simulation.settlement.has_building("sawmill")
			var has_house3: bool = simulation.settlement.has_building("house_lvl3")
			var pickaxe_ok: bool = simulation.settlement._has_tools(["pickaxe"])
			var money_ok: bool = simulation.settlement.money >= 15
			req_text = "Requirements for Stone Era:\n"
			req_text += "- Wooden town hall built: %s\n" % ("Yes" if has_th else "No")
			req_text += "- Sawmill built: %s\n" % ("Yes" if has_sm else "No")
			req_text += "- Wood market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Wood house Level 3 built: %s\n" % ("Yes" if has_house3 else "No")
			req_text += "- Tool Pickaxe owned: %s\n" % ("Yes" if pickaxe_ok else "No")
			req_text += "- Money (needs 15): %d (%s)\n" % [simulation.settlement.money, "OK" if money_ok else "Need more"]
			can_advance = simulation.settlement.can_advance_to(next_era, simulation.citizens.size(), housing_slots)

		SettlementStateScript.Era.STONE:
			next_era = SettlementStateScript.Era.BRICK
			var has_pref: bool = simulation.settlement.has_building("stone_prefecture")
			var has_mkt: bool = simulation.settlement.has_building("stone_market")
			var has_mw: bool = simulation.settlement.has_building("masonry_workshop")
			var stone_ok: bool = simulation.settlement.available_amount(ResourceIds.STONE) >= 20
			var money_ok: bool = simulation.settlement.money >= 20
			req_text = "Requirements for Brick Era:\n"
			req_text += "- Stone prefecture built: %s\n" % ("Yes" if has_pref else "No")
			req_text += "- Masonry workshop built: %s\n" % ("Yes" if has_mw else "No")
			req_text += "- Stone market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Stone (needs 20): %d (%s)\n" % [simulation.settlement.amount(ResourceIds.STONE), "OK" if stone_ok else "Need more"]
			req_text += "- Money (needs 20): %d (%s)\n" % [simulation.settlement.money, "OK" if money_ok else "Need more"]
			can_advance = simulation.settlement.can_advance_to(next_era, simulation.citizens.size(), housing_slots)

		SettlementStateScript.Era.BRICK:
			req_text = "Maximum era reached! Your settlement is fully advanced."
			can_advance = false

	return [req_text, can_advance]
