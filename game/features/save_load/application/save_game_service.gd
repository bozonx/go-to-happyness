class_name SaveGameService
extends RefCounted

## Settlement-module serialization. This builds and reads only the
## `gth.settlement` save section; the host `SessionSaveCoordinator` owns the
## file, headers and the slot path. The section schema is the module's contract
## and may evolve with the module — nothing else reads these keys.

const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")
const WarehouseStateScript = preload("res://game/features/settlement/domain/warehouse_state.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")


## Builds the full `gth.settlement` module section from a running session. The
## caller (the module's save hook) files this under `modules["gth.settlement"]`.
## Returns an empty dictionary only if the game node is null; everything else
## writes a valid, possibly partial, section.
static func capture_settlement_section(game: Node) -> Dictionary:
	if game == null:
		push_error("SaveGameService: Cannot save null game instance")
		return {}

	# 1. Settlement State
	var settlement_state := {}
	if "settlement" in game and game.settlement != null:
		var s = game.settlement
		var res_map: Dictionary = {}
		var ResourceIdsScript = load("res://game/features/settlement/domain/resource_ids.gd")
		if ResourceIdsScript != null and "ALL" in ResourceIdsScript:
			for res_id in ResourceIdsScript.ALL:
				var amt: int = s.amount(res_id)
				if amt > 0:
					res_map[res_id] = amt
		settlement_state = {
			"money": s.money,
			"wellbeing": s.wellbeing,
			"resources": res_map,
			"backpack": s.backpack.duplicate(true),
			"warehouses": _save_warehouses(s),
			"warehouse_types": s.warehouse_types.duplicate(),
			"warehouse_ever_built": s.warehouse_ever_built,
			"work_policy": {
				"workday_hours": s.workday_hours,
				"pending_workday_hours": s.pending_workday_hours,
				"night_work_order_day": s.night_work_order_day,
				"double_time_order_day": s.double_time_order_day,
				"road_walking_order_enabled": s.road_walking_order_enabled,
				"cheer_up_used_today": s.cheer_up_used_today,
			},
			"research": {
				"tech_id": s.active_research_tech_id,
				"worker_id": s.active_research_worker_id,
				"remaining_time": s.active_research_remaining_time,
				"duration": s.active_research_duration,
			},
			"unlocked_building_levels": s.unlocked_building_levels.duplicate() if "unlocked_building_levels" in s else {},
			"unlocked_systems": s.unlocked_systems.duplicate() if "unlocked_systems" in s else {},
			"equipment": s.equipment.duplicate(true),
			"era": int(s.era)
		}

	# 2. Simulation Clock (module-owned; the host engine_state holds only the clock model)
	var clock_state := {}
	if "clock" in game and game.clock != null:
		clock_state = {
			"minutes": game.clock.minutes,
			"current_day": game.day_cycle.current_day if "day_cycle" in game else 1,
		}

	# 3. Camera (module-owned; only the settlement session stores camera framing)
	var camera_target: Variant = game.get("camera_target") if "camera_target" in game else Vector3.ZERO
	var camera_state := {
		"target": SaveDataScript.vector3_to_dict(camera_target if camera_target is Vector3 else Vector3.ZERO),
		"distance": float(game.get("camera_distance")) if "camera_distance" in game else 30.0,
		"yaw": float(game.get("camera_yaw")) if "camera_yaw" in game else 42.0,
		"pitch": float(game.get("camera_pitch")) if "camera_pitch" in game else 52.0,
	}

	# 4. Buildings & Construction Sites
	var buildings_list: Array = []
	var construction_sites_list: Array = []
	if "building_registry" in game and game.building_registry != null:
		for record in game.building_registry.records():
			if is_instance_valid(record.node):
				var cell_dict = SaveDataScript.vector2i_to_dict(record.cell)
				var center_dict = SaveDataScript.vector3_to_dict(record.center)
				var rot_y = record.node.rotation_degrees.y
				var b_type = record.building_type
				var blueprint_ref: Dictionary = record.node.get_meta("blueprint_ref", {})
				var zone_state: Array = game.building_zone_service.zone_state_snapshot(record.node) if "building_zone_service" in game and game.building_zone_service != null else []
				if "construction_controller" in game and game.construction_controller != null and game.construction_controller.is_construction_site(record.node):
					var site = game.call("_get_construction_site_data", record.node)
					if site != null:
						construction_sites_list.append({
							"cell": cell_dict,
							"building_type": b_type,
							"position": center_dict,
							"rotation_y": rot_y,
							"progress": site.progress,
							"delivered_materials": site.delivered_materials.duplicate(),
							"blueprint_ref": blueprint_ref.duplicate(true),
							"zone_state": zone_state.duplicate(true),
						})
				else:
					buildings_list.append({
						"cell": cell_dict,
						"building_type": b_type,
						"position": center_dict,
						"rotation_y": rot_y,
						"blueprint_ref": blueprint_ref.duplicate(true),
						"zone_state": zone_state.duplicate(true),
					})

	# 5. Resource Piles
	var piles_list: Array = []
	if "resource_piles" in game:
		for pile in game.resource_piles:
			if pile != null and is_instance_valid(pile.node):
				piles_list.append({
					"resources": pile.resources.duplicate(true),
					"position": SaveDataScript.vector3_to_dict(pile.node.global_position),
					"is_backpack": pile.is_backpack,
					"landscape_owned": bool(pile.node.get_meta("landscape_owned", false)),
				})

	# 5b. Forest (felled trees and branch/wood depletion)
	var forest_state: Array = []
	if "foraging_service" in game and game.foraging_service != null and game.foraging_service.has_method("export_tree_state"):
		forest_state = game.foraging_service.export_tree_state()

	# 6. Citizens
	var citizens_list: Array = []
	if "citizens" in game:
		for citizen in game.citizens:
			if is_instance_valid(citizen):
				var pockets_content: Array = citizen.pockets_get_content() if citizen.has_method("pockets_get_content") else []
				var citizen_data := {
					"ai_id": citizen.ai_id,
					"is_hero": citizen.is_hero,
					"position": SaveDataScript.vector3_to_dict(citizen.global_position),
					"needs": {
						"hunger": citizen.hunger,
						"fatigue": citizen.fatigue,
						"satisfaction": citizen.satisfaction,
						"continuous_work_hours": citizen.continuous_work_hours,
						"satisfaction_tick": citizen.satisfaction_tick,
						"recovery_until_workday_id": citizen.recovery_until_workday_id,
						"buffs": citizen.buffs.duplicate(true),
						"debuffs": citizen.debuffs.duplicate(true),
					},
					"specialization": citizen.specialization,
					"active_role": citizen.active_role,
					"employment_state": int(citizen.employment_state),
					"permanent_role": citizen.permanent_role,
					"daily_order_role": citizen.daily_order_role,
					"pockets": pockets_content
				}
				if is_instance_valid(citizen.employment_workplace) and "building_registry" in game:
					var employment_record = game.building_registry.record_for_node(citizen.employment_workplace)
					if employment_record != null:
						citizen_data["employment_building_cell"] = SaveDataScript.vector2i_to_dict(employment_record.cell)
						if "building_zone_service" in game and game.building_zone_service != null:
							citizen_data["employment_zone_id"] = String(game.building_zone_service.zone_id_for(
								citizen.employment_workplace, StringName(citizen.permanent_role), citizen.ai_id))
				if "first_name" in citizen:
					citizen_data["first_name"] = citizen.get("first_name")
				if "last_name" in citizen:
					citizen_data["last_name"] = citizen.get("last_name")
				if "age" in citizen:
					citizen_data["age"] = citizen.get("age")
				citizens_list.append(citizen_data)

	# 7. World state (next id, biome, map ref, natural resources, roads, map zones)
	var map_reference: Dictionary = {}
	if "launch_config" in game and game.launch_config != null and not String(game.launch_config.map_ref).is_empty():
		var address := ContentIdScript.split_runtime_key(game.launch_config.map_ref)
		map_reference = {"source": String(address["source"]), "id": String(address["id"])}
		if game.launch_config.map_document != null:
			map_reference["revision"] = game.launch_config.map_document.meta.revision
	var world_state := {
		"next_ai_citizen_id": game.get("next_ai_citizen_id"),
		"biome_id": str(game.launch_config.biome_id) if "launch_config" in game and game.launch_config != null else "",
		"map_ref": map_reference,
		"natural_resources": game.ambient_spawner.export_resource_state() if "ambient_spawner" in game and game.ambient_spawner != null else {},
		"roads": game.road_network_service.export_state() if "road_network_service" in game and game.road_network_service != null else [],
		# Session state of map zones (active_zones.md §13): owner and flags only —
		# geometry comes back from the map document on every launch. A save without
		# zones (older build, or a no-map session) writes an empty list and loads
		# with the registry left at its freshly-built default.
		"map_zones": game.map_zone_registry.session_state_to_dict() if "map_zone_registry" in game and game.map_zone_registry != null else [],
		# Only the SURFACE of the terrain, never its relief: the map package owns
		# the ground and reloads it, but material and detail change during play —
		# citizens wear paths and burned cells regrow (`terrain_materials.md` §6.1,
		# §6.4). Run-length encoded, so an untouched board is a few hundred bytes.
		"terrain_surface": _terrain_surface_state(game),
	}

	return {
		"settlement": settlement_state,
		"world": world_state,
		"buildings": buildings_list,
		"construction_sites": construction_sites_list,
		"citizens": citizens_list,
		"resource_piles": piles_list,
		"forest": forest_state,
		"clock": clock_state,
		"camera": camera_state,
	}


static func _save_warehouses(settlement: RefCounted) -> Array:
	var result: Array = []
	for warehouse: WarehouseState in settlement.warehouses:
		result.append({
			"capacity": warehouse.capacity,
			"resources": warehouse.resources.duplicate(true),
			"blacklisted": warehouse.blacklisted.duplicate(true),
		})
	return result


## Restores core settlement domain state (money, wellbeing, era, resources,
## backpack, unlocked levels/systems, equipment) from a saved dictionary.
static func restore_settlement_state(settlement: RefCounted, s_dict: Dictionary) -> void:
	settlement.money = int(s_dict.get("money", 500))
	settlement.wellbeing = int(s_dict.get("wellbeing", 75))
	settlement.era = int(s_dict.get("era", 0))
	settlement.backpack.clear()
	if s_dict.get("backpack", {}) is Dictionary:
		settlement.backpack.merge((s_dict.get("backpack") as Dictionary).duplicate(true), true)

	var saved_res: Dictionary = s_dict.get("resources", {})
	for res_id in ResourceIds.ALL:
		var target_amt: int = int(saved_res.get(res_id, 0))
		var current_amt: int = settlement.amount(res_id)
		var diff: int = target_amt - current_amt
		if diff != 0:
			settlement.add(res_id, diff)

	if s_dict.has("unlocked_building_levels"):
		var u_b: Dictionary = s_dict["unlocked_building_levels"]
		for b_type in u_b:
			settlement.unlocked_building_levels[b_type] = u_b[b_type]
	if s_dict.has("unlocked_systems"):
		var u_sys: Dictionary = s_dict["unlocked_systems"]
		for sys_id in u_sys:
			settlement.unlocked_systems[sys_id] = u_sys[sys_id]

	if s_dict.has("equipment"):
		settlement.equipment = s_dict["equipment"].duplicate(true)


## Restores work policy fields (workday hours, night work, road walking, etc.)
static func restore_work_policy(settlement: RefCounted, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var policy: Dictionary = data
	settlement.workday_hours = clampi(int(policy.get("workday_hours", settlement.workday_hours)), 1, 24)
	settlement.pending_workday_hours = clampi(int(policy.get("pending_workday_hours", 0)), 0, 24)
	settlement.night_work_order_day = int(policy.get("night_work_order_day", -1))
	settlement.double_time_order_day = int(policy.get("double_time_order_day", -1))
	settlement.road_walking_order_enabled = bool(policy.get("road_walking_order_enabled", false))
	settlement.cheer_up_used_today = bool(policy.get("cheer_up_used_today", false))


## Restores active research progress fields.
static func restore_research(settlement: RefCounted, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var research: Dictionary = data
	settlement.active_research_tech_id = str(research.get("tech_id", ""))
	settlement.active_research_worker_id = int(research.get("worker_id", -1))
	settlement.active_research_remaining_time = maxf(0.0, float(research.get("remaining_time", 0.0)))
	settlement.active_research_duration = maxf(0.0, float(research.get("duration", 0.0)))


## Restores warehouse capacities, stored resources, and blacklists.
static func restore_warehouses(settlement: RefCounted, data: Variant, types: Variant, ever_built: bool) -> void:
	if not (data is Array):
		return
	var saved_warehouses: Array = data
	for index in mini(saved_warehouses.size(), settlement.warehouses.size()):
		var saved: Variant = saved_warehouses[index]
		if not (saved is Dictionary):
			continue
		var warehouse: WarehouseState = settlement.warehouses[index]
		var saved_dict: Dictionary = saved
		warehouse.capacity = maxi(0, int(saved_dict.get("capacity", warehouse.capacity)))
		if saved_dict.get("resources", {}) is Dictionary:
			var saved_resources: Dictionary = saved_dict.get("resources")
			for resource_type in ResourceIds.ALL:
				warehouse.resources[resource_type] = maxi(0, int(saved_resources.get(resource_type, 0)))
		if saved_dict.get("blacklisted", {}) is Dictionary:
			var saved_blacklist: Dictionary = saved_dict.get("blacklisted")
			for resource_type in ResourceIds.ALL:
				warehouse.blacklisted[resource_type] = bool(saved_blacklist.get(resource_type, false))
	if types is Array:
		settlement.warehouse_types.clear()
		for warehouse_type in types:
			settlement.warehouse_types.append(str(warehouse_type))
	settlement.warehouse_ever_built = ever_built


## Extracts camera state into a dictionary with Vector3 target and scalar
## distance/yaw/pitch. Returns an empty dict if camera_state is empty.
static func restore_camera(camera_state: Dictionary) -> Dictionary:
	if camera_state.is_empty():
		return {}
	var result: Dictionary = {}
	var cam_target_dict: Dictionary = camera_state.get("target", {})
	if not cam_target_dict.is_empty():
		result["target"] = SaveDataScript.dict_to_vector3(cam_target_dict)
	result["distance"] = float(camera_state.get("distance", 30.0))
	result["yaw"] = float(camera_state.get("yaw", 42.0))
	result["pitch"] = float(camera_state.get("pitch", 52.0))
	return result


## The session's surface layer as base64, or "" when there is no terrain to read.
## Empty is a valid state and loads as "leave the map's surface alone", which is
## exactly right for a save written before this layer existed.
static func _terrain_surface_state(game: Node) -> String:
	if not ("world_setup" in game) or game.world_setup == null:
		return ""
	var grid: TerrainGrid = game.world_setup.terrain_grid
	return "" if grid == null else TerrainSurfaceCodec.to_base64(grid)
