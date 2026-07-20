class_name BuildingBlueprints
extends RefCounted


const BuildingModuleScene = preload("res://game/features/buildings/presentation/building_module.tscn")

const BLOCK_SIZE := 1.0
const PANEL_THICKNESS := 0.5

const COLORS := {
	"foundation": Color("776d60"),
	"house": Color("91a9bb"),
	"warehouse": Color("8a6549"), # Dirt heap color
	"straw_warehouse": Color("c7a96a"),
	"straw_warehouse_roof": Color("78513f"),
	"tarp_warehouse": Color("8a9aa8"),
	"tarp_warehouse_roof": Color("5a6a7a"),
	"sawmill": Color("af6f3b"),
	"farm": Color("788f45"),
	"canteen": Color("d4a64f"),
	"school": Color("8d7fc0"),
	"park": Color("4b8d54"),
	"brick_factory": Color("b85e42"),
	"materials_factory": Color("78828b"),
	"recycling_factory": Color("4e9a86"),
	"metal_factory": Color("687784"),
	"city_hall": Color("b7a552"),
	"leisure_center": Color("b06f9b"),
	"house_roof": Color("476573"),
	"warehouse_roof": Color("78513f"),
	"sawmill_roof": Color("8b6540"),
	"canteen_roof": Color("a54e38"),
	"school_roof": Color("4f477b"),
	"brick_factory_roof": Color("703c35"),
	"materials_factory_roof": Color("47545d"),
	"recycling_factory_roof": Color("27665e"),
	"metal_factory_roof": Color("394651"),
	"city_hall_roof": Color("6b6040"),
	"leisure_center_roof": Color("704065"),
	"campfire": Color("b85e42"),
	"campfire_lvl2": Color("b85e42"),
	"campfire_lvl3": Color("c56a3a"),
	"gathering_place": Color("6e4a2b"),
	"cook_campfire": Color("c56a3a"),
	"cook_campfire_lvl2": Color("c56a3a"),
	"cook_campfire_lvl3": Color("d4773e"),
	"tent": Color("c7a96a"),
	"straw_tent": Color("c7a96a"),
	"tarp_tent": Color("8a9aa8"),
	"forager_tent": Color("739350"),
	"straw_forager_tent": Color("739350"),
	"tarp_forager_tent": Color("587a3f"),
	"materials_yard": Color("8a7b4f"),
	"straw_materials_yard": Color("8a7b4f"),
	"tarp_materials_yard": Color("6e7a8a"),
	"craft_tent": Color("a46b46"),
	"straw_craft_tent": Color("a46b46"),
	"tarp_craft_tent": Color("7a6b8a"),
	"dew_collector": Color("5f95ab"),
	"advanced_dew_collector": Color("4fa2c0"),
	"house_lvl2": Color("859eaf"),
	"house_lvl3": Color("7992a3"),
	"pond": Color("3f7fa0"),
	"dugout": Color("8a6549"),
	"earth_house": Color("9b7655"),
	"smithy": Color("65686d"),
	"hide_worker": Color("a98259"),
	"straw_trade_tent": Color("c7a96a"),
	"tarp_trade_tent": Color("8a9aa8"),
	"earth_market": Color("8a6549"),
	"clay_house": Color("b87a50"),
	"clay_workshop": Color("c28558"),
	"clay_market": Color("a6683c"),
	"stone_house": Color("8a8d8f"),
	"masonry_workshop": Color("76797b"),
	"stone_market": Color("6e7173"),
	"stone_house_roof": Color("505355"),
	"masonry_workshop_roof": Color("46484a"),
	"stone_market_roof": Color("3c3d3e"),
	"wood_market": Color("af6f3b"),
	"brick_market": Color("b85e42"),
	"earth_assembly": Color("7a5840"),
	"dugout_kitchen": Color("825d43"),
	"clay_lodge": Color("c0855c"),
	"clay_bakery": Color("c57b4c"),
	"wood_town_hall": Color("8b6540"),
	"stone_prefecture": Color("707275"),
	"stone_tavern": Color("7d8082"),
	"builders_guild": Color("747b80"),
	"brick_city_hall": Color("b7a552"),
	"brick_restaurant": Color("a2583d"),
	"brick_house": Color("b4533a"),
	"construction_company": Color("a94b3c"),
	"employment_office": Color("8a8f99"),
	"toilet_tent": Color("ab8e5b"),
	"tarp_toilet": Color("7a8a9a"),
	"toilet_earth": Color("8a6549"),
	"toilet_earth_lvl2": Color("7f5a3e"),
	"toilet_earth_lvl3": Color("744f33"),
	"toilet_clay": Color("b87a50"),
	"toilet_clay_lvl2": Color("ad6f45"),
	"toilet_clay_lvl3": Color("a2643a"),
	"toilet_wood": Color("af6f3b"),
	"toilet_wood_lvl2": Color("a46430"),
	"toilet_wood_lvl3": Color("995925"),
	"toilet_stone": Color("8a8d8f"),
	"toilet_stone_lvl2": Color("7f8284"),
	"toilet_stone_lvl3": Color("747779"),
	"toilet_brick": Color("b85e42"),
	"toilet_brick_lvl2": Color("ad5337"),
	"toilet_brick_lvl3": Color("a2482c"),
	"boundary_post": Color("8a7b4f"),
}


# Buildings with two worker entrances (front and back), used by staff and couriers.
const DUAL_WORKER_ENTRANCE_BUILDINGS := {
	"sawmill": true,
	"school": true,
	"canteen": true,
	"city_hall": true,
	"wood_town_hall": true,
	"brick_city_hall": true,
	"employment_office": true,
	"construction_company": true,
	"materials_factory": true,
	"recycling_factory": true,
	"metal_factory": true,
	"brick_factory": true,
	"builders_guild": true,
	"stone_prefecture": true,
	"stone_tavern": true,
}

# Buildings that have a visitor entrance (for guests/clients), separate from worker entrances.
const VISITOR_ENTRANCE_BUILDINGS := {
	"campfire": true,
	"campfire_lvl2": true,
	"campfire_lvl3": true,
	"cook_campfire": true,
	"cook_campfire_lvl2": true,
	"cook_campfire_lvl3": true,
	"canteen": true,
	"school": true,
	"city_hall": true,
	"wood_town_hall": true,
	"brick_city_hall": true,
	"earth_assembly": true,
	"clay_lodge": true,
	"stone_prefecture": true,
	"stone_tavern": true,
	"brick_restaurant": true,
	"dugout_kitchen": true,
	"clay_bakery": true,
	"employment_office": true,
	"straw_trade_tent": true,
	"tarp_trade_tent": true,
	"earth_market": true,
	"clay_market": true,
	"wood_market": true,
	"stone_market": true,
	"brick_market": true,
	"gathering_place": true,
}

# Buildings with only a visitor entrance and no worker entrance (e.g. recreation).
const VISITOR_ONLY_BUILDINGS := {
	"park": true,
	"leisure_center": true,
	"gathering_place": true,
}


static func get_blueprint(building_type: String) -> Dictionary:
	match building_type:
		"campfire", "campfire_lvl2", "campfire_lvl3": return _campfire_blueprint_for(building_type)
		"gathering_place": return _gathering_place_blueprint()
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3": return _cook_campfire_blueprint(building_type)
		"dew_collector": return _water_collector_blueprint("dew_collector", Vector2i(2, 2))
		"advanced_dew_collector": return _water_collector_blueprint("advanced_dew_collector", Vector2i(3, 3))
		"pond": return _pond_blueprint()
		"tent", "straw_tent", "tarp_tent", "forager_tent", "straw_forager_tent", "tarp_forager_tent", "materials_yard", "straw_materials_yard", "tarp_materials_yard", "craft_tent", "straw_craft_tent", "tarp_craft_tent", "straw_trade_tent", "tarp_trade_tent": return _enclosed_blueprint(building_type, Vector2i(4, 4), 2, "gable")
		"house": return _enclosed_blueprint("house", Vector2i(4, 4), 3, "gable")
		"house_lvl2": return _enclosed_blueprint("house_lvl2", Vector2i(5, 5), 3, "gable")
		"house_lvl3": return _enclosed_blueprint("house_lvl3", Vector2i(6, 6), 3, "gable")
		"dugout", "earth_house", "smithy", "hide_worker", "earth_market", "earth_assembly", "dugout_kitchen": return _enclosed_blueprint(building_type, Vector2i(4, 4), 2, "gable")
		"clay_house", "clay_workshop", "clay_market", "clay_lodge", "clay_bakery": return _enclosed_blueprint(building_type, Vector2i(4, 4), 2, "gable")
		"stone_house", "masonry_workshop", "stone_market", "stone_prefecture", "stone_tavern", "builders_guild": return _enclosed_blueprint(building_type, Vector2i(5, 5), 3, "hip")
		"wood_town_hall": return _enclosed_blueprint("wood_town_hall", Vector2i(6, 6), 3, "hip")
		"brick_city_hall": return _enclosed_blueprint("brick_city_hall", Vector2i(7, 6), 4, "hip")
		"brick_restaurant": return _enclosed_blueprint("brick_restaurant", Vector2i(7, 5), 3, "hip")
		"brick_house": return _enclosed_blueprint("brick_house", Vector2i(5, 5), 3, "gable")
		"construction_company": return _enclosed_blueprint("construction_company", Vector2i(7, 6), 3, "shed")
		"employment_office": return _enclosed_blueprint("employment_office", Vector2i(5, 5), 3, "hip")
		"warehouse": return _heap_blueprint("warehouse", Vector2i(5, 5))
		"straw_warehouse": return _enclosed_blueprint("straw_warehouse", Vector2i(5, 5), 3, "shed")
		"tarp_warehouse": return _enclosed_blueprint("tarp_warehouse", Vector2i(5, 5), 3, "shed")
		"sawmill": return _sawmill_blueprint()
		"farm": return _farm_blueprint()
		"canteen": return _enclosed_blueprint("canteen", Vector2i(7, 5), 3, "hip")
		"school": return _enclosed_blueprint("school", Vector2i(7, 5), 4, "steep_gable")
		"park": return _park_blueprint()
		"brick_factory": return _enclosed_blueprint("brick_factory", Vector2i(7, 6), 3, "shed")
		"materials_factory": return _enclosed_blueprint("materials_factory", Vector2i(8, 6), 3, "shed")
		"recycling_factory": return _enclosed_blueprint("recycling_factory", Vector2i(7, 6), 3, "shed")
		"metal_factory": return _enclosed_blueprint("metal_factory", Vector2i(7, 6), 3, "shed")
		"city_hall": return _enclosed_blueprint("city_hall", Vector2i(8, 6), 4, "hip")
		"leisure_center": return _enclosed_blueprint("leisure_center", Vector2i(8, 6), 3, "hip")
		"wood_market", "brick_market": return _enclosed_blueprint(building_type, Vector2i(5, 5), 3, "shed")
		"toilet_tent", "tarp_toilet": return _enclosed_blueprint(building_type, Vector2i(3, 3), 2, "gable")
		"toilet_earth", "toilet_earth_lvl2", "toilet_earth_lvl3": return _enclosed_blueprint(building_type, Vector2i(3, 3), 2, "gable")
		"toilet_clay", "toilet_clay_lvl2", "toilet_clay_lvl3": return _enclosed_blueprint(building_type, Vector2i(3, 3), 2, "gable")
		"toilet_wood", "toilet_wood_lvl2", "toilet_wood_lvl3": return _enclosed_blueprint(building_type, Vector2i(3, 3), 2, "gable")
		"toilet_stone", "toilet_stone_lvl2", "toilet_stone_lvl3": return _enclosed_blueprint(building_type, Vector2i(3, 3), 2, "hip")
		"toilet_brick", "toilet_brick_lvl2", "toilet_brick_lvl3": return _enclosed_blueprint(building_type, Vector2i(3, 3), 2, "shed")
		"boundary_post": return _boundary_post_blueprint()
		_: return _enclosed_blueprint(building_type, Vector2i(5, 5), 3, "gable")


static func create_module(module: Dictionary) -> StaticBody3D:
	var body: StaticBody3D = BuildingModuleScene.instantiate()
	body.position = module.position
	body.rotation_degrees = module.get("rotation", Vector3.ZERO)
	body.set_meta("building_module", true)
	body.set_meta("module_kind", module.kind)

	var mesh_instance := body.get_node("MeshInstance3D") as MeshInstance3D
	var mesh := BoxMesh.new()
	mesh.size = module.size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = module.color
	material.roughness = 0.9
	mesh_instance.material_override = material

	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	var shape := BoxShape3D.new()
	shape.size = module.size
	collision.shape = shape
	return body


static func _enclosed_blueprint(building_type: String, footprint: Vector2i, height: int, roof_style: String) -> Dictionary:
	var modules: Array[Dictionary] = []
	_add_floor(modules, footprint, building_type)
	var worker_entrances: Array[Vector2i] = []
	if building_type in DUAL_WORKER_ENTRANCE_BUILDINGS:
		worker_entrances = [Vector2i(0, -footprint.y / 2), Vector2i(0, footprint.y / 2)]
	_add_enclosing_walls(modules, footprint, height, building_type, worker_entrances)
	_add_roof(modules, footprint, height, roof_style, building_type)
	var blueprint := {"type": building_type, "footprint": footprint, "entrance": Vector2i(0, -footprint.y / 2), "modules": modules}
	if not worker_entrances.is_empty():
		blueprint.worker_entrances = worker_entrances
	return blueprint


static func _add_floor(modules: Array[Dictionary], footprint: Vector2i, building_type: String) -> void:
	for x in range(footprint.x):
		for z in range(footprint.y):
			modules.append(_module(Vector3(_axis_coordinate(x, footprint.x), 0.25, _axis_coordinate(z, footprint.y)), Vector3(1.0, PANEL_THICKNESS, 1.0), "floor", COLORS.foundation))


static func _add_enclosing_walls(modules: Array[Dictionary], footprint: Vector2i, height: int, building_type: String, doorways: Array[Vector2i] = []) -> void:
	var half_x := (footprint.x - 1) * 0.5
	var half_z := (footprint.y - 1) * 0.5
	var front_doors: Dictionary = {}
	var back_doors: Dictionary = {}
	var left_doors: Dictionary = {}
	var right_doors: Dictionary = {}
	for doorway in doorways:
		if doorway.y == -footprint.y / 2:
			front_doors[doorway.x] = true
		elif doorway.y == footprint.y / 2:
			back_doors[doorway.x] = true
		if doorway.x == -footprint.x / 2:
			left_doors[doorway.y] = true
		elif doorway.x == footprint.x / 2:
			right_doors[doorway.y] = true
	for level in range(height):
		var y := 0.5 + level
		for x_index in range(footprint.x):
			var x := _axis_coordinate(x_index, footprint.x)
			if not (roundi(x) in front_doors and level < 2):
				modules.append(_module(Vector3(x, y, -half_z), Vector3(1.0, 1.0, PANEL_THICKNESS), "wall", COLORS[building_type]))
			if not (roundi(x) in back_doors and level < 2):
				modules.append(_module(Vector3(x, y, half_z), Vector3(1.0, 1.0, PANEL_THICKNESS), "wall", COLORS[building_type]))
		for z_index in range(1, footprint.y - 1):
			var z := _axis_coordinate(z_index, footprint.y)
			# Window openings are empty modules on both side walls.
			if not (level == 1 and z_index % 2 == 0):
				if not (roundi(z) in left_doors and level < 2):
					modules.append(_module(Vector3(-half_x, y, z), Vector3(PANEL_THICKNESS, 1.0, 1.0), "wall", COLORS[building_type]))
				if not (roundi(z) in right_doors and level < 2):
					modules.append(_module(Vector3(half_x, y, z), Vector3(PANEL_THICKNESS, 1.0, 1.0), "wall", COLORS[building_type]))
	# Solid corner columns hide the seam where the front/back and side panels
	# meet, so the building reads as a proper box instead of four loose walls.
	var corner_color: Color = COLORS[building_type].darkened(0.18)
	var column_center_y := 0.5 + (height - 1) * 0.5
	for corner_x: float in [-half_x, half_x]:
		for corner_z: float in [-half_z, half_z]:
			modules.append(_module(Vector3(corner_x, column_center_y, corner_z), Vector3(0.62, height, 0.62), "corner", corner_color))


static func _add_roof(modules: Array[Dictionary], footprint: Vector2i, height: int, roof_style: String, building_type: String) -> void:
	var roof_color: Color = COLORS.get(building_type + "_roof", COLORS.house_roof)
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	match roof_style:
		"shed":
			for x in range(footprint.x + 1):
				modules.append(_module(Vector3(-half_x + x, height + 0.45 + x * 0.14, 0.0), Vector3(1.15, 0.28, footprint.y + 1.0), "roof", roof_color, Vector3(0.0, 0.0, -8.0)))
		"hip":
			for ring in range(3):
				var ring_size := Vector3(footprint.x + 1.0 - ring * 1.5, 0.3, footprint.y + 1.0 - ring * 1.5)
				modules.append(_module(Vector3(0.0, height + 0.25 + ring * 0.38, 0.0), ring_size, "roof", roof_color))
		"steep_gable":
			_add_gable_roof(modules, footprint, height, roof_color, 38.0, 0.62)
		_:
			_add_gable_roof(modules, footprint, height, roof_color, 27.0, 0.48)


static func _add_gable_roof(modules: Array[Dictionary], footprint: Vector2i, height: int, color: Color, angle: float, rise: float) -> void:
	var half_x := footprint.x * 0.5
	for side: float in [-1.0, 1.0]:
		for x_index in range(ceili(half_x)):
			var distance: float = x_index + 0.5
			var x: float = side * (half_x - distance)
			var y: float = height + 0.28 + (half_x - absf(x)) * rise
			modules.append(_module(Vector3(x, y, 0.0), Vector3(1.18, 0.28, footprint.y + 1.0), "roof", color, Vector3(0.0, 0.0, -side * angle)))


static func _sawmill_blueprint() -> Dictionary:
	var footprint := Vector2i(6, 5)
	var modules: Array[Dictionary] = []
	_add_floor(modules, footprint, "sawmill")
	var half_x := (footprint.x - 1) * 0.5
	var half_z := (footprint.y - 1) * 0.5
	for x: float in [-half_x, half_x]:
		for z: float in [-half_z, half_z]:
			for level in range(3):
				modules.append(_module(Vector3(x, 0.5 + level, z), Vector3(PANEL_THICKNESS, 1.0, PANEL_THICKNESS), "post", COLORS.sawmill))
	_add_roof(modules, footprint, 3, "shed", "sawmill")
	var worker_entrances := [Vector2i(0, -3), Vector2i(0, 3)]
	return {"type": "sawmill", "footprint": footprint, "entrance": Vector2i(0, -3), "worker_entrances": worker_entrances, "modules": modules}


static func _farm_blueprint() -> Dictionary:
	var footprint := Vector2i(7, 7)
	var modules: Array[Dictionary] = []
	for x in range(footprint.x):
		for z in range(footprint.y):
			var color := COLORS.farm.lightened(0.08 if (x + z) % 2 == 0 else 0.0)
			modules.append(_module(Vector3(_axis_coordinate(x, footprint.x), 0.12, _axis_coordinate(z, footprint.y)), Vector3(0.82, 0.24, 0.82), "field", color))
	return {"type": "farm", "footprint": footprint, "entrance": Vector2i(0, -3), "modules": modules}


static func _park_blueprint() -> Dictionary:
	var footprint := Vector2i(6, 6)
	var modules: Array[Dictionary] = []
	_add_floor(modules, footprint, "park")
	for offset in [Vector3(-2.0, 0.75, -2.0), Vector3(2.0, 0.75, -2.0), Vector3(-2.0, 0.75, 2.0), Vector3(2.0, 0.75, 2.0)]:
		modules.append(_module(offset, Vector3(0.35, 1.5, 0.35), "tree", Color("684630")))
		modules.append(_module(offset + Vector3.UP * 1.0, Vector3(1.25, 1.25, 1.25), "tree", Color("2d733d")))
	modules.append(_module(Vector3.ZERO, Vector3(3.0, 0.25, 0.5), "bench", Color("8a603c")))
	return {"type": "park", "footprint": footprint, "entrance": Vector2i(0, -3), "modules": modules}


static func _water_collector_blueprint(building_type: String, footprint: Vector2i) -> Dictionary:
	# A raised basin on four legs. Dew and rain trickle into the tray, so the
	# collector slowly fills the settlement's water up to its own limit.
	var modules: Array[Dictionary] = []
	var half_x := (footprint.x - 1) * 0.5
	var half_z := (footprint.y - 1) * 0.5
	var frame_color: Color = COLORS[building_type].darkened(0.25)
	for x: float in [-half_x, half_x]:
		for z: float in [-half_z, half_z]:
			modules.append(_module(Vector3(x, 0.5, z), Vector3(0.28, 1.0, 0.28), "post", frame_color))
	modules.append(_module(Vector3(0.0, 1.05, 0.0), Vector3(footprint.x + 0.2, 0.22, footprint.y + 0.2), "basin", frame_color))
	modules.append(_module(Vector3(0.0, 1.22, 0.0), Vector3(footprint.x - 0.2, 0.16, footprint.y - 0.2), "water", COLORS[building_type]))
	# A little collecting funnel above the tray.
	modules.append(_module(Vector3(0.0, 1.7, 0.0), Vector3(0.9, 0.7, 0.9), "funnel", frame_color, Vector3(0.0, 45.0, 0.0)))
	return {"type": building_type, "footprint": footprint, "entrance": Vector2i(0, -1), "modules": modules}


static func _pond_blueprint() -> Dictionary:
	var footprint := Vector2i(5, 5)
	var modules: Array[Dictionary] = []
	# A stone rim around a recessed water surface.
	var half_x := (footprint.x - 1) * 0.5
	var half_z := (footprint.y - 1) * 0.5
	for x in range(footprint.x):
		for z in range(footprint.y):
			var on_edge := x == 0 or z == 0 or x == footprint.x - 1 or z == footprint.y - 1
			if on_edge:
				modules.append(_module(Vector3(_axis_coordinate(x, footprint.x), 0.18, _axis_coordinate(z, footprint.y)), Vector3(1.0, 0.36, 1.0), "rim", Color("6f747a")))
	modules.append(_module(Vector3(0.0, 0.1, 0.0), Vector3(footprint.x - 1.4, 0.2, footprint.y - 1.4), "water", COLORS.pond))
	return {"type": "pond", "footprint": footprint, "entrance": Vector2i(0, -2), "modules": modules}


static func _campfire_blueprint_for(building_type: String) -> Dictionary:
	var footprint := Vector2i(5, 5)
	var modules: Array[Dictionary] = []
	modules.append(_module(Vector3(0.0, 0.05, 0.0), Vector3(4.6, 0.1, 4.6), "floor", Color("4f4438")))
	if building_type == "campfire_lvl2":
		_add_civic_fire_modules(modules)
	elif building_type == "campfire_lvl3":
		_add_pioneer_fire_modules(modules)
	else:
		_add_small_fire_modules(modules)
	return {"type": building_type, "footprint": footprint, "entrance": Vector2i(0, -3), "modules": modules}


static func _add_small_fire_modules(modules: Array[Dictionary]) -> void:
	modules.append(_module(Vector3(0.0, 0.2, 0.0), Vector3(1.0, 0.25, 0.25), "wood", Color("5c4033"), Vector3(0.0, 45.0, 0.0)))
	modules.append(_module(Vector3(0.0, 0.2, 0.0), Vector3(1.0, 0.25, 0.25), "wood", Color("5c4033"), Vector3(0.0, -45.0, 0.0)))
	modules.append(_module(Vector3(0.0, 0.42, 0.0), Vector3(0.45, 0.44, 0.45), "fire", Color("ff5a00")))


static func _add_civic_fire_modules(modules: Array[Dictionary]) -> void:
	modules.append(_module(Vector3.ZERO, Vector3(3.7, 0.14, 3.7), "civic_ground", Color("6d604d")))
	for angle_index in range(8):
		var angle := angle_index * TAU / 8.0
		modules.append(_module(Vector3(cos(angle) * 1.55, 0.22, sin(angle) * 1.55), Vector3(0.5, 0.35, 0.5), "stone", Color("6f747a")))
	modules.append(_module(Vector3(0.0, 0.25, 0.0), Vector3(1.3, 0.25, 0.25), "wood", Color("5c4033"), Vector3(0.0, 45.0, 0.0)))
	modules.append(_module(Vector3(0.0, 0.25, 0.0), Vector3(1.3, 0.25, 0.25), "wood", Color("5c4033"), Vector3(0.0, -45.0, 0.0)))
	modules.append(_module(Vector3(0.0, 0.52, 0.0), Vector3(0.7, 0.56, 0.7), "fire", Color("ff5a00")))


static func _add_pioneer_fire_modules(modules: Array[Dictionary]) -> void:
	for i in range(5):
		var y := 0.25 + i * 0.32
		var length := 3.6 - i * 0.48
		var spread := 1.25 - i * 0.18
		modules.append(_module(Vector3(-spread * 0.5, y, 0.0), Vector3(0.28, length, 0.28), "pioneer_log", Color("5c4033"), Vector3(0.0, 0.0, 22.0)))
		modules.append(_module(Vector3(spread * 0.5, y, 0.0), Vector3(0.28, length, 0.28), "pioneer_log", Color("5c4033"), Vector3(0.0, 0.0, -22.0)))
	modules.append(_module(Vector3(0.0, 0.82, 0.0), Vector3(0.95, 1.35, 0.95), "tall_fire", Color("ff5a00")))
	for angle_index in range(6):
		var angle := angle_index * TAU / 6.0
		modules.append(_module(Vector3(cos(angle) * 2.05, 0.2, sin(angle) * 2.05), Vector3(1.3, 0.28, 0.32), "bench_log", Color("5c4033"), Vector3(0.0, -rad_to_deg(angle), 0.0)))

static func _heap_blueprint(building_type: String, footprint: Vector2i) -> Dictionary:
	var modules: Array[Dictionary] = []
	_add_floor(modules, footprint, building_type)
	modules.append(_module(Vector3(0.0, 0.4, 0.0), Vector3(2.5, 0.7, 2.5), "soil_heap", Color("8a6549")))
	modules.append(_module(Vector3(-0.6, 0.4, 0.6), Vector3(1.6, 0.3, 0.3), "wood_log", Color("5c4033"), Vector3(0.0, 30.0, 0.0)))
	modules.append(_module(Vector3(-0.4, 0.6, 0.5), Vector3(1.6, 0.3, 0.3), "wood_log", Color("5c4033"), Vector3(0.0, 15.0, 0.0)))
	modules.append(_module(Vector3(0.6, 0.4, -0.6), Vector3(1.2, 0.4, 1.2), "grass_pile", Color("739350"), Vector3(0.0, -25.0, 0.0)))
	modules.append(_module(Vector3(0.8, 0.3, 0.8), Vector3(0.5, 0.4, 0.5), "stone", Color("6f747a"), Vector3(15.0, 45.0, 0.0)))
	return {"type": building_type, "footprint": footprint, "entrance": Vector2i(0, -footprint.y / 2), "modules": modules}

static func _gathering_place_blueprint() -> Dictionary:
	var modules: Array[Dictionary] = []
	modules.append(_module(Vector3.ZERO, Vector3(5.6, 0.08, 8.0), "court", Color("526f45")))
	modules.append(_module(Vector3(0.0, 0.13, 0.0), Vector3(5.4, 0.04, 0.08), "center_line", Color("e8e4cf")))
	for x: float in [-2.55, 2.55]:
		modules.append(_module(Vector3(x, 0.14, 0.0), Vector3(0.08, 0.04, 7.8), "side_line", Color("e8e4cf")))
	for z: float in [-3.75, 3.75]:
		modules.append(_module(Vector3(0.0, 0.14, z), Vector3(5.4, 0.04, 0.08), "back_line", Color("e8e4cf")))
	for x: float in [-2.65, 2.65]:
		modules.append(_module(Vector3(x, 0.8, 0.0), Vector3(0.12, 1.6, 0.12), "net_post", Color("3a3a3a")))
	modules.append(_module(Vector3(0.0, 1.15, 0.0), Vector3(5.35, 0.12, 0.05), "net_top", Color("d8d8d8")))
	modules.append(_module(Vector3(0.0, 0.75, 0.0), Vector3(5.35, 0.08, 0.04), "net_bottom", Color("d8d8d8")))
	modules.append(_module(Vector3(1.4, 0.22, -2.2), Vector3(0.35, 0.16, 0.35), "shuttlecock_head", Color("f1f1e7")))
	modules.append(_module(Vector3(1.4, 0.42, -2.2), Vector3(0.55, 0.45, 0.55), "shuttlecock_skirt", Color("faf8e8"), Vector3(0.0, 45.0, 0.0)))
	return {"type": "gathering_place", "footprint": Vector2i(6, 8), "entrance": Vector2i(0, -5), "modules": modules}


static func _cook_campfire_blueprint(building_type: String) -> Dictionary:
	var footprint := Vector2i(3, 3)
	var modules: Array[Dictionary] = []
	modules.append(_module(Vector3(0.0, 0.05, 0.0), Vector3(3.0, 0.1, 3.0), "floor", Color("4f4438")))
	# Ring of stones around the fire.
	for angle_index in range(6):
		var angle := angle_index * PI / 3.0
		modules.append(_module(Vector3(cos(angle) * 0.9, 0.18, sin(angle) * 0.9), Vector3(0.35, 0.35, 0.35), "stone", Color("6f747a")))
	modules.append(_module(Vector3(0.0, 0.2, 0.0), Vector3(0.8, 0.25, 0.25), "wood", Color("5c4033"), Vector3(0.0, 45.0, 0.0)))
	if building_type in ["cook_campfire_lvl2", "cook_campfire_lvl3"]:
		modules.append(_module(Vector3(0.0, 0.2, 0.0), Vector3(0.8, 0.25, 0.25), "wood", Color("5c4033"), Vector3(0.0, -45.0, 0.0)))
	if building_type == "cook_campfire_lvl3":
		modules.append(_module(Vector3(0.0, 1.38, 0.0), Vector3(2.8, 0.18, 2.8), "cooking_canopy", Color("8a6549")))
		for x: float in [-1.15, 1.15]:
			for z: float in [-1.15, 1.15]:
				modules.append(_module(Vector3(x, 0.72, z), Vector3(0.12, 1.35, 0.12), "canopy_post", Color("5c4033")))
	modules.append(_module(Vector3(0.0, 0.35, 0.0), Vector3(0.4, 0.3, 0.4), "fire", Color("ff5a00")))
	# A cooking pot on a tripod above the flames.
	for leg_angle in [0.0, 2.1, 4.2]:
		modules.append(_module(Vector3(cos(leg_angle) * 0.5, 0.75, sin(leg_angle) * 0.5), Vector3(0.08, 1.5, 0.08), "tripod", Color("3a3a3a"), Vector3(0.0, 0.0, 18.0)))
	modules.append(_module(Vector3(0.0, 0.85, 0.0), Vector3(0.7, 0.55, 0.7), "pot", Color("2c2c2c")))
	return {"type": building_type, "footprint": footprint, "entrance": Vector2i(0, -1), "modules": modules}


static func worker_entrance_offsets(building_type: String) -> Array[Vector2i]:
	if building_type in VISITOR_ONLY_BUILDINGS:
		return []
	var blueprint := get_blueprint(building_type)
	var offsets: Array[Vector2i] = []
	if blueprint.has("worker_entrances"):
		for value in blueprint.worker_entrances:
			if value is Vector2i:
				offsets.append(value)
	elif blueprint.has("entrance"):
		offsets.append(blueprint.entrance)
	return offsets


static func visitor_entrance_offsets(building_type: String) -> Array[Vector2i]:
	if building_type not in VISITOR_ENTRANCE_BUILDINGS and building_type not in VISITOR_ONLY_BUILDINGS:
		return []
	var blueprint := get_blueprint(building_type)
	if blueprint.has("entrance"):
		return [blueprint.entrance]
	return []


static func has_worker_entrance(building_type: String) -> bool:
	return not worker_entrance_offsets(building_type).is_empty()


static func has_visitor_entrance(building_type: String) -> bool:
	return building_type in VISITOR_ENTRANCE_BUILDINGS or building_type in VISITOR_ONLY_BUILDINGS


static func _module(position: Vector3, size: Vector3, kind: String, color: Color, rotation := Vector3.ZERO) -> Dictionary:
	return {"position": position, "size": size, "kind": kind, "color": color, "rotation": rotation}


static func _axis_coordinate(index: int, count: int) -> float:
	return index - (count - 1) * 0.5


static func _boundary_post_blueprint() -> Dictionary:
	var color := COLORS["boundary_post"]
	var modules: Array[Dictionary] = [
		_module(Vector3(0.0, 0.25, 0.0), Vector3(0.12, 0.5, 0.12), "post", color),
	]
	return {
		"type": "boundary_post",
		"footprint": Vector2i(1, 1),
		"height": 1,
		"modules": modules,
		"entrance": Vector2i(0, 0),
	}
