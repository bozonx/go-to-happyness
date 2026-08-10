extends SceneTree

## Scratch: who owns the height budget — the ranges the recipe asked for, or the
## border rim? Prints the uplift footprint inside the frame, split by source.

const CASES: Array = [
	["continent_east_ranges", 8],
	["continent_east_ranges", 10],
	["river_valley", 1],
	["arid_frontier", 4],
	["mountain_basin", 1],
]


func _init() -> void:
	for case_entry: Array in CASES:
		var recipe := MapRecipe.from_json_path(
			"res://tools/map_gen_lab/presets/%s.gdmapgen.json" % case_entry[0])
		var context := GenerationContext.new()
		context.configure(recipe, GenerationSeed.new(case_entry[1]))
		BorderShaper.classify(context)
		LandmassField.build(context)
		BaseReliefField.build(context)
		MountainSkeleton.build(context)
		var ranges_only := context.uplift.duplicate()
		BorderShaper.raise_rims(context)
		print("=== %s seed %d  (mean %d, max %d)" % [
			case_entry[0], case_entry[1], recipe.land_mean_height, recipe.land_max_height])
		_report(context, ranges_only)
	quit(0)


func _report(context: GenerationContext, ranges_only: PackedFloat32Array) -> void:
	var interior := 0
	var range_sum := 0.0
	var total_sum := 0.0
	var range_cells := 0
	var rim_cells := 0
	var rim_only_sum := 0.0
	var buckets := PackedInt32Array()
	buckets.resize(6)
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		interior += 1
		var total := context.uplift[index]
		var ranges := ranges_only[index]
		range_sum += ranges
		total_sum += total
		if ranges > 0.5:
			range_cells += 1
		if total - ranges > 0.5:
			rim_cells += 1
			rim_only_sum += total - ranges
		var bucket := clampi(int(total / 2.0), 0, buckets.size() - 1)
		buckets[bucket] += 1
	var n := float(maxi(interior, 1))
	print("   interior land %d" % interior)
	print("   mean uplift  total %.2f = ranges %.2f + rim %.2f   (pre-gain)" % [
		total_sum / n, range_sum / n, rim_only_sum / n])
	print("   footprint    ranges %.1f%%  rim %.1f%% of interior land" % [
		float(range_cells) * 100.0 / n, float(rim_cells) * 100.0 / n])
	var labels: Array[String] = ["0-2", "2-4", "4-6", "6-8", "8-10", "10+"]
	var line: PackedStringArray = []
	for i in buckets.size():
		line.append("%s:%.0f%%" % [labels[i], float(buckets[i]) * 100.0 / n])
	print("   uplift bands ", "  ".join(line))
