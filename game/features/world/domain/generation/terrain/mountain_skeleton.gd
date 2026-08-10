class_name MountainSkeleton
extends RefCounted

## Stage 3: mountains as a graph, not as a threshold on noise
## (procedural_map_generation.md §3.5, §5.1).
##
## This is the central bet of stage 1. `ridged_noise > 0.7` produces crumpled
## paper: you cannot ask it for two ranges, you cannot point them north-west, and
## you cannot put a pass through one. So a range is authored as a POLYLINE of
## peaks, and the height field is grown from it by distance. Then "two ranges from
## the north-west, four summits each, two passes" is a thing the generator can
## actually be held to — and the metrics stage can check.
##
## The graph pays for itself again in later layers: the rain shadow of layer 2 is
## computed from these same crest lines and orientations, which is impossible
## against noise (§11).

const STAGE := &"mountains"
## Half-width of a crest before the flanks start, in cells.
const CREST_CORE := 1.6
## How far a pass reaches along the ridge and how much of the crest it removes.
const PASS_RADIUS := 3.0
const PASS_DEPTH := 0.62
## Shape of a flank between the crest and the plain. Slightly above linear, so the
## mountain rounds off into its foothills instead of ending in a rim.
const FLANK_PROFILE := 1.35


static func build(context: GenerationContext) -> void:
	var recipe := context.recipe
	context.peaks.clear()
	context.ridges.clear()
	context.passes.clear()
	context.uplift.fill(0.0)
	if not recipe.has_mountains():
		return
	var rng := context.seeds.rng(STAGE)
	var span := float(context.board_cells)
	var diagonal := span * sqrt(2.0)

	var range_index := 0
	for spec: Dictionary in recipe.mountain_ranges:
		for _instance in int(spec["count"]):
			_build_range(context, rng, spec, diagonal, range_index)
			range_index += 1
	_build_solitary_peaks(context, rng, recipe.solitary_peaks)
	_apply_passes(context)


## One range: a crest polyline with `peaks_per_range` summits, laid along the
## requested orientation with the requested jitter, then the flanks grown from it.
static func _build_range(context: GenerationContext, rng: RandomNumberGenerator, spec: Dictionary, diagonal: float, range_index: int) -> void:
	var jitter := float(spec["orientation_jitter"])
	var orientation := float(spec["orientation"]) + rng.randf_range(-jitter, jitter)
	var angle := deg_to_rad(orientation)
	# Compass bearing: 0° points north, which is −Z on this board.
	var forward := Vector2(sin(angle), -cos(angle))
	var sideways := Vector2(forward.y, -forward.x)
	var length := float(spec["length"]) * diagonal
	var extent := float(context.board_cells) * 0.34
	var centre := Vector2(rng.randf_range(-extent, extent), rng.randf_range(-extent, extent))

	var summits := int(spec["peaks_per_range"])
	var heights: Array[int] = spec["peak_height"]
	var crest := PackedVector2Array()
	var crest_heights := PackedFloat32Array()
	for step in summits:
		var t := 0.0 if summits <= 1 else float(step) / float(summits - 1)
		var along := (t - 0.5) * length
		var wander := sideways * rng.randf_range(-1.0, 1.0) * length * 0.12
		crest.append(centre + forward * along + wander)
		var height := rng.randf_range(float(heights[0]), float(heights[1]))
		# The ends of a range taper: a crest that starts at full height reads as a
		# wall cut off by the board, not as a mountain range.
		var taper := 0.55 + 0.45 * sin(PI * clampf(t, 0.0, 1.0))
		crest_heights.append(height * taper)
		context.peaks.append({"position": crest[step], "height": crest_heights[step]})
	context.ridges.append(crest)

	_grow_flanks(context, crest, crest_heights, float(spec["flank_steepness"]), int(spec["foothills"]))
	_plan_passes(context, rng, crest, int(spec["passes"]), range_index)


static func _build_solitary_peaks(context: GenerationContext, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var count := int(spec.get("count", 0))
	if count <= 0:
		return
	var heights: Array[int] = spec["height"]
	var steepness := float(spec["flank_steepness"])
	var extent := float(context.board_cells) * 0.4
	for _peak in count:
		var position := Vector2(rng.randf_range(-extent, extent), rng.randf_range(-extent, extent))
		var height := rng.randf_range(float(heights[0]), float(heights[1]))
		context.peaks.append({"position": position, "height": height})
		var crest := PackedVector2Array([position])
		var crest_heights := PackedFloat32Array([height])
		context.ridges.append(crest)
		_grow_flanks(context, crest, crest_heights, steepness, 4)


## Height grown from the crest by distance.
##
## §5.2 is the whole of this function: **the generator has to plan the ground a
## slope needs.** A flank is not free to be as steep as a slider says — it has to
## land on a drop per cell that the catalog can actually express on this material,
## and the width follows from that rather than the other way round.
##
## On stone that set is {1, 2, 4} steps per cell (`steep`, `very_steep`,
## `pre_cliff` — the classes whose run is one cell, which is all the angle of
## repose leaves room for). `flank_steepness` chooses among them, so 0.7 gives a
## `very_steep` flank a walker can climb and 1.0 gives a `pre_cliff` wall that
## only a pass gets through. A drop of three is missing from that set on purpose:
## no class divides it, so it would come out a bare `cliff`.
##
## Getting this wrong is not a cosmetic error. A flank steeper than the set allows
## becomes a staircase of `pre_cliff` bands, those bands follow the contours, and
## contours close — so the board silently shatters into hundreds of terraces
## nobody can walk between while every other metric still looks healthy.
##
## Ranges combine with `max`, never with a sum: two crests crossing must make one
## massif of their own height, not a peak twice as tall as either.
static func _grow_flanks(context: GenerationContext, crest: PackedVector2Array, crest_heights: PackedFloat32Array, steepness: float, foothills: int) -> void:
	var tallest := 0.0
	for height: float in crest_heights:
		tallest = maxf(tallest, height)
	var gradient := flank_gradient(context.recipe.repose_override, steepness)
	# The profile is steepest at the crest, so the width comes from the steepest
	# point and not from the average — an average-fitted flank overshoots the
	# gradient over its whole upper half.
	var flank_width := maxf(
		CREST_CORE + float(foothills) * 0.5,
		tallest * FLANK_PROFILE / gradient,
	)
	var profile_exponent := FLANK_PROFILE
	var reach := flank_width + CREST_CORE
	for z in range(context.min_coordinate(), context.max_coordinate() + 1):
		for x in range(context.min_coordinate(), context.max_coordinate() + 1):
			var point := Vector2(float(x), float(z))
			var nearest := _nearest_crest(crest, crest_heights, point)
			var distance: float = nearest.x
			if distance > reach:
				continue
			var crest_height: float = nearest.y
			var falloff := clampf(1.0 - maxf(distance - CREST_CORE, 0.0) / flank_width, 0.0, 1.0)
			var value := crest_height * pow(falloff, profile_exponent)
			var index := context.index_of(x, z)
			if value > context.uplift[index]:
				context.uplift[index] = value


## Drops per cell this material can carry as a single-cell ramp, gentlest first.
## `run` has to be one: the angle of repose gives a boundary a budget of
## `ceil(drop / repose)` cells (`SlopeAssigner._budget_for`), which is one cell for
## everything up to the repose limit, and a class needing more ground than that is
## never chosen.
static func rampable_drops(material_id: StringName) -> Array[int]:
	var repose := TerrainMaterialCatalog.repose_steps_per_cell_of(material_id)
	var drops: Array[int] = []
	for slope_class: int in SlopeCatalog.RAMP_CLASSES:
		if SlopeCatalog.RUN_BY_CLASS[slope_class] != 1:
			continue
		var rise := SlopeCatalog.RISE_BY_CLASS[slope_class]
		if is_inf(repose) or float(rise) <= repose + 0.0001:
			drops.append(rise)
	drops.sort()
	# Soft ground holds nothing in one cell; a flank on it is a long gentle apron.
	return drops if not drops.is_empty() else ([1] as Array[int])


## Public because the border rim is grown by the same rule (§3.2): the edge of the
## board is a range like any other, and a range that picks its own gradient is a
## range the catalog cannot express.
static func flank_gradient(material_id: StringName, steepness: float) -> float:
	var drops := rampable_drops(material_id)
	var choice := clampi(roundi(steepness * float(drops.size() - 1)), 0, drops.size() - 1)
	return float(drops[choice])


## Distance to the crest polyline and the crest height interpolated at the
## closest point, as `Vector2(distance, height)`.
static func _nearest_crest(crest: PackedVector2Array, crest_heights: PackedFloat32Array, point: Vector2) -> Vector2:
	if crest.size() == 1:
		return Vector2(point.distance_to(crest[0]), crest_heights[0])
	var best_distance := INF
	var best_height := 0.0
	for segment in crest.size() - 1:
		var from := crest[segment]
		var to := crest[segment + 1]
		var span := to - from
		var length_squared := span.length_squared()
		var t := 0.0 if length_squared <= 0.0001 else clampf((point - from).dot(span) / length_squared, 0.0, 1.0)
		var projection := from + span * t
		var distance := point.distance_to(projection)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_height = lerpf(crest_heights[segment], crest_heights[segment + 1], t)
	return Vector2(best_distance, best_height)


## Saddles are chosen on the crest, between summits, where a range is naturally at
## its lowest. They are recorded now and pressed into the uplift once every range
## exists, so a pass cannot be filled in by the next range crossing it.
static func _plan_passes(context: GenerationContext, rng: RandomNumberGenerator, crest: PackedVector2Array, count: int, range_index: int) -> void:
	if count <= 0 or crest.size() < 2:
		return
	for pass_index in count:
		var t := (float(pass_index) + 0.5 + rng.randf_range(-0.2, 0.2)) / float(count)
		var position := clampf(t, 0.02, 0.98) * float(crest.size() - 1)
		var segment := clampi(int(position), 0, crest.size() - 2)
		var local := position - float(segment)
		context.passes.append(crest[segment].lerp(crest[segment + 1], local))
	context.note("range %d: %d passes planned" % [range_index, count])


static func _apply_passes(context: GenerationContext) -> void:
	if context.passes.is_empty():
		return
	for z in range(context.min_coordinate(), context.max_coordinate() + 1):
		for x in range(context.min_coordinate(), context.max_coordinate() + 1):
			var index := context.index_of(x, z)
			if context.uplift[index] <= 0.0:
				continue
			var point := Vector2(float(x), float(z))
			var deepest := 0.0
			for saddle: Vector2 in context.passes:
				var distance := point.distance_to(saddle)
				if distance > PASS_RADIUS:
					continue
				deepest = maxf(deepest, PASS_DEPTH * (1.0 - distance / PASS_RADIUS))
			if deepest > 0.0:
				context.uplift[index] *= 1.0 - deepest
