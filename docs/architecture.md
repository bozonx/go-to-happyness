# Architecture

## Structure

The project uses a feature-first layout. Gameplay code lives under `game/features`,
with its rules, orchestration and Godot-facing code kept close to the feature that
owns it.

```text
game/
  bootstrap/
    settlement_game.tscn
    settlement_game.gd
  features/
    settlement/domain/
    buildings/{domain,application,presentation}/
    citizens/{domain,presentation}/
    decision/{domain,application}/
    logistics/application/
    production/{domain,application}/
    simulation/application/
    world/presentation/
```

`game/bootstrap/settlement_game.tscn` is the configured main scene. Its
`settlement_game.gd` controller is the composition root: it creates the runtime
services, wires signals and drives the simulation tick. It must not become the owner
of new feature rules or UI implementation.

## Layer boundaries

Each feature may use these layers when it needs them:

- `domain/`: deterministic rules and gameplay state. It must not depend on nodes,
  rendering, physics, input, UI or wall-clock time.
- `application/`: use cases and systems that coordinate domain state, actors and
  feature services. It exposes focused commands and queries.
- `presentation/`: `Node`, `Node3D`, `Control`, procedural mesh, terrain, camera
  and input code. It renders state and forwards user intent to application code.

Dependency direction is one way:

```text
presentation -> application -> domain
bootstrap -> all features
```

Godot- or persistence-specific adapters belong in a feature's `presentation/` layer
until a shared `game/infrastructure/` implementation is genuinely needed. Do not
create generic `utils`, `helpers`, `managers` or catch-all `services` directories.

## Feature ownership

- `settlement`: economy, stored resources, eras, wellbeing and global progression.
- `buildings`: definitions, placement, construction, demolition and building visuals.
- `citizens`: citizen profiles, task state, actor movement and task execution.
- `decision`: workforce policy, GOAP adapter and work assignment coordination.
- `logistics`: couriers, canteen deliveries, trade and water collection.
- `production`: production-specific rules and systems, currently the sawmill.
- `simulation`: the deterministic clock and simulation-wide scheduling.
- `world`: terrain and world-only presentation. Future routing code belongs in a
  `routing` feature; UI belongs in a `ui/presentation` feature.

## Building model

Keep the three building concepts separate:

- `BuildingDefinition`: immutable content data, eventually an editor-authored
  `Resource` in `game/data/buildings/`.
- `BuildingInstance`: typed runtime gameplay state, addressed by an ID.
- `BuildingView`: the `Node3D` and its collision/mesh representation.

`building_blueprints.gd` is presentation code. It may build geometry and collision,
but it must not decide costs, unlocks, production or staffing. Do not use `Node3D`
metadata or arbitrary dictionaries as a new source of building state; introduce a
typed runtime record and registry as the building feature grows.

## Citizen, decision and routing boundaries

`Citizen` is currently a transitional actor that still contains movement, task
execution and some role state. New movement and physics code belongs with the
citizen presentation actor. New task selection belongs in `decision/application`;
new deterministic eligibility rules belong in `decision/domain`.

The GOAP integration is an adapter, not the source of game rules. It may request a
decision and execute an assigned command, but it must use a narrow decision/query
interface rather than read the composition root directly.

Routing must be introduced as its own feature with a route request/result API. The
navigation mesh and obstacle registry remain Godot-facing; route selection rules do
not depend on `Citizen` or UI nodes.

## Rules for new code

1. Add a file to the feature that owns the behavior, not to a global technical
   folder. Add a new feature only when it has an independent reason to change.
2. Keep one source of truth. UI reads a view model or query result and emits intent;
   it never changes settlement state directly.
3. Prefer typed classes such as `ConstructionSite`, `TradeOrder`, `ResourcePile` and
   `SawmillStock` over ad hoc dictionaries. Use `StringName` or constants for stable
   IDs instead of duplicating string literals.
4. Keep service dependencies narrow. A service must not hold `simulation: Node` and
   reach into unrelated fields; inject the specific state, registry or callable it
   needs.
5. Emit typed gameplay events at feature boundaries. UI notification formatting and
   colours belong in the UI feature, not in domain rules.
6. Prefer a scene per reusable UI panel or actor over constructing a growing UI tree
   inside the bootstrap controller.

## Migration boundary

The physical migration is complete, but `settlement_game.gd` still contains legacy
implementation for several features. Extract it incrementally without a behavior
rewrite:

1. Move clock/day-cycle scheduling into `simulation/application`.
2. Introduce a building registry, then extract placement, construction and demolition.
3. Extract courier dispatch and resource delivery into `logistics/application`.
4. Extract navigation and routing behind a route service.
5. Move each UI panel into `ui/presentation` and make it consume commands and query
   results instead of bootstrap fields.
6. Split the citizen actor only after its movement and task-execution contracts are
   covered by tests.

Keep short compatibility delegates in the bootstrap controller only while a caller is
being migrated. Delete them with the final caller; do not let them become a permanent
API.

## Tests

Put pure rule tests in `tests/unit/domain`, application/system tests in
`tests/unit/application`, and scene startup checks in `tests/smoke`. The existing
headless entries remain `tests/test_domain.gd` and `tests/test_startup.gd` until they
are moved alongside their new test categories.

Run the domain checks with:

```sh
godot --headless --path . --script res://tests/test_domain.gd
```
