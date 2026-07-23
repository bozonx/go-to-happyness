extends SceneTree

const TestDomainEconomyScript = preload("res://tests/domain/test_domain_economy.gd")
const TestDomainRoutingScript = preload("res://tests/domain/test_domain_routing.gd")
const TestDomainConstructionScript = preload("res://tests/domain/test_domain_construction.gd")
const TestDomainLogisticsScript = preload("res://tests/domain/test_domain_logistics.gd")


const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")


func _init() -> void:
	TestDomainEconomyScript.run_all()
	TestDomainRoutingScript.run_all()
	TestDomainConstructionScript.run_all()
	TestDomainLogisticsScript.run_all()
	print("SUCCESS: All domain sub-tests passed successfully.")
	quit(0)
