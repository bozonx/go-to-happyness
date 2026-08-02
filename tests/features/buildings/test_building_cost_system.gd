extends SceneTree

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")


func _init() -> void:
	print("--- Running test_building_cost_system.gd ---")
	_test_material_block_counts()
	_test_manual_cost()
	_test_blueprint_json_serialization()
	print("--- test_building_cost_system.gd PASSED ALL TESTS ---")
	quit(0)


func _test_material_block_counts() -> void:
	var bp := BuildingBlueprintScript.new()
	for i in range(3):
		bp.blocks.append(BlueprintBlockScript.new(Vector3i(i, 0, 0), &"cube", 0, &"earth"))
	bp.blocks.append(BlueprintBlockScript.new(Vector3i(3, 0, 0), &"cube", 0, &"stone"))
	assert(bp.block_counts_by_material() == {&"earth": 3, &"stone": 1})
	assert(bp.construction_cost.is_empty(), "block counts are only an authoring hint")


func _test_manual_cost() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.manual_costs = {"logs": 12, "stone": 4, "ignored": 0}
	bp.recalculate_construction_cost()
	assert(bp.construction_cost == {"logs": 12, "stone": 4})


func _test_blueprint_json_serialization() -> void:
	print("Testing blueprint JSON serialization with cost fields...")
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_cost_building"
	bp.name = "Тестовое здание"
	bp.manual_costs = {"soil": 7, "stone": 2}

	var b := BlueprintBlockScript.new()
	b.pos = Vector3i(0, 0, 0)
	b.block_id = &"cube"
	b.material_id = &"earth_stone"
	bp.blocks.append(b)

	bp.recalculate_construction_cost()
	var json_str := bp.to_json()

	var loaded := BuildingBlueprintScript.from_json(json_str)
	assert(loaded != null, "Blueprint deserialized from JSON must not be null")
	assert(int(loaded.manual_costs.get("soil", 0)) == 7)
	assert(int(loaded.manual_costs.get("stone", 0)) == 2)
	assert(int(loaded.construction_cost.get("soil", 0)) == 7)
	assert(int(loaded.construction_cost.get("stone", 0)) == 2)
