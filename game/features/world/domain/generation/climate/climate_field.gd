class_name ClimateField
extends RefCounted

## Layer 2: temperature and moisture over the finished relief
## (procedural_map_generation.md §11.1).
##
## Climate is not a decoration on top of the map — it is what decides where water
## can stand (§11.1.3), what the ground is made of (`SurfacePainter`) and which
## biome a column belongs to (`BiomeField`). It is therefore a stage of the
## pipeline with its own buffers, not a lookup someone calls twice with different
## answers.
##
## ## Two fields, both derived, neither noise on its own
##
## * **Temperature** = latitude + altitude + a little noise. The latitude term is
##   a gradient across the board (north is colder, the northern hemisphere being
##   the only one this generator models); the altitude term is the lapse rate
##   against the column's own height. That second term is the load-bearing one:
##   the bare rock on a peak and the snow on it are consequences of the lapse
##   rate, not of a "rock line" constant, which is why a gentle-plains recipe and
##   an alpine one both put their treeline in the right place without a second
##   knob (§11.1.1).
## * **Moisture** = what the sea gives the coast, plus what a windward slope wrings
##   out of the air, minus the rain shadow behind a range. The shadow is computed
##   from the RELIEF the mountain stage produced (§11.1.2) rather than from a
##   second noise field — this is the payoff the design document promised for
##   building mountains as structures: the crest already knows where it is and how
##   high it stands, so its lee side comes for free.
##
## ## The prevailing wind is one vector, and the shadow is one sweep
##
## The naive rain shadow marches upwind from every cell until it finds a barrier:
## on a 128² board with a 40-cell reach that is 650 000 samples and the laboratory
## stops being interactive. Instead the board is swept ONCE in the direction the
## wind blows, carrying the highest ground the air has crossed so far and letting
## it decay downwind (`SHADOW_DECAY`). A cell whose carried barrier stands above
## it is in a shadow proportional to the difference. Same answer, O(cells).
##
## ## Both means are targets, not outcomes (§5.3)
##
## `land_mean_temperature` and `land_mean_moisture` are properties of the finished
## map the same way `land_fraction` is: the raw fields are shifted until the mean
## measured over the land inside the frame equals what the recipe asked for. A
## recipe that says "12 °C" gets 12 °C on every seed, and the metric that checks it
## is measuring the same number the author typed.
##
## ## It runs twice, for the same reason `flow` does
##
## Rivers need moisture before they are traced (a spring needs rain), and the
## biome of a column needs the temperature of the ground that will actually ship —
## and river incision and the repose pass both move columns in between. So the
## stage is re-run after them (`reclimate`), exactly as the drainage tree is
## (`reflow`). It is a pure function of the buffers and its own seed stream, so
## running it twice cannot introduce drift.

const STAGE := &"climate"

## Metres of world per repetition of the two perturbation fields. Climate varies
## over regions, not over cells: a per-cell wobble would dice every biome into
## confetti and no amount of smoothing downstream would put it back together.
const NOISE_PERIOD_CELLS := 26.0
## How much the perturbation may move each field, in its own units.
const TEMPERATURE_NOISE := 1.2
const MOISTURE_NOISE := 0.08

## Height steps of barrier the carried air loses per cell it travels. A range 12
## steps above the plain behind it therefore shadows roughly 50 cells downwind,
## which is most of a small board and a region of a large one.
const SHADOW_DECAY := 0.22
## Height steps of barrier that make a complete rain shadow.
const SHADOW_SCALE := 10.0
## How much moisture a full shadow removes, before `climate.rain_shadow` scales it.
const SHADOW_STRENGTH := 0.45
## Height steps of windward climb that make a full orographic bonus, how far
## upwind the climb is measured, and how much moisture that bonus is worth.
const OROGRAPHIC_SCALE := 5.0
const CLIMB_REACH := 3
const OROGRAPHIC_STRENGTH := 0.15
## Moisture the open sea puts into the air directly over the shore.
const COASTAL_STRENGTH := 0.30
## Moisture ground has before anything is added to it. The solver moves this to
## hit the recipe's mean; it only has to be a sane starting point.
const BASE_MOISTURE := 0.35

## Passes of the mean solver. Clamping to 0…1 makes a single offset inexact, so
## the correction is applied, re-measured and applied again — three passes put
## every preset inside a hundredth.
const SOLVER_PASSES := 4

## Below this a column is cold enough for snow to lie all year, and how much
## colder each further level of it needs. Snow is a STATE in the detail byte, not
## a material (`terrain_materials.md` §2.5), which is exactly why the painter can
## put it on top of whatever the biome chose.


static func build(context: GenerationContext) -> void:
	context.temperature.resize(context.cell_count)
	context.moisture.resize(context.cell_count)
	var recipe := context.recipe
	var blow := wind_vector(recipe.wind_direction)
	var barrier := _upwind_barrier(context, blow)
	var climb := _windward_climb(context, blow)

	var temperature_noise := context.seeds.noise(
		&"climate_temperature", 1.0 / NOISE_PERIOD_CELLS, 2,
	)
	var moisture_noise := context.seeds.noise(&"climate_moisture", 1.0 / NOISE_PERIOD_CELLS, 3)

	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		var height := float(context.heights[index])
		var above_sea := maxf(height - float(recipe.ocean_level), 0.0)
		# Latitude: −1 at the northern edge of the board, +1 at the southern one.
		# North is −Z everywhere in this codebase (`SlopeCatalog.DIR_N`), so the
		# gradient is simply the normalised Z coordinate.
		var latitude := context.normalised(cell.x, cell.y).y
		var temperature := recipe.land_mean_temperature
		temperature += latitude * recipe.temperature_span * 0.5
		temperature -= above_sea * recipe.lapse_rate
		temperature += temperature_noise.get_noise_2d(float(cell.x), float(cell.y)) * TEMPERATURE_NOISE
		context.temperature[index] = temperature

		var shore := context.shore_distance[index]
		# Negative shore distance is sea: over the water itself the air is as wet as
		# it gets, and the shelf is what the coast then breathes in.
		var coastal := 1.0 if shore <= 0.0 else exp(-shore / maxf(recipe.coastal_reach, 1.0))
		var moisture := BASE_MOISTURE + coastal * COASTAL_STRENGTH
		moisture += clampf(climb[index] / OROGRAPHIC_SCALE, 0.0, 1.0) * OROGRAPHIC_STRENGTH
		moisture -= clampf(barrier[index] / SHADOW_SCALE, 0.0, 1.0) * SHADOW_STRENGTH * recipe.rain_shadow
		moisture += moisture_noise.get_noise_2d(float(cell.x), float(cell.y)) * MOISTURE_NOISE
		context.moisture[index] = clampf(moisture, 0.0, 1.0)

	_solve_mean(context, context.temperature, recipe.land_mean_temperature, -1000.0, 1000.0)
	_solve_mean(context, context.moisture, recipe.land_mean_moisture, 0.0, 1.0)
	context.note("climate: %.1f °C mean, %.2f moisture, wind from %d°" % [
		mean_over_land(context, context.temperature),
		mean_over_land(context, context.moisture),
		roundi(recipe.wind_direction),
	])


## Unit vector the wind BLOWS ALONG, from a bearing it blows FROM. Bearing 0 is a
## northerly — air arriving from the north and travelling south, which is +Z.
static func wind_vector(bearing_degrees: float) -> Vector2:
	var bearing := deg_to_rad(bearing_degrees)
	return Vector2(-sin(bearing), cos(bearing))


## Mean of a field over the land inside the frame — the same population every
## other land metric uses (§10.1.5), so the solver and the verdict cannot end up
## measuring two different maps.
static func mean_over_land(context: GenerationContext, field: PackedFloat32Array) -> float:
	var total := 0.0
	var count := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		total += field[index]
		count += 1
	if count == 0:
		return 0.0
	return total / float(count)


# --- Internals ----------------------------------------------------------------

## Shifts the whole field until its mean over the land is the target. Clamping is
## what makes this iterative rather than a single subtraction: moisture pushed
## past 0 or 1 stops responding, so the remaining error is re-measured and pushed
## into the cells that can still move.
static func _solve_mean(
	context: GenerationContext, field: PackedFloat32Array,
	target: float, low: float, high: float,
) -> void:
	for _pass in SOLVER_PASSES:
		var error := target - mean_over_land(context, field)
		if absf(error) < 0.005:
			return
		for index in context.cell_count:
			field[index] = clampf(field[index] + error, low, high)


## The highest ground the air has crossed on its way to each cell, decaying
## downwind. One sweep in the direction the wind blows: the cells upwind of any
## cell are always visited before it, which is what makes a single pass enough.
static func _upwind_barrier(context: GenerationContext, blow: Vector2) -> PackedFloat32Array:
	var carried := PackedFloat32Array()
	var barrier := PackedFloat32Array()
	carried.resize(context.cell_count)
	barrier.resize(context.cell_count)
	var step_x := signi(roundi(blow.x * 1000.0))
	var step_z := signi(roundi(blow.y * 1000.0))
	var weight_x := absf(blow.x)
	var weight_z := absf(blow.y)
	var weight_total := maxf(weight_x + weight_z, 0.0001)
	weight_x /= weight_total
	weight_z /= weight_total

	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var span := high - low + 1
	for offset_z in span:
		var z := (low + offset_z) if step_z >= 0 else (high - offset_z)
		for offset_x in span:
			var x := (low + offset_x) if step_x >= 0 else (high - offset_x)
			var index := context.index_of(x, z)
			var height := float(context.heights[index])
			# Air arriving from upwind carries the barrier it has already crossed.
			# Off the board it carries nothing but the local ground, so the windward
			# edge starts in the open rather than in a shadow of its own making.
			var incoming := 0.0
			incoming += weight_x * _carried_at(context, carried, x - step_x, z, height)
			incoming += weight_z * _carried_at(context, carried, x, z - step_z, height)
			incoming = maxf(incoming - SHADOW_DECAY, height)
			barrier[index] = maxf(incoming - height, 0.0)
			carried[index] = incoming
	return barrier


static func _carried_at(
	context: GenerationContext, carried: PackedFloat32Array,
	x: int, z: int, fallback: float,
) -> float:
	if not context.contains(x, z):
		return fallback
	return carried[context.index_of(x, z)]


## How steeply the ground climbs into the wind at each cell. A windward slope
## lifts the air and wrings it out, which is the other half of the same
## mechanism the shadow is: the moisture the lee side does not get was left here.
##
## The comparison reaches `CLIMB_REACH` cells upwind rather than one. Heights are
## integers and terraced, so a single-cell difference is 0 on most of a hillside
## and 2 on the step — a slope measured that way is a row of dots, not a flank.
static func _windward_climb(context: GenerationContext, blow: Vector2) -> PackedFloat32Array:
	var climb := PackedFloat32Array()
	climb.resize(context.cell_count)
	var step := Vector2i(signi(roundi(blow.x * 1000.0)), signi(roundi(blow.y * 1000.0))) * CLIMB_REACH
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		var upwind := cell - step
		if not context.contains(upwind.x, upwind.y):
			continue
		climb[index] = maxf(
			float(context.heights[index]) - float(context.heights[context.cell_index(upwind)]), 0.0,
		)
	return climb
