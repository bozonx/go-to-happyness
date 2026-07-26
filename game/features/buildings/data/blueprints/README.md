# Building blueprints (.gdbuilding.json)

Canonical block-based building definitions authored in the modular building
editor (dev mode). At runtime the presentation-side `BuildingBlueprintLibrary` resolves an in-game
`building_type` to the file here whose `id` matches, and the game renders the
building from its blocks instead of the legacy procedural generator.

Until a type has a file here, the game falls back to `building_blueprints.gd`.

## Layout

Subfolders are free-form: the loader is meant to walk this tree recursively and
classify each file by its own fields, never by its path. Do not encode era,
style or category in folder names — see
`design_docs/core/content_packaging.md` §1.

This folder becomes `res://game/content/core/buildings/` once packs land
(content_packaging.md §5.1); nothing about the file format changes with it.

## Files

Every file carries a `revision` — a stamp rewritten on each save, shared with
map packages (`ContentRevision.new_stamp()`). A game save keeps it next to
`blueprint_ref` so a session can tell the player the file changed since.
Files written before the field existed fall back to a content hash.
