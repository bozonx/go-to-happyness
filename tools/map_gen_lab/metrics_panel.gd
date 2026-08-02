extends PanelContainer

## The §6 acceptance conditions in real time (procedural_map_generation.md §7.1).
##
## Two columns on purpose: the map just generated and the one before it. Judging
## a recipe means comparing neighbouring seeds — a recipe that only works on one
## seed is a bad recipe — and a panel that shows only the current numbers makes
## that comparison a memory exercise.
##
## Failures are shown in full and never summarised into "rejected": the reason is
## the useful half of a verdict.

var _previous: GenerationReport = null


func show_report(recipe: MapRecipe, report: GenerationReport, attempts: int) -> void:
	if report == null:
		return
	if report.is_rejected_recipe():
		%Verdict.text = "RECIPE REFUSED"
		%Metrics.text = "—"
		%Failures.text = "\n".join(report.recipe_errors)
		%Timings.text = "—"
		%Notes.text = ""
		return
	%Verdict.text = "%s — seed %d, attempt %d of %d" % [
		report.verdict().to_upper(), report.seed, report.attempt + 1, attempts,
	]
	%Metrics.text = "\n".join(_paired_lines(recipe, report))
	%Failures.text = "\n".join(report.failures)
	%Timings.text = "\n".join(report.timing_lines())
	%Notes.text = "\n".join(report.notes)
	_previous = report


## Current metrics with the previous run's number beside each one, so a change of
## seed or of a parameter reads as a difference rather than as a new screen.
func _paired_lines(recipe: MapRecipe, report: GenerationReport) -> Array[String]:
	var current := report.metric_lines(recipe)
	if _previous == null or _previous.metrics.is_empty():
		return current
	var previous := _previous.metric_lines(recipe)
	var lines: Array[String] = []
	for index in current.size():
		var was := previous[index].substr(14) if index < previous.size() else ""
		lines.append("%s   was %s" % [current[index], was.strip_edges()])
	return lines


func forget_previous() -> void:
	_previous = null
