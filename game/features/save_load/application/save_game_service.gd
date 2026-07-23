class_name SaveGameService
extends RefCounted

## Application service managing save and load operations.

const QUICKSAVE_PATH := "user://saves/quicksave.json"
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")
const WarehouseStateScript = preload("res://game/features/settlement/domain/warehouse_state.gd")


static func has_quicksave() -> bool:
	return FileAccess.file_exists(QUICKSAVE_PATH)


static func save_quicksave(game: Node) -> bool:
	return save_game(game, QUICKSAVE_PATH)


static func load_quicksave(game: Node) -> bool:
	return load_game(game, QUICKSAVE_PATH)


static func save_game(game: Node, path: String = QUICKSAVE_PATH) -> bool:
	if game == null:
		push_error("SaveGameService: Cannot save null game instance")
		return false
		
	var save_data := SaveDataScript.new()
	
	# 1. Settlement State
	if "settlement" in game and game.settlement != null:
		var s = game.settlement
		var res_map: Dictionary = {}
		var ResourceIdsScript = load("res://game/features/settlement/domain/resource_ids.gd")
		if ResourceIdsScript != null and "ALL" in ResourceIdsScript:
			for res_id in ResourceIdsScript.ALL:
				var amt: int = s.amount(res_id)
				if amt > 0:
					res_map[res_id] = amt
		save_data.settlement_state = {
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

	# 2. Simulation Clock
	if "clock" in game and game.clock != null:
		save_data.clock_state = {
			"minutes": game.clock.minutes,
			"current_day": game.day_cycle.current_day if "day_cycle" in game else 1,
		}
		
	# 3. Camera
	var camera_target: Variant = game.get("camera_target") if "camera_target" in game else Vector3.ZERO
	save_data.camera_state = {
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
				if game.has_method("_is_construction_site") and game.call("_is_construction_site", record.node):
					var site = game.call("_get_construction_site_data", record.node)
					if site != null:
						construction_sites_list.append({
							"cell": cell_dict,
							"building_type": b_type,
							"position": center_dict,
							"rotation_y": rot_y,
							"progress": site.progress,
							"delivered_materials": site.delivered_materials.duplicate()
						})
				else:
					buildings_list.append({
						"cell": cell_dict,
						"building_type": b_type,
						"position": center_dict,
						"rotation_y": rot_y
					})
	save_data.buildings_state = buildings_list
	save_data.construction_sites_state = construction_sites_list

	# 5. Resource Piles
	var piles_list: Array = []
	if "resource_piles" in game:
		for pile in game.resource_piles:
			if pile != null and is_instance_valid(pile.node):
				piles_list.append({
					"resources": pile.resources.duplicate(true),
					"position": SaveDataScript.vector3_to_dict(pile.node.global_position),
					"is_backpack": pile.is_backpack,
				})
	save_data.resource_piles_state = piles_list

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
				if "first_name" in citizen:
					citizen_data["first_name"] = citizen.get("first_name")
				if "last_name" in citizen:
					citizen_data["last_name"] = citizen.get("last_name")
				if "age" in citizen:
					citizen_data["age"] = citizen.get("age")
				citizens_list.append(citizen_data)
	save_data.citizens_state = citizens_list
	save_data.world_state = {
		"next_ai_citizen_id": game.get("_next_ai_citizen_id")
	}

	var success := save_data.save_to_file(path)
	if success:
		print("SaveGameService: Successfully saved quicksave to " + path)
	return success


static func _save_warehouses(settlement: RefCounted) -> Array:
	var result: Array = []
	for warehouse: WarehouseState in settlement.warehouses:
		result.append({
			"capacity": warehouse.capacity,
			"resources": warehouse.resources.duplicate(true),
			"blacklisted": warehouse.blacklisted.duplicate(true),
		})
	return result


static func load_game(game: Node, path: String = QUICKSAVE_PATH) -> bool:
	if game == null:
		push_error("SaveGameService: Cannot load into null game instance")
		return false
		
	var save_data := SaveDataScript.new()
	if not save_data.load_from_file(path):
		push_error("SaveGameService: Failed to read save file from " + path)
		return false
	
	if game.has_method("restore_from_save_data"):
		var restored: Variant = game.call("restore_from_save_data", save_data)
		if restored is bool and not restored:
			push_error("SaveGameService: Game rejected save data")
			return false
		print("SaveGameService: Successfully loaded quicksave from " + path)
		return true
	else:
		push_error("SaveGameService: Target game node missing restore_from_save_data method")
		return false
