extends SceneTree

const TestDomainEconomyScript = preload("res://tests/domain/test_domain_economy.gd")
const TestDomainRoutingScript = preload("res://tests/domain/test_domain_routing.gd")
const TestDomainConstructionScript = preload("res://tests/domain/test_domain_construction.gd")
const TestDomainLogisticsScript = preload("res://tests/domain/test_domain_logistics.gd")
const TestDomainLaunchScript = preload("res://tests/domain/test_domain_launch.gd")
const TestDomainNavigationScript = preload("res://tests/domain/test_domain_navigation.gd")
const TestDomainBuildingEditorScript = preload("res://tests/domain/test_domain_building_editor.gd")
const TestDomainTerrainScript = preload("res://tests/domain/test_domain_terrain.gd")
const TestDomainTerrainMaterialsScript = preload("res://tests/domain/test_domain_terrain_materials.gd")
const TestSurfaceStateScript = preload("res://tests/features/world/test_surface_state.gd")
const TestTerrainMeshingScript = preload("res://tests/features/world/test_terrain_meshing.gd")
const TestTerrainBrushScript = preload("res://tests/features/world/test_terrain_brush.gd")
const TestMapDocumentScript = preload("res://tests/features/world/test_map_document.gd")
const TestDomainTerrainNavigationScript = preload("res://tests/domain/test_domain_terrain_navigation.gd")
const TestDomainWaterScript = preload("res://tests/domain/test_domain_water.gd")

const TestAIFrameworkScript = preload("res://tests/ai/test_ai_framework.gd")
const TestAINeedsScript = preload("res://tests/ai/test_ai_needs.gd")
const TestAIWorkProvidersScript = preload("res://tests/ai/test_ai_work_providers.gd")
const TestAILogisticsScript = preload("res://tests/ai/test_ai_logistics.gd")
const TestAIDomainScript = preload("res://tests/ai/test_ai_domain.gd")


const TestSaveLoadScript = preload("res://tests/test_save_load.gd")


func _init() -> void:
	print("==================================================")
	print("       GO TO HAPPYNESS - MASTER TEST RUNNER       ")
	print("==================================================")

	# 1. Run Domain Unit Tests
	print("\n[1/2] Running Domain Unit Tests...")
	TestDomainEconomyScript.run_all()
	TestDomainRoutingScript.run_all()
	TestDomainConstructionScript.run_all()
	TestDomainLogisticsScript.run_all()
	TestDomainLaunchScript.run_all()
	TestDomainNavigationScript.run_all()
	TestDomainBuildingEditorScript.run_all()
	TestDomainTerrainScript.run_all()
	TestDomainTerrainMaterialsScript.run_all()
	TestSurfaceStateScript.run_all()
	TestTerrainMeshingScript.run_all()
	TestTerrainBrushScript.run_all()
	TestMapDocumentScript.run_all()
	TestDomainTerrainNavigationScript.run_all()
	TestDomainWaterScript.run_all()
	TestSaveLoadScript.run_all()
	print("  => Domain Unit Tests PASSED.")



	# 2. Run AI Unit Tests
	print("\n[2/2] Running AI Unit Tests...")
	TestAIFrameworkScript.run_all()
	TestAINeedsScript.run_all()
	TestAIWorkProvidersScript.run_all()
	TestAILogisticsScript.run_all()
	TestAIDomainScript.run_all()
	print("  => AI Unit Tests PASSED.")

	print("\n==================================================")
	print(" SUCCESS: All Domain & AI test suites passed.")
	print("==================================================")

	quit(0)
