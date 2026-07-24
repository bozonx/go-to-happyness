extends SceneTree

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")


func _init() -> void:
	print("--- Running test_building_cost_system.gd ---")
	_test_era_material_compositions()
	_test_auto_cost_calculation_with_ceil()
	_test_extra_non_block_costs()
	_test_manual_cost_override()
	_test_blueprint_json_serialization()
	print("--- test_building_cost_system.gd PASSED ALL TESTS ---")
	quit(0)


func _test_era_material_compositions() -> void:
	print("Testing era material compositions...")
	assert(BuildingMaterialCatalogScript.has_material(&"earth_stone"), "earth_stone material must exist")
	assert(BuildingMaterialCatalogScript.has_material(&"stone_mortar"), "stone_mortar material must exist")

	var comp_earth_stone := BuildingMaterialCatalogScript.resource_composition(&"earth_stone")
	assert(comp_earth_stone.get("soil", 0.0) == 0.5, "earth_stone requires 0.5 soil")
	assert(comp_earth_stone.get("stone", 0.0) == 0.5, "earth_stone requires 0.5 stone")

	var comp_stone_mortar := BuildingMaterialCatalogScript.resource_composition(&"stone_mortar")
	assert(comp_stone_mortar.get("stone", 0.0) == 0.8, "stone_mortar requires 0.8 stone")
	assert(comp_stone_mortar.get("clay", 0.0) == 0.2, "stone_mortar requires 0.2 clay")


func _test_auto_cost_calculation_with_ceil() -> void:
	print("Testing auto cost calculation and ceil rounding...")
	var bp := BuildingBlueprintScript.new()
	bp.category = &"earth"

	# Add 3 earth_stone blocks (3 * 0.5 soil = 1.5 -> ceili 2; 3 * 0.5 stone = 1.5 -> ceili 2)
	for i in range(3):
		var b := BlueprintBlockScript.new()
		b.pos = Vector3i(i, 0, 0)
		b.block_id = &"cube"
		b.material_id = &"earth_stone"
		bp.blocks.append(b)

	bp.recalculate_construction_cost()
	assert(bp.construction_cost.get("soil", 0) == 2, "1.5 soil must round up (ceili) to 2")
	assert(bp.construction_cost.get("stone", 0) == 2, "1.5 stone must round up (ceili) to 2")


func _test_extra_non_block_costs() -> void:
	print("Testing extra non-block costs...")
	var bp := BuildingBlueprintScript.new()
	bp.category = &"tent"

	var b := BlueprintBlockScript.new()
	b.pos = Vector3i(0, 0, 0)
	b.block_id = &"cube"
	b.material_id = &"branches"
	bp.blocks.append(b)

	bp.extra_costs = {"tarp": 2, "coins": 5}
	bp.recalculate_construction_cost()

	assert(bp.construction_cost.get("branches", 0) == 1, "1 branch block should give 1 branches")
	assert(bp.construction_cost.get("tarp", 0) == 2, "Extra cost tarp = 2 must be included")
	assert(bp.construction_cost.get("coins", 0) == 5, "Extra cost coins = 5 must be included")


func _test_manual_cost_override() -> void:
	print("Testing manual cost override...")
	var bp := BuildingBlueprintScript.new()
	bp.category = &"wood"

	# Add 10 log blocks
	for i in range(10):
		var b := BlueprintBlockScript.new()
		b.pos = Vector3i(i, 0, 0)
		b.block_id = &"cube"
		b.material_id = &"logs"
		bp.blocks.append(b)

	bp.cost_mode = &"manual"
	bp.manual_costs = {"coins": 100, "rare_crystal": 1}
	bp.recalculate_construction_cost()

	assert(bp.construction_cost.get("logs", 0) == 0, "In manual mode, block logs must not dictate cost")
	assert(bp.construction_cost.get("coins", 0) == 100, "Manual cost coins = 100")
	assert(bp.construction_cost.get("rare_crystal", 0) == 1, "Manual cost rare_crystal = 1")


func _test_blueprint_json_serialization() -> void:
	print("Testing blueprint JSON serialization with cost fields...")
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_cost_building"
	bp.name = "Тестовое здание"
	bp.category = &"earth"
	bp.cost_mode = &"auto"
	bp.extra_costs = {"tarp": 1}

	var b := BlueprintBlockScript.new()
	b.pos = Vector3i(0, 0, 0)
	b.block_id = &"cube"
	b.material_id = &"earth_stone"
	bp.blocks.append(b)

	bp.recalculate_construction_cost()
	var json_str := bp.to_json()

	var loaded := BuildingBlueprintScript.from_json(json_str)
	assert(loaded != null, "Blueprint deserialized from JSON must not be null")
	assert(loaded.cost_mode == &"auto", "cost_mode must be auto")
	assert(loaded.extra_costs.get("tarp", 0) == 1, "extra_costs tarp must be 1")
	assert(loaded.construction_cost.get("soil", 0) == 1, "soil must be 1")
	assert(loaded.construction_cost.get("stone", 0) == 1, "stone must be 1")
