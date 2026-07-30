extends SceneTree

const TestDomainConstructionScript = preload("res://tests/domain/test_domain_construction.gd")

func _init() -> void:
	print("=== Construction tests only ===")
	TestDomainConstructionScript._test_construction_site_uses_building_entrance()
	print("=== Done ===")
	quit(0)
