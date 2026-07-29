class_name MapTestRunService
extends RefCounted

## Read-only preflight for an editor test run. The editor owns buttons and scene
## changes; this service owns the rule that an unsaved map must be launchable
## before handing it to the host runtime.

func validate(document: MapDocument, nav_grid: NavGrid) -> Dictionary:
	var result := {"errors": [], "warnings": []}
	if document == null:
		result["errors"] = ["карта отсутствует"]
		return result
	result["errors"] = MapValidator.validate(
		document, document.terrain, document.water, nav_grid,
	)
	result["warnings"] = MapValidator.warnings(document, nav_grid)
	return result
