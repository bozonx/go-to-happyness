class_name BuildingBlueprints
extends RefCounted


const BLOCK_SIZE := 1.0
const PANEL_THICKNESS := 0.5

const COLORS := {
	"foundation": Color("776d60"),
	"house": Color("91a9bb"),
	"warehouse": Color("c78d52"),
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
	"tent": Color("c7a96a"),
	"forager_tent": Color("739350"),
	"craft_tent": Color("a46b46"),
	"water_store": Color("4d8fa8"),
	"dugout": Color("8a6549"),
	"earth_house": Color("9b7655"),
	"smithy": Color("65686d"),
	"hide_worker": Color("a98259"),
}


static func get_blueprint(building_type: String) -> Dictionary:
	match building_type:
		"campfire": return _park_blueprint()
		"tent", "forager_tent", "craft_tent", "water_store", "dugout", "earth_house", "smithy", "hide_worker": return _enclosed_blueprint(building_type, Vector2i(4, 4), 2, "gable")
		"warehouse": return _enclosed_blueprint("warehouse", Vector2i(5, 5), 3, "shed")
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
		_: return _enclosed_blueprint("house", Vector2i(5, 5), 3, "gable")


static func create_module(module: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = module.position
	body.rotation_degrees = module.get("rotation", Vector3.ZERO)
	body.set_meta("building_module", true)
	body.set_meta("module_kind", module.kind)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = module.size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = module.color
	material.roughness = 0.9
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = module.size
	collision.shape = shape
	body.add_child(collision)
	return body


static func _enclosed_blueprint(building_type: String, footprint: Vector2i, height: int, roof_style: String) -> Dictionary:
	var modules: Array[Dictionary] = []
	_add_floor(modules, footprint, building_type)
	_add_enclosing_walls(modules, footprint, height, building_type)
	_add_roof(modules, footprint, height, roof_style, building_type)
	return {"type": building_type, "footprint": footprint, "entrance": Vector2i(0, -footprint.y / 2), "modules": modules}


static func _add_floor(modules: Array[Dictionary], footprint: Vector2i, building_type: String) -> void:
	for x in range(footprint.x):
		for z in range(footprint.y):
			modules.append(_module(Vector3(_axis_coordinate(x, footprint.x), 0.25, _axis_coordinate(z, footprint.y)), Vector3(1.0, PANEL_THICKNESS, 1.0), "floor", COLORS.foundation))


static func _add_enclosing_walls(modules: Array[Dictionary], footprint: Vector2i, height: int, building_type: String) -> void:
	var half_x := (footprint.x - 1) * 0.5
	var half_z := (footprint.y - 1) * 0.5
	for level in range(height):
		var y := 0.5 + level
		for x_index in range(footprint.x):
			var x := _axis_coordinate(x_index, footprint.x)
			# The two missing front modules form a real 1x2 metre doorway.
			if not (is_zero_approx(x) and level < 2):
				modules.append(_module(Vector3(x, y, -half_z), Vector3(1.0, 1.0, PANEL_THICKNESS), "wall", COLORS[building_type]))
			modules.append(_module(Vector3(x, y, half_z), Vector3(1.0, 1.0, PANEL_THICKNESS), "wall", COLORS[building_type]))
		for z_index in range(1, footprint.y - 1):
			var z := _axis_coordinate(z_index, footprint.y)
			# Window openings are empty modules on both side walls.
			if not (level == 1 and z_index % 2 == 0):
				modules.append(_module(Vector3(-half_x, y, z), Vector3(PANEL_THICKNESS, 1.0, 1.0), "wall", COLORS[building_type]))
				modules.append(_module(Vector3(half_x, y, z), Vector3(PANEL_THICKNESS, 1.0, 1.0), "wall", COLORS[building_type]))


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
	return {"type": "sawmill", "footprint": footprint, "entrance": Vector2i(0, -3), "modules": modules}


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


static func _module(position: Vector3, size: Vector3, kind: String, color: Color, rotation := Vector3.ZERO) -> Dictionary:
	return {"position": position, "size": size, "kind": kind, "color": color, "rotation": rotation}


static func _axis_coordinate(index: int, count: int) -> float:
	return index - (count - 1) * 0.5
