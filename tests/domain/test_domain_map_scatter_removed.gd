class_name TestDomainMapScatterRemoved
extends RefCounted

## Guards the "startup reads only map data" contract for natural fill.
##
## The old `natural_scatter` compact-grove key was the one piece of startup
## fabrication left: the loader expanded `tree_cells` into grass/forage records
## at fixed offsets. That expansion is gone, so this suite asserts:
##   1. A map that still carries `natural_scatter` no longer grows extra entities
##      from it — the key is inert, grass/forage come only from explicit records.
##   2. The shipped green_valley map authors every natural kind (grass, forage,
##      fireflies) explicitly, with no `natural_scatter` field at all.

static func run_all() -> void:
	_test_natural_scatter_key_is_inert()
	_test_green_valley_authors_natural_explicitly()
	print("    [PASS] Map Scatter Removed Tests")


## A document built from JSON with `natural_scatter` but no grass/forage records
## must load exactly the entities the JSON declared — nothing expanded.
static func _test_natural_scatter_key_is_inert() -> void:
	var source := {
		"format_version": MapMeta.FORMAT_VERSION,
		"id": "scatter_probe",
		"name": "Scatter probe",
		"board": {"cell_size": 1.0, "cells": 32},
		"entities": [
			{"id": "tree_01", "archetype": "core:tree", "transform": {"position": [4.5, 0.0, 4.5]}},
		],
		# Legacy compact grove data: the old loader turned each tree cell into
		# 3 grass + 2 forage records. This build must ignore it entirely.
		"natural_scatter": {"tree_cells": [[4, 4]]},
	}
	var document := MapDocument.from_json(source)
	var kinds := _kind_counts(document)
	assert(kinds.get("tree", 0) == 1, "authored tree record must load")
	assert(not kinds.has("grass_source"), "natural_scatter must not expand into grass")
	assert(not kinds.has("forage_source"), "natural_scatter must not expand into forage")


## The shipped map is the reference: it must not rely on any expansion, and it
## must author every natural kind the runtime consumes, including fireflies.
static func _test_green_valley_authors_natural_explicitly() -> void:
	var service := MapDocumentService.new()
	var document := service.load_map(&"core:green_valley")
	assert(document != null, "green_valley must load")
	var kinds := _kind_counts(document)
	# No compact grove data survives — every natural object is an explicit record.
	assert(kinds.get("tree", 0) > 0)
	assert(kinds.get("grass_source", 0) > 0, "grass is authored, not scattered")
	assert(kinds.get("forage_source", 0) > 0, "forage is authored, not scattered")
	assert(kinds.get("rabbit", 0) > 0)
	assert(kinds.get("fireflies", 0) > 0, "fireflies are authored map entities")
	# A resave must not reintroduce the obsolete key.
	var json := document.to_json()
	assert(not json.has("natural_scatter"), "resave must drop natural_scatter")


static func _kind_counts(document: MapDocument) -> Dictionary:
	EntityArchetypeCatalog.reload()
	var counts: Dictionary = {}
	for placed: MapEntityRecord in document.entities.entities:
		# Fireflies carry no settlement_natural component (the presenter owns
		# them), so classify by archetype id first and fall back to the kind.
		if String(placed.archetype_id) == "core:fireflies":
			counts["fireflies"] = counts.get("fireflies", 0) + 1
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype == null or not archetype.has_component(&"settlement_natural"):
			continue
		var kind := String(archetype.component_data(&"settlement_natural").get("kind", ""))
		counts[kind] = counts.get(kind, 0) + 1
	return counts
