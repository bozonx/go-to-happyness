# Architecture

## Runtime responsibilities

`MainSimulation` is the scene composition root. It owns Godot nodes, input routing,
scene-local UI and the lifecycle of runtime services. It should not become the source
of truth for feature rules.

`BuildingCatalog` owns build and research economy definitions. Add a building there
before adding its geometry to `BuildingBlueprints` and runtime completion handling.

`BuildingBlueprints` owns procedural visuals and collision modules only. It does not
decide prices, production or unlock conditions.

`WorkforceCoordinator` owns work eligibility and task assignment. `MainSimulation`
keeps compatibility methods because GOAP currently uses them; new AI code should use
the coordinator or a narrow scheduling interface rather than read scene state.

`Citizen` is presently an actor with movement and task execution. New task selection
belongs in a coordinator or GOAP action; new movement behavior belongs in the actor.

## Extension rules

1. Put content configuration in `scripts/domain`, not in UI labels or `match` blocks.
2. Use typed `Resource` data when definitions become editor-authored or need variants.
3. Put cross-citizen coordination in a service and expose small query methods from the
   scene controller instead of reading unrelated mutable fields.
4. Preserve signals as the boundary from `Citizen` to the simulation economy.
5. Keep scenes declarative. Procedural runtime nodes are created by a scene controller
   or dedicated factory, never from a domain definition.

## Testing priorities

Add headless tests before changing economy or scheduling rules. Cover building payment,
research payment, work eligibility and task assignment first; they are deterministic
and do not require rendering or voxel terrain.
