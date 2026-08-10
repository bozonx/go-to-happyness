class_name GenerationReport
extends RefCounted

## What one generation attempt produced besides a map
## (procedural_map_generation.md §6, §7.1).
##
## The report is the reason the laboratory can judge a recipe instead of a
## screenshot: metrics, per-stage timings, notes from the stages and — when the
## map was refused — the conditions it broke. Timings are numbers on the screen
## and nothing else; stage 1 measures, it does not promise (§2.2).

var recipe_id := ""
var seed := 0
var attempt := 0
var accepted := false
## Metrics as `TerrainMetrics.measure` produced them.
var metrics: Dictionary = {}
## The §6 conditions this attempt broke. Empty when accepted.
var failures: Array[String] = []
## Recipe-level refusals — a contradictory request never reaches a stage.
var recipe_errors: Array[String] = []
var notes: Array[String] = []
## stage id -> milliseconds.
var stage_times: Dictionary = {}
var total_milliseconds := 0


func is_rejected_recipe() -> bool:
	return not recipe_errors.is_empty()


func verdict() -> String:
	if is_rejected_recipe():
		return "recipe refused"
	return "accepted" if accepted else "rejected"


## One line per metric, in a stable order, for the laboratory panel and for
## `--capture` output. Metrics whose target is known are marked, so an author sees
## which number is a measurement and which one is a promise.
func metric_lines(recipe: MapRecipe) -> Array[String]:
	if metrics.is_empty():
		return ["no metrics — the run did not reach verdict"] as Array[String]
	var lines: Array[String] = []
	lines.append("land          %.3f   target %.3f ±%.3f" % [
		metrics["land_fraction"], recipe.land_fraction, recipe.land_fraction_tolerance,
	])
	lines.append("mean height   %.2f    target %d" % [metrics["land_mean_height"], recipe.land_mean_height])
	lines.append("max height    %d      target %d" % [metrics["land_max_height"], recipe.land_max_height])
	lines.append("flat          %.3f   min %.3f" % [metrics["flat_fraction"], recipe.flat_fraction_min])
	lines.append("cliffs        %.3f   max %.3f" % [metrics["cliff_fraction"], recipe.cliff_fraction_max])
	lines.append("land compnt   %.3f   min %.3f" % [
		metrics["largest_land_component"], recipe.largest_land_component_min,
	])
	lines.append("reach         %.3f   walker · %.3f cart   (share of walkable land in one piece)" % [
		metrics["pedestrian_reach"], metrics["cart_reach"],
	])
	lines.append("walkable      %.3f   of the land a walker can stand on" % metrics["pedestrian_walkable"])
	lines.append("walls sealed  %s" % ("yes" if bool(metrics["walls_sealed"]) else "NO"))
	# The other half of §3.2: sealed says the edge holds, these two say it is a
	# mountainside rather than a box — how much of the rim can be stood on, and how
	# far its inner edge wanders. A slab scores 0.000 and 0.0 here.
	lines.append("rim           %.3f walkable foothills · %.1f cells of ragged edge   (min %.3f)" % [
		metrics.get("rim_walkable", 0.0), metrics.get("rim_edge_spread", 0.0), recipe.rim_walkable_min,
	])
	lines.append("rivers        %d/%d reach a receiver" % [metrics["rivers_terminated"], metrics["rivers_traced"]])
	lines.append("water         %d bodies, %d wet cells, %d damaged" % [
		metrics["water_bodies"], metrics["wet_cells"], metrics["damaged_water_bodies"],
	])
	lines.append("mountains     %d ranges, %d peaks, %d passes" % [
		metrics["ranges"], metrics["peaks"], metrics["passes"],
	])
	lines.append("heights       %d … %d" % [metrics["height_min"], metrics["height_max"]])
	lines.append("climate       %.1f °C   %.2f moisture   (targets %.1f / %.2f)" % [
		metrics["mean_temperature"], metrics["mean_moisture"],
		recipe.land_mean_temperature, recipe.land_mean_moisture,
	])
	lines.append("desert lakes  %.3f   max %.3f" % [
		metrics["desert_lake_fraction"], recipe.desert_lake_fraction_max,
	])
	lines.append("biomes        %s" % _biome_summary())
	return lines


## The biome mask as shares of the land, biggest first — the line that says what
## kind of world the recipe actually produced, as opposed to what shape it has.
func _biome_summary() -> String:
	var shares: Dictionary = metrics.get("biome_shares", {})
	if shares.is_empty():
		return "—"
	var ids: Array = shares.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(shares[a]) > float(shares[b]))
	var parts: Array[String] = []
	for id: String in ids:
		parts.append("%s %d%%" % [id, roundi(float(shares[id]) * 100.0)])
	return ", ".join(parts)


func timing_lines() -> Array[String]:
	var lines: Array[String] = []
	for stage: StringName in stage_times:
		lines.append("%-12s %5d ms" % [stage, int(stage_times[stage])])
	lines.append("%-12s %5d ms" % ["TOTAL", total_milliseconds])
	return lines


func to_dictionary() -> Dictionary:
	return {
		"recipe_id": recipe_id,
		"seed": seed,
		"attempt": attempt,
		"verdict": verdict(),
		"metrics": metrics.duplicate(),
		"failures": failures.duplicate(),
		"recipe_errors": recipe_errors.duplicate(),
		"notes": notes.duplicate(),
		"stage_times": stage_times.duplicate(),
		"total_milliseconds": total_milliseconds,
	}
