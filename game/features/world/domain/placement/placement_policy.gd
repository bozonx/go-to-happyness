class_name PlacementPolicy
extends RefCounted

## The part of placement that is a *rule of the game* rather than a rule of the
## world (design_docs/engine/building_placement.md §2).
##
## `BuildingPlacementService` is the single owner of "put a blueprint on the
## ground", used by the map editor and by player construction alike. What differs
## between the two is never the algorithm — it is this object. Two placement
## algorithms would mean the same spot answering differently to the author and to
## the player, and the map would turn out impassable in exactly the scenario it
## was made for.
##
## The engine invariants are NOT here, because they are not negotiable anywhere:
## footprints do not overlap and entrances are not walled in.

## Cells the author is warned about between two footprints. The gap itself is a
## setting of a game module, not a property of a blueprint and not an engine
## constant — an author designing a town is not building it under the rules of an
## era.
var min_building_gap := 1

## The largest drop the merge is willing to bridge at the edge of a pad
## (`grid_terrain_system.md` §5.3). Beyond it the placement is refused: what would
## be left is not a building on a slope but a tower on a plinth nobody authored.
var max_border_drop := 4


## The policy the map editor places with: warnings where the game refuses, and no
## economy of soil, fog or overlay audiences (§13).
static func editor() -> PlacementPolicy:
	return PlacementPolicy.new()
