class_name MapGenerationService
extends RefCounted

## Generation as an operation on a MAP DOCUMENT, not on a pair of bare grids
## (procedural_map_generation.md §11.4, layer 6).
##
## `TerrainGenerationService` fills a `TerrainGrid` and a `WaterGrid`. That is all
## the laboratory needs and it is deliberately all that service knows. A map is
## more than its ground: it has a header that says how big the board is and what
## lies past its rim, it has an author's undo stack, and it has layers — zones,
## entities, placements — that describe the ground the generator is about to
## replace. Teaching those to the terrain service would put the map format inside
## the generator; putting them here keeps one entry point for the editor and one
## for the lab, over the same pipeline.
##
## Three things this service exists to get right, none of which the pipeline can:
##
## 1. **The rim of the map is one field, the recipe has four sides.** A recipe can
##    ask for ocean west and a wall east; `MapMeta` has a single `border_kind` and
##    a single `border_level`, because that header answers one question — what does
##    the world do past the last column. If the two disagree, `BorderOceanService`
##    re-floods the rim at a different level after the author's very first stroke
##    and quietly undoes the coastline the generator drew.
## 2. **Generation replaces the ground, so it replaces the document.** It is not an
##    edit: the terrain and water histories are cleared by the terrain service, and
##    the editor's own stack has to go with them, or Ctrl+Z replays a stroke onto
##    a board that no longer means the same thing.
## 3. **A generated map is not a finished map.** It has no start option and no
##    entities, so the validator will refuse to launch it — correctly. Saying so in
##    the result beats the author discovering it from a red ✔.

## What a generated document still needs from its author before it can be
## launched. Reported, never fixed silently: choosing where a session starts is
## authoring, and a generator that guesses would be guessing at the game.
const MISSING_START_NOTE := "карта сгенерирована: расставьте точки старта — без них запуск невозможен"

var _terrain_generation: TerrainGenerationService = null


func configure(terrain_generation: TerrainGenerationService) -> void:
	_terrain_generation = terrain_generation


## Generates into `document` and returns the result of the run.
##
## The document's own grids are the ones the terrain service was configured with,
## so nothing is copied: the generator writes the map. Everything around the
## ground — the header, the dirty flag, the note about what is still missing — is
## this service's half of the job.
func generate_into(document: MapDocument, recipe: MapRecipe, seed_value: int) -> GenerationResult:
	var result := GenerationResult.new()
	if document == null or _terrain_generation == null:
		result.report = GenerationReport.new()
		result.report.recipe_errors.append("no document to generate into")
		return result
	if document.meta.board_cells != recipe.board_size:
		result.report = GenerationReport.new()
		result.report.recipe_id = recipe.id
		result.report.recipe_errors.append(
			"recipe board %d does not match the map's %d — the size of a map is chosen once, at creation (map_editor.md §6.2)" % [
				recipe.board_size, document.meta.board_cells,
			])
		result.attempts.append(result.report)
		return result

	result = _terrain_generation.generate(recipe, seed_value)
	if result.report != null and result.report.is_rejected_recipe():
		return result

	apply_border(document.meta, recipe)
	document.meta.biomes = biome_ids_of(result)
	document.mark_dirty()
	if result.report != null and document.meta.start.starts.is_empty():
		result.report.notes.append(MISSING_START_NOTE)
	return result


## Writes the recipe's four independent sides into the one question the map header
## asks (`map_editor.md` §6.1): what does the world do past the board.
##
## Any ocean side makes the map an ocean map — a coastline that stops being sea at
## the rim is not a coastline — and the level is the recipe's own, so the sea the
## generator poured and the sea `BorderOceanService` maintains are the same sea.
## A board walled or open on every side ends at its edge.
static func apply_border(meta: MapMeta, recipe: MapRecipe) -> void:
	if recipe.has_ocean_border():
		meta.border_kind = MapMeta.BORDER_OCEAN
		meta.border_level = recipe.ocean_level
	else:
		meta.border_kind = MapMeta.BORDER_NOTHING
		meta.border_level = recipe.ocean_level


## The biomes the run actually produced, biggest share first, for the header's
## `biomes[]` filter. Anything under a twentieth of the land is local colour — a
## marsh in one bend of a river — and naming it in the header would make every map
## claim every biome.
static func biome_ids_of(result: GenerationResult, minimum_share := 0.05) -> Array[StringName]:
	var ids: Array[StringName] = []
	if result == null or result.report == null:
		return ids
	var shares: Dictionary = result.report.metrics.get("biome_shares", {})
	var names: Array = shares.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return float(shares[a]) > float(shares[b]))
	for name: String in names:
		if float(shares[name]) >= minimum_share:
			ids.append(StringName(name))
	return ids
