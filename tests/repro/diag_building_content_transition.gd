extends SceneTree

## Read-only transition audit. It intentionally uses the `diag_` prefix so the
## master runner does not turn incomplete content into a failing test while the
## building-authoring task is still in progress.


func _init() -> void:
	BuildingBlueprintLibrary.refresh()
	var authored := 0
	var ready := 0
	for entry in BuildingBlueprintLibrary.authored_entries():
		var runtime_key := str(entry["runtime_key"])
		var blueprint: Dictionary = BuildingBlueprints.get_blueprint(runtime_key)
		authored += 1
		var door_count := BuildingAccessPoints.authored_door_count(blueprint)
		var builder_doors := BuildingAccessPoints.construction_local_positions(blueprint).size()
		var staff_doors := BuildingAccessPoints.worker_local_positions(blueprint).size()
		var visitor_doors := BuildingAccessPoints.visitor_local_positions(blueprint).size()
		var zones: Array = blueprint.get("zones", [])
		var errors := BuildingAccessPoints.transition_errors(blueprint)
		var status := "READY" if errors.is_empty() else "NOT READY: %s" % ", ".join(errors)
		if errors.is_empty():
			ready += 1
		print("%s  %s  doors=%d builder=%d staff=%d visitor=%d zones=%d" % [
			status, runtime_key, door_count, builder_doors, staff_doors, visitor_doors, zones.size()])
	print("Authored transition readiness: %d/%d blueprints satisfy the access contract." % [ready, authored])
	quit(0)
