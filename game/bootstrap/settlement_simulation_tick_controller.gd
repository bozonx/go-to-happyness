class_name SettlementSimulationTickController
extends RefCounted

## Handles per-frame simulation updates: clock advancement, daylight/weather
## sync, citizen position guarding, living status refresh, work-time queries,
## leisure dispatch, and unstaffed employment center warnings.
## Extracted from SettlementGame to reduce its method count.

const S = preload("res://game/features/ui/domain/game_strings.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func total_game_minutes() -> float:
	return float(game.day_cycle.current_day - 1) * 24.0 * 60.0 + game.game_minutes


func is_night() -> bool:
	return game.clock.is_night()


func is_work_time() -> bool:
	return game.day_cycle.is_work_time(game.settlement.workday_hours)


func is_citizen_work_time(citizen: Citizen) -> bool:
	if not is_instance_valid(citizen) or citizen.is_recovering(game.day_cycle.current_day):
		return false
	return is_work_time() or citizen.has_active_overtime(game.day_cycle.current_day)


func has_lit_communal_fire() -> bool:
	for record in game.building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and game.fire_management_service.is_managed_fire_source(building) and game.fire_management_service.is_fire_lit(building):
			return true
	return false


func refresh_living_statuses() -> void:
	if game.citizen_living_status_service == null:
		return
	game.citizen_living_status_service.refresh_all(game.citizens, has_lit_communal_fire(), is_night())


func refresh_living_status(citizen: Citizen) -> void:
	if game.citizen_living_status_service == null:
		return
	game.citizen_living_status_service.refresh_citizen(citizen, has_lit_communal_fire(), is_night())


func update_clock(delta: float) -> void:
	var previous_hour := game.clock.hour()
	var events := game.day_cycle.advance(delta, game.GAME_MINUTES_PER_SECOND, game.settlement.workday_hours)
	if game.weather_state.update(game.clock.minutes):
		if game.weather_state.is_raining:
			game.update_interface("Rain has started.")
		else:
			game.update_interface("Rain has stopped.")
	if game.clock.hour() != previous_hour:
		game.settlement_survival_service.apply_hourly_tent_survival(game.clock.hour())
		game.settlement_survival_service.apply_hourly_bare_hands_penalty()
		game.settlement_survival_service.apply_hourly_work_fatigue()
	if game.ui_manager.hud != null:
		game.ui_manager.hud.update_clock("%s  %02d:%02d  x%d" % ["Night" if game.clock.is_night() else "Day", game.clock.hour(), game.clock.minute(), int(game.time_multiplier)])
	if game.survival_event_controller != null:
		game.survival_event_controller.update_skip_night_button()
	for event in events:
		if game.simulation_event_dispatcher != null:
			game.simulation_event_dispatcher.dispatch_event(event, game.day_cycle.current_day)


func update_daylight() -> void:
	if game.world_setup != null:
		var cloud_cover := game.weather_state.cloud_cover_at(game.clock.minutes)
		var rain_intensity := game.weather_state.intensity_at(game.clock.minutes)
		var storm_influence := game.weather_state.storm_influence_at(game.clock.minutes)
		# Continuous game-time so cloud drift/morph advances (and fast-forwards) with
		# the clock; wind comes from the shared weather model so it matches whatever
		# waves/flags/sails read from it.
		var weather_minutes := total_game_minutes()
		var wind := game.weather_state.wind_vector_at(game.clock.minutes)
		var wind_displacement := game.weather_state.wind_displacement_at(game.clock.minutes)
		var precipitation := game.weather_state.precipitation_type_at(game.clock.minutes)
		game.world_setup.update_daylight(
			game.game_minutes,
			cloud_cover,
			rain_intensity,
			game.runtime_seconds,
			storm_influence,
			game.weather_state.cloud_seed,
			wind,
			weather_minutes,
			precipitation,
			wind_displacement
		)


func guard_citizen_positions() -> void:
	if not is_instance_valid(game.entrance_stone):
		return
	for citizen in game.citizens:
		if not is_instance_valid(citizen) or game.outside_workers.has(citizen.get_stable_id()):
			continue
		var citizen_id := citizen.get_stable_id()
		var previous: Vector3 = game.last_citizen_positions.get(citizen_id, citizen.global_position)
		var intentionally_at_entrance := citizen.state in [Citizen.State.TO_ARRIVAL_ENTRANCE, Citizen.State.ARRIVAL_MEETING, Citizen.State.ARRIVAL_WAITING, Citizen.State.TO_ARRIVAL_CENTER, Citizen.State.TO_TRADE_PICKUP, Citizen.State.TO_TRADE_DESTINATION]
		# No normal work transition moves an established resident from across the
		# map to the entrance. Keep the last known world location if that reset is
		# observed, while preserving genuine arrival and trade routes.
		if not intentionally_at_entrance and previous.distance_to(citizen.global_position) > 5.0 and previous.distance_to(game.entrance_stone.global_position) > 5.0 and citizen.global_position.distance_to(game.entrance_stone.global_position) < 2.5:
			citizen.global_position = previous
			citizen.velocity = Vector3.ZERO
		game.last_citizen_positions[citizen_id] = citizen.global_position


func start_park_rest(cooks_only: bool) -> void:
	if game.citizen_needs_service == null:
		return
	var sent := game.citizen_needs_service.request_scheduled_rest(cooks_only, game.citizens, game.park_positions)
	if sent > 0:
		game.update_interface("%02d:00 park break: %d residents are resting." % [int(game.game_minutes) / 60, sent])


func check_unstaffed_employment_center() -> void:
	if not is_work_time():
		return

	var has_waiting_citizen := false
	var center := game.employment_center_position()
	if center != Vector3.INF:
		for citizen in game.citizens:
			if is_instance_valid(citizen) and citizen.state in [Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]:
				if citizen.global_position.distance_to(center) <= 3.5:
					has_waiting_citizen = true
					break

	if has_waiting_citizen and not game.citizen_registration_service.is_registration_staffed():
		var current_time := game.runtime_seconds
		if current_time - game.last_unstaffed_warning_time > 60.0:
			game.last_unstaffed_warning_time = current_time
			game.add_message(S.WARNING_NO_OFFICER)


## Per-frame simulation orchestration. Called from SettlementGame._process after
## the first-person/input and camera updates. All service tick calls live here
## so _process stays a thin dispatch.
func tick(delta: float) -> void:
	game.construction_controller.update_construction(delta)
	game.demolition.tick(delta)
	game.water_collector_service.tick(delta)
	update_clock(delta)
	game.release_unassigned_overtime_workers()
	if game.survival_event_controller != null:
		game.survival_event_controller.update_survival_busy_workers()
	game.outside_work_controller.return_outside_workers()
	if game.ambient_spawner != null:
		game.ambient_spawner.update_wild_food(delta)
	guard_citizen_positions()
	game.world_navigation_controller.update_trail_overlay()
	update_daylight()
	if game.building_lifecycle_service != null:
		game.building_lifecycle_service.update_house_lights()
	game.canteen_service.update_canteen_delivery()
	game.citizen_lifecycle_service.update_arrivals()
	game.fire_management_service.update_fire_status(game, game.settlement.amount(ResourceIds.BRANCHES))
	if game.trade_service != null:
		game.trade_service.update()
	# Queued trades are delivered as courier tasks; a dispatch pass picks them up.
	game.request_courier_dispatch()
	game.sawmills.tick(delta, game.runtime_seconds)
	game.research_controller.update_building_research(delta)
	if game.building_status_indicator_controller != null:
		game.building_status_indicator_controller.update_building_status_indicators(delta)
	game.foraging_service.update_gathering_indicators(game.is_first_person, game.interaction_action, game.interaction_resource, game.interaction_time, game.player_citizen, game.citizens)
	if game.label_distance_fade_controller != null:
		game.label_distance_fade_controller.update_label_distance_fading()
	game.backpack_node = game.resource_pile_service.sync_backpack_pile(game.backpack_node)
	if is_work_time() or game.has_active_night_work_order():
		game.worker_poll_timer -= delta
		if game.worker_poll_timer <= 0.0:
			game.worker_poll_timer = game.WORKER_POLL_INTERVAL
			game.update_workers()
	if game.selected_builder != null and game.ui_manager.build_menu.visible:
		game.show_selected_citizen_menu()


func send_citizen_to_leisure(citizen: Citizen, minimum_hours := 0) -> bool:
	# Returns whether the citizen was actually placed somewhere to rest so the
	# waiting window knows if it needs to keep looking for work.
	if citizen.is_player_controlled or citizen.state not in [Citizen.State.IDLE, Citizen.State.RESTING, Citizen.State.WAITING]:
		return false
	# Dedicated recreation first (parks, leisure centers), picked at random.
	var recreation: Array[Vector3] = game.park_positions + game.leisure_positions
	for position in game.gathering_place_positions:
		var place := game.building_registry.building_at_service_position(position)
		if is_instance_valid(place):
			recreation.append(position)
	if not recreation.is_empty():
		return game.citizen_needs_service != null and game.citizen_needs_service.request_leisure(citizen.ai_id, recreation, minimum_hours)
	# No parks yet (early eras): gather at the main campfire or at the water.
	var gathering_spots: Array[Vector3] = []
	if is_instance_valid(game.campfire_node) and game.fire_management_service.is_fire_lit(game.campfire_node):
		gathering_spots.append(game.campfire_node.global_position)
	# An access point is already a bank cell, so it needs no nudge out of the water:
	# `WaterAccessService` never returns a wet column.
	for bank: Vector3 in game.water_source_positions:
		gathering_spots.append(bank)
	if not gathering_spots.is_empty():
		return game.citizen_needs_service != null and game.citizen_needs_service.request_leisure(citizen.ai_id, gathering_spots, minimum_hours)
	# Nothing communal exists at all. During the working day we must NOT send them
	# home to sleep — a RESTING citizen stops re-probing for work and would sleep
	# through the day (the "skip night with full storage" freeze). Return false so
	# the waiting window drops them to IDLE (with its indicator) and the poll keeps
	# checking. Night-time sleep is handled separately by the native sleep goal.
	return false
