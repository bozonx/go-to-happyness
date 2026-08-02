class_name MapFormatMigration
extends RefCounted

## Raises a `map.json` written by an older build to the current format
## (design_docs/engine/map_start.md §16, map_editor.md §4.1).
##
## It runs on the parsed dictionary, before `MapDocument.from_json`, so every
## typed reader below only ever sees the current shape. That is the difference
## between a migration and a compatibility layer: the alias lives in one function
## for one release instead of in every consumer forever.
##
## v7 → v8 is one idea in four places: **the party's size stops being a property
## of the geometry.** The pair of hero/companion anchors becomes a spawn group
## that says "these places, and this clearing when there are more people than
## places"; the map gains one entrance that points at it; the starting backpack
## stops being an archetype and becomes a container carrying a function.

const FIRST_SUPPORTED := 7

## v7 anchor functions and what they are called now (§16, §4.1).
const FUNCTION_ALIASES: Dictionary = {
	"core:hero_start": "core:party_leader",
	"core:companion_start": "core:party_slot",
}

## The group and entrance a map without authored ones is read as.
const LEGACY_GROUP_ID := "legacy_party"

## v7's second backpack archetype, folded back into the ordinary one (§6.5).
const LEGACY_BACKPACK_ARCHETYPES: Array[String] = [
	"core:starter_backpack", "starter_backpack",
]
const BACKPACK_ARCHETYPE := "core:backpack"


## Returns the upgraded document, or an empty dictionary when the version is one
## this build cannot read at all. The caller reports that; silently returning the
## input would open a v9 map as if it were understood.
static func upgrade(source: Dictionary) -> Dictionary:
	var version := int(source.get("format_version", 0))
	if version == MapMeta.FORMAT_VERSION:
		return source
	if version < FIRST_SUPPORTED or version > MapMeta.FORMAT_VERSION:
		return {}
	var upgraded := source.duplicate(true)
	if version == 7:
		_upgrade_7_to_8(upgraded)
	upgraded["format_version"] = MapMeta.FORMAT_VERSION
	return upgraded


static func _upgrade_7_to_8(document: Dictionary) -> void:
	_rename_anchor_functions(document)
	_add_legacy_spawn_group(document)
	_add_legacy_start_option(document)
	_fold_starter_backpack(document)


static func _rename_anchor_functions(document: Dictionary) -> void:
	for raw_anchor: Variant in document.get("anchors", []):
		if not (raw_anchor is Dictionary):
			continue
		var anchor := raw_anchor as Dictionary
		var function := String(anchor.get("function", ""))
		if FUNCTION_ALIASES.has(function):
			anchor["function"] = FUNCTION_ALIASES[function]


## The party anchors become one group: the leader's place, the companion places,
## and the clearing is left unset because a v7 map never drew one. A group with
## slots and no area still places exactly as many members as it has slots, which
## is what the map meant — the difference is that asking for more now produces a
## readable refusal instead of a missing-anchor error.
static func _add_legacy_spawn_group(document: Dictionary) -> void:
	if document.has("spawn_groups"):
		return
	var slots: Array = []
	var order := 0
	for raw_anchor: Variant in document.get("anchors", []):
		if not (raw_anchor is Dictionary):
			continue
		var anchor := raw_anchor as Dictionary
		var function := String(anchor.get("function", ""))
		if function == String(MapSpawnService.PARTY_LEADER):
			slots.append({
				"id": "leader", "anchor": String(anchor.get("id", "")),
				"tags": [String(MapSpawnGroup.TAG_LEADER)], "order": 0,
			})
		elif function == String(MapSpawnService.PARTY_SLOT):
			order += 1
			slots.append({"id": "slot_%d" % order, "anchor": String(anchor.get("id", "")), "order": order})
	if slots.is_empty():
		document["spawn_groups"] = []
		return
	document["spawn_groups"] = [{
		"id": LEGACY_GROUP_ID,
		"name": {"ru": "Старт отряда"},
		"slots": slots,
		"capacity": maxi(slots.size(), MapSpawnGroup.DEFAULT_CAPACITY),
		"fallback": String(MapSpawnGroup.FALLBACK_NEAREST),
	}]


static func _add_legacy_start_option(document: Dictionary) -> void:
	var start: Variant = document.get("start", {})
	if not (start is Dictionary):
		start = {}
		document["start"] = start
	var settings := start as Dictionary
	if settings.get("starts") is Array and not (settings["starts"] as Array).is_empty():
		return
	var groups: Variant = document.get("spawn_groups", [])
	var group_id := ""
	if groups is Array and not (groups as Array).is_empty():
		group_id = String(((groups as Array)[0] as Dictionary).get("id", ""))
	settings["starts"] = [{
		"id": String(MapStart.LEGACY_START_ID),
		"name": {"ru": "Начало"},
		"selectable": true,
		"spawn_group": group_id,
	}]
	settings["default_start"] = String(MapStart.LEGACY_START_ID)


## The duplicate archetype disappears and the surviving one is marked with the
## function that made it special (§6.5). Nothing about the entity's contents
## changes: the authored props were always the starting supplies, and now any
## container carrying the function is read the same way.
static func _fold_starter_backpack(document: Dictionary) -> void:
	for raw_entity: Variant in document.get("entities", []):
		if not (raw_entity is Dictionary):
			continue
		var entity := raw_entity as Dictionary
		if String(entity.get("archetype", "")) in LEGACY_BACKPACK_ARCHETYPES:
			entity["archetype"] = BACKPACK_ARCHETYPE
			entity["function"] = String(MapEntityFunction.PARTY_STASH)
