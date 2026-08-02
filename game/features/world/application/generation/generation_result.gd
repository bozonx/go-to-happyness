class_name GenerationResult
extends RefCounted

## What `TerrainGenerationService.generate` hands back
## (procedural_map_generation.md §8).
##
## The grids themselves are not in here: the service wrote them, once, through
## the same bulk path that keeps mesh and navigation in step. What the caller gets
## is the verdict and everything needed to explain it — the report with the
## metrics, and the context with the mountain skeleton, the drainage field and the
## water plan the overlays of the laboratory draw.

var recipe: MapRecipe = null
var report: GenerationReport = null
var context: GenerationContext = null
## Every attempt made, including the accepted one. A recipe that only works on
## one seed is a bad recipe (§7.1), and this is where that shows.
var attempts: Array[GenerationReport] = []


func is_accepted() -> bool:
	return report != null and report.accepted


func failure_summary() -> String:
	if report == null:
		return "no report"
	if report.is_rejected_recipe():
		return "recipe refused: %s" % "; ".join(report.recipe_errors)
	if report.accepted:
		return ""
	return "; ".join(report.failures)
