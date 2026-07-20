extends SceneTree

const TestAIFrameworkScript = preload("res://tests/ai/test_ai_framework.gd")
const TestAINeedsScript = preload("res://tests/ai/test_ai_needs.gd")
const TestAIWorkProvidersScript = preload("res://tests/ai/test_ai_work_providers.gd")
const TestAILogisticsScript = preload("res://tests/ai/test_ai_logistics.gd")


func _init() -> void:
	TestAIFrameworkScript.run_all()
	TestAINeedsScript.run_all()
	TestAIWorkProvidersScript.run_all()
	TestAILogisticsScript.run_all()
	print("SUCCESS: All AI sub-tests passed successfully.")
	quit(0)
