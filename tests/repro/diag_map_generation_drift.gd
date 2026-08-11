extends SceneTree

## Scratch: where does the mean land height drift away from the value the
## hypsometry solver hit? Replays the pipeline stage by stage and prints the mean
## the verdict would measure after each one.

const CASES: Array = [
	["archipelago", 1],
	["continent_east_ranges", 8],
	["continent_east_ranges", 10],
	["river_valley", 1],
	["arid_frontier", 4],
]


func _init() -> void:
	for case_entry: Array in CASES:
		var recipe := MapRecipe.from_json_path(
			"res://game/content/mapgen/presets/%s.gdmapgen.json" % case_entry[0])
		print("=== %s seed %d  target mean %d, max %d" % [
			case_entry[0], case_entry[1], recipe.land_mean_height, recipe.land_max_height])
		_replay(recipe, case_entry[1])
	quit(0)


func _replay(recipe: MapRecipe, seed_value: int) -> void:
	var context := GenerationContext.new()
	context.configure(recipe, GenerationSeed.new(seed_value))
	BorderShaper.classify(context)
	LandmassField.build(context)
	BaseReliefField.build(context)
	MountainSkeleton.build(context)
	BorderShaper.raise_rims(context)
	Hypsometry.apply(context)
	_report(context, "hypsometry (float)", true)
	for note: String in context.notes:
		print("      note: ", note)
	var uplift_mean := 0.0
	var uplift_count := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		uplift_count += 1
		uplift_mean += context.uplift[index]
	print("      mean uplift inside the frame after gain: %.2f (gain %.3f)" % [
		uplift_mean / float(maxi(uplift_count, 1)), context.mountain_gain])
	BorderShaper.apply(context)
	_report(context, "border (float)", true)
	HeightQuantizer.apply(context)
	_report(context, "quantize", false)
	BorderSeal.enforce(context)
	_report(context, "seal", false)
	ClimateField.build(context)
	PassCarver.carve(context)
	_report(context, "passes", false)
	FlowField.build(context)
	RiverCarver.carve(context)
	_report(context, "rivers", false)
	LandformField.build(context)
	GroundMask.build(context)
	ReposePass.apply(context)
	_report(context, "repose", false)
	FlowField.build(context)
	LakeFiller.fill(context)
	BorderSeal.enforce(context)
	_report(context, "reseal", false)


func _report(context: GenerationContext, label: String, use_float: bool) -> void:
	var total := 0.0
	var count := 0
	var highest := -1000.0
	var flat := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0:
			continue
		var height: float = context.height_field[index] if use_float else float(context.heights[index])
		if height < float(context.recipe.ocean_level):
			continue
		count += 1
		total += height
		highest = maxf(highest, height)
		if not use_float and _is_level(context, index):
			flat += 1
	print("   %-20s mean %6.2f  max %6.1f  land %d  level-4-neighbourhood %.3f" % [
		label, total / float(maxi(count, 1)), highest, count, float(flat) / float(maxi(count, 1)),
	])


static func _is_level(context: GenerationContext, index: int) -> bool:
	var cell := context.cell_of_index(index)
	var height := context.heights[index]
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var neighbour := cell + offset
		if not context.contains(neighbour.x, neighbour.y):
			continue
		if context.heights[context.cell_index(neighbour)] != height:
			return false
	return true
