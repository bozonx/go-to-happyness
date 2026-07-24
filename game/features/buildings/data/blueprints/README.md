# Building blueprints (.gdbuilding.json)

Canonical block-based building definitions authored in the modular building
editor (dev mode). At runtime the presentation-side `BuildingBlueprintLibrary` resolves an in-game
`building_type` to the file here whose `id` matches, and the game renders the
building from its blocks instead of the legacy procedural generator.

Empty for now: buildings are converted to this format in a later stage. Until a
type has a file here, the game falls back to `building_blueprints.gd`.
