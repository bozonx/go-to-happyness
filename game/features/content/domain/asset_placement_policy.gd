class_name AssetPlacementPolicy
extends Resource

## Where an asset may stand and how it sits on the ground
## (design_docs/engine/map_fill_mode.md §3.3).
##
## These are not settings the author tweaks for taste: they are the invariants the
## editor checks *instead of* the author. Reeds belong in shallow water, a spruce
## on ground no steeper than the second slope class, a boat on water. Breaking one
## is a **warning** — a yellow ghost — never a refusal. Refusal is reserved for
## the physically meaningless: off the board, inside an `is_hole` cut.
##
## Navigation blocking deliberately does **not** live here. `WorldAssetDef`
## already owns `blocking_navigation` and the whole engine reads it from there;
## a second copy in this section would be a second write-owner for one mechanic.

## Surface kinds an asset can be asked to stand on. They are the four the terrain
## and water layers can actually report for a cell, not a taxonomy of biomes.
const SURFACE_GROUND := &"ground"
const SURFACE_SHALLOW := &"shallow"
const SURFACE_WATER := &"water"
const SURFACE_ICE := &"ice"
const SURFACE_LAVA := &"lava"

const SURFACES: Array[StringName] = [
	SURFACE_GROUND, SURFACE_SHALLOW, SURFACE_WATER, SURFACE_ICE, SURFACE_LAVA,
]

## How much of the ground normal the object takes on. `partial` is the useful
## default: a tree leans with the hillside a little and still grows up.
const ALIGN_NONE := &"none"
const ALIGN_PARTIAL := &"partial"
const ALIGN_FULL := &"full"

const ALIGN_MODES: Array[StringName] = [ALIGN_NONE, ALIGN_PARTIAL, ALIGN_FULL]

## What standing below the water surface means for this asset: forbidden (a
## campfire), tolerated (a rock), or the whole point (a sunken wreck).
const SUBMERGED_FORBID := &"forbid"
const SUBMERGED_ALLOW := &"allow"
const SUBMERGED_REQUIRE := &"require"

const SUBMERGED_MODES: Array[StringName] = [
	SUBMERGED_FORBID, SUBMERGED_ALLOW, SUBMERGED_REQUIRE,
]

@export var surfaces: Array[StringName] = [SURFACE_GROUND]
## Steepest slope class the asset tolerates under its footprint, as a
## `SlopeCatalog` class index. `CLASS_CLIFF` means "anything".
@export var max_slope_class: int = SlopeCatalog.CLASS_CLIFF
@export var align_to_normal: StringName = ALIGN_PARTIAL
@export var submerged: StringName = SUBMERGED_FORBID
## Authored lift off the surface, in metres. The surface height itself is never
## authored — it comes from `TerrainGrid` (§9.3).
@export var vertical_offset: float = 0.0
@export var footprint_cells: Vector2i = Vector2i.ONE
@export var scatter_allowed: bool = false
@export var scatter_default_density: float = 0.35
@export var scatter_min_spacing_m: float = 1.0


static func of_surfaces(
	p_surfaces: Array[StringName],
	p_max_slope_class: int = SlopeCatalog.CLASS_CLIFF,
	p_submerged: StringName = SUBMERGED_FORBID
) -> AssetPlacementPolicy:
	var policy := AssetPlacementPolicy.new()
	policy.surfaces = p_surfaces
	policy.max_slope_class = p_max_slope_class
	policy.submerged = p_submerged
	return policy


func allows_surface(surface: StringName) -> bool:
	return surfaces.is_empty() or surface in surfaces


func allows_slope_class(slope_class: int) -> bool:
	return slope_class <= max_slope_class


## Warnings for one candidate spot, described by what the layers report there:
##   {"surface": StringName, "slope_class": int, "submerged": bool}
##
## The editor paints the ghost yellow and lists these; it never blocks the click.
## Returning strings rather than codes keeps the policy self-explaining: the
## author is told which invariant they are breaking, in the panel, at the moment
## they break it.
func warnings_for(facts: Dictionary) -> Array[String]:
	var messages: Array[String] = []
	var surface := StringName(facts.get("surface", SURFACE_GROUND))
	if not allows_surface(surface):
		messages.append("поверхность «%s» не в списке разрешённых" % surface)
	var slope_class := int(facts.get("slope_class", SlopeCatalog.CLASS_FLAT))
	if not allows_slope_class(slope_class):
		messages.append("уклон «%s» круче допустимого «%s»" % [
			SlopeCatalog.id_of_class(slope_class),
			SlopeCatalog.id_of_class(max_slope_class),
		])
	var is_submerged := bool(facts.get("submerged", false))
	if is_submerged and submerged == SUBMERGED_FORBID:
		messages.append("объект под водой, а его политика это запрещает")
	if not is_submerged and submerged == SUBMERGED_REQUIRE:
		messages.append("объект вне воды, а его политика требует погружения")
	return messages


func to_dict() -> Dictionary:
	var surface_ids: Array = []
	for surface: StringName in surfaces:
		surface_ids.append(String(surface))
	return {
		"surface": surface_ids,
		"max_slope_class": max_slope_class,
		"align_to_normal": String(align_to_normal),
		"submerged": String(submerged),
		"vertical_offset": vertical_offset,
		"footprint_cells": [footprint_cells.x, footprint_cells.y],
		"scatter": {
			"allowed": scatter_allowed,
			"default_density": scatter_default_density,
			"min_spacing_m": scatter_min_spacing_m,
		},
	}


## Unknown enum values fall back to the default rather than failing: a pack
## authored by a later build must still open here (§11, "не является ошибкой").
static func from_dict(source: Dictionary) -> AssetPlacementPolicy:
	var policy := AssetPlacementPolicy.new()
	var raw_surfaces: Variant = source.get("surface", null)
	if raw_surfaces is Array:
		var parsed: Array[StringName] = []
		for entry: Variant in raw_surfaces as Array:
			var surface := StringName(entry)
			if surface in SURFACES:
				parsed.append(surface)
		if not parsed.is_empty():
			policy.surfaces = parsed
	policy.max_slope_class = clampi(
		int(source.get("max_slope_class", policy.max_slope_class)),
		SlopeCatalog.CLASS_FLAT,
		SlopeCatalog.CLASS_CLIFF
	)
	var align := StringName(source.get("align_to_normal", policy.align_to_normal))
	if align in ALIGN_MODES:
		policy.align_to_normal = align
	var submerged_mode := StringName(source.get("submerged", policy.submerged))
	if submerged_mode in SUBMERGED_MODES:
		policy.submerged = submerged_mode
	policy.vertical_offset = float(source.get("vertical_offset", policy.vertical_offset))
	var raw_footprint: Variant = source.get("footprint_cells", null)
	if raw_footprint is Array and (raw_footprint as Array).size() >= 2:
		policy.footprint_cells = Vector2i(
			maxi(1, int((raw_footprint as Array)[0])),
			maxi(1, int((raw_footprint as Array)[1]))
		)
	var raw_scatter: Variant = source.get("scatter", null)
	if raw_scatter is Dictionary:
		var scatter := raw_scatter as Dictionary
		policy.scatter_allowed = bool(scatter.get("allowed", policy.scatter_allowed))
		policy.scatter_default_density = float(
			scatter.get("default_density", policy.scatter_default_density)
		)
		policy.scatter_min_spacing_m = float(
			scatter.get("min_spacing_m", policy.scatter_min_spacing_m)
		)
	return policy
