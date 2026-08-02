class_name MapEntityFunction
extends RefCounted

## Host-owned functions a placed entity can carry
## (design_docs/engine/map_start.md §6.5).
##
## Same split as zones: geometry and identity are the engine's, meaning is a
## pack's. An entity's `function` is the pack-facing label, and the engine
## interprets only the handful it owns itself. The list is open — a pack adds its
## own string and the format does not change.

## A container the starting party's supplies live in. What made
## `core:starter_backpack` a special archetype is a function now, which is why a
## chest, a cart or a barrel works with no new code: whatever carries this is
## read as party supplies, and a module sums **every** marked container rather
## than picking the first archetype it recognises.
const PARTY_STASH := &"core:party_stash"
