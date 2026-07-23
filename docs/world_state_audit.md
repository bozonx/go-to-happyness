# World objects and state ownership

This is the current ownership map for naturally occurring objects in the
Summer Valley territory. It exists to prevent a visual node being mistaken for
the source of a gameplay resource.

| Object | Scene ownership | Runtime source of truth | Saved today |
| --- | --- | --- | --- |
| Terrain surface | `Terrain3dWorld/Terrain3D` | Terrain3D data | terrain asset | 
| Trees | `Terrain3dWorld/LandscapeObjects` | `WorldResourceState.trees` keyed by board cell | yes: wood, branches, felled and exhausted flags |
| Grass patches | `LandscapeObjects` | `grass_sources` (`GrassSourceRecord`) | yes: remaining amount |
| Wild forage | `LandscapeObjects` | `forage_sources` + `forage_respawn_at` | yes: source and respawn state |
| Rabbits | `LandscapeObjects` | `rabbit_sources` + `rabbit_respawn_at` | yes: position, direction and respawn state |
| Ponds | `LandscapeObjects` | fixed cells + `pond_positions` | regenerated deterministically |
| Starter trash piles | `LandscapeObjects` | `ResourcePileService.resource_piles` | yes, as resource piles |
| Citizen/logistics piles | game root | `ResourcePileService.resource_piles` | yes, as resource piles |

## What happens at a new launch

`SettlementGame._ready()` asks the active `BiomeDefinition` for its immutable
`BiomeLayout`, then `AmbientSpawner` projects that layout into the territory.
The Summer Valley layout lives in
`presentation/biomes/summer/summer_valley/summer_valley_layout.tres`; it owns
the fixed tree/pond cells and starter loot. The terrain scene itself only owns
the `LandscapeObjects` presentation container.

## Relationship to progression and saves

`SettlementState` owns settlement progression: era, unlocks, money, storage,
equipment, research and policies. Natural-resource availability is **not** in
that state. It is runtime world state spread across `SettlementGame`,
`AmbientSpawner` and `ForagingService`.

`WorldResourceState` serializes mutable grass, forage, rabbit and respawn data
under `SaveData.world_state.natural_resources`. Trees and physical piles keep
their existing serializers. A load recreates presentation nodes from this data,
so resource availability no longer resets.

## Next refactor boundary

Tree mutations now go through `WorldResourceState`. Tree metadata is retained
only as a compatibility projection for presentation and legacy query code; it
is reconstructed from the state record and is not serialized. The next cleanup
can replace those remaining metadata reads with state queries without changing
the persistence boundary.
