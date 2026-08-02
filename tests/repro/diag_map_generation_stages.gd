extends SceneTree

## Prints the land share after each stage for one seed — the cheapest way to see
## which stage moves a target the solver already met.

func _init() -> void:
	var recipe := TestMapGeneration._recipe()
	var seeds := GenerationSeed.new(4242)
	var context := GenerationContext.new()
	context.configure(recipe, seeds)
	BorderShaper.classify(context)
	LandmassField.build(context)
	_report(context, "landmass")
	BaseReliefField.build(context)
	MountainSkeleton.build(context)
	Hypsometry.apply(context)
	_report(context, "hypsometry")
	BorderShaper.apply(context)
	_report(context, "border")
	HeightQuantizer.apply(context)
	_report(context, "quantize")
	PassCarver.carve(context)
	_report(context, "passes")
	FlowField.build(context)
	RiverCarver.carve(context)
	_report(context, "rivers")
	FlowField.build(context)
	LakeFiller.fill(context)
	_report(context, "lakes")
	ReposePass.apply(context)
	_report(context, "repose")
	for note: String in context.notes:
		print("  note: ", note)
	quit(0)


func _report(context: GenerationContext, stage: String) -> void:
	var land := 0
	var frame := 0
	var sum := 0
	var top := -9999
	for index in context.cell_count:
		if context.border_locked[index] != 0:
			frame += 1
			continue
		if context.is_land[index] == 0:
			continue
		land += 1
		sum += context.heights[index]
		top = maxi(top, context.heights[index])
	var inside := context.cell_count - frame
	print("%-10s land %.3f  mean %.2f  max %d" % [
		stage, float(land) / float(maxi(inside, 1)),
		float(sum) / float(maxi(land, 1)), top,
	])
