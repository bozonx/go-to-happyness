# World objects and state ownership

This is the current ownership map for naturally occurring objects in the
Summer Valley territory. It exists to prevent a visual node being mistaken for
the source of a gameplay resource.

| Object | Scene ownership | Runtime source of truth | Saved today |
| --- | --- | --- | --- |
| Terrain surface | `Terrain3dWorld/Terrain3D` | Terrain3D data | terrain asset | 
| Trees | `Terrain3dWorld/LandscapeObjects` | `ForagingService` + `tree_nodes` keyed by board cell | yes: wood, branches, felled and exhausted flags |
| Grass patches | `LandscapeObjects` | `grass_sources` (`GrassSourceRecord`) | **no** |
| Wild forage | `LandscapeObjects` | `forage_sources` + `forage_respawn_at` | **no** |
| Rabbits | `LandscapeObjects` | `rabbit_sources` + `rabbit_respawn_at` | **no** |
| Ponds | `LandscapeObjects` | fixed cells + `pond_positions` | regenerated deterministically |
| Starter trash piles | `LandscapeObjects` | `ResourcePileService.resource_piles` | yes, as resource piles |
| Citizen/logistics piles | game root | `ResourcePileService.resource_piles` | yes, as resource piles |

## What happens at a new launch

`SettlementGame._ready()` creates a new `AmbientSpawner`, then initializes the
fixed forest, starter trash, initial rabbits and ponds. The locations are
hard-coded in `AmbientSpawner`; quantities use the game RNG. The terrain scene
previously contained no child for these objects, which is why they appeared at
the game root. `LandscapeObjects` now owns their visuals without changing the
resource registrations used by AI, player interaction, navigation or logistics.

## Relationship to progression and saves

`SettlementState` owns settlement progression: era, unlocks, money, storage,
equipment, research and policies. Natural-resource availability is **not** in
that state. It is runtime world state spread across `SettlementGame`,
`AmbientSpawner` and `ForagingService`.

The save format currently persists only tree deltas and physical resource piles.
Consequently a save/load reconstructs grass, forage and rabbits from a fresh
launch; their depleted/respawn state is lost. This is the remaining correctness
gap, not a scene-hierarchy issue.

## Next refactor boundary

Create a typed `WorldResourceState` in the `world` feature, keyed by stable
board cell and containing tree, grass, forage, rabbit, pond and respawn data.
`AmbientSpawner` should become a presentation projection of that state, while
`ForagingService` mutates it through narrow methods. Serialize this record under
`SaveData.world_state` (including biome ID and generation seed), then recreate
visuals from it on load. Do not put `Node3D` references in that record; keep
them in a presentation registry keyed by the same stable cells.
