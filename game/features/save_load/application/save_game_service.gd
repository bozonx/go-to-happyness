class_name SaveGameService
extends RefCounted

## Application service managing save and load operations.

const QUICKSAVE_PATH := "user://saves/quicksave.json"
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")


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
			"unlocked_building_levels": s.unlocked_building_levels.duplicate() if "unlocked_building_levels" in s else {},
			"unlocked_systems": s.unlocked_systems.duplicate() if "unlocked_systems" in s else {},
			"equipment": s.equipment.duplicate(true),
			"era": int(s.era)
		}

	
	# 2. Simulation Clock
	if "clock" in game and game.clock != null:
		save_data.clock_state = {
			"minutes": game.clock.minutes
		}
		
	# 3. Camera
	save_data.camera_state = {
		"target": SaveDataScript.vector3_to_dict(game.get("camera_target")),
		"distance": game.get("camera_distance"),
		"yaw": game.get("camera_yaw"),
		"pitch": game.get("camera_pitch")
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
				
				if game.has_method("is_construction_site") and game.call("is_construction_site", record.node):
					var site = game.call("get_construction_site_data", record.node)
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
					"resource_id": pile.resource_type,
					"amount": pile.amount,
					"position": SaveDataScript.vector3_to_dict(pile.position)
				})
	save_data.resource_piles_state = piles_list

	# 6. Citizens
	var citizens_list: Array = []
	if "citizens" in game:
		for citizen in game.citizens:
			if is_instance_valid(citizen):
				var pockets_content: Array = citizen.pockets_get_content() if citizen.has_method("pockets_get_content") else []
				citizens_list.append({
					"ai_id": citizen.ai_id,
					"first_name": citizen.first_name,
					"last_name": citizen.last_name,
					"age": citizen.age,
					"is_hero": citizen.is_hero,
					"position": SaveDataScript.vector3_to_dict(citizen.global_position),
					"needs": {
						"hunger": citizen.hunger,
						"fatigue": citizen.fatigue,
						"comfort": citizen.comfort,
						"health": citizen.health
					},
					"specialization": citizen.specialization,
					"active_role": citizen.active_role,
					"pockets": pockets_content
				})
	save_data.citizens_state = citizens_list
	save_data.world_state = {
		"next_ai_citizen_id": game.get("_next_ai_citizen_id")
	}

	var success := save_data.save_to_file(path)
	if success:
		print("SaveGameService: Successfully saved quicksave to " + path)
	return success


static func load_game(game: Node, path: String = QUICKSAVE_PATH) -> bool:
	if game == null:
		push_error("SaveGameService: Cannot load into null game instance")
		return false
		
	var save_data := SaveDataScript.new()
	if not save_data.load_from_file(path):
		push_error("SaveGameService: Failed to read save file from " + path)
		return false
	
	if game.has_method("restore_from_save_data"):
		game.call("restore_from_save_data", save_data)
		print("SaveGameService: Successfully loaded quicksave from " + path)
		return true
	else:
		push_error("SaveGameService: Target game node missing restore_from_save_data method")
		return false
