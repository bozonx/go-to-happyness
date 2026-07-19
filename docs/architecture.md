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
    citizens/{domain,application,presentation}/
    decision/{domain,application}/
    logistics/{domain,application}/
    needs/application/
    production/{domain,application}/
    simulation/{domain,application}/
    world/{application,presentation}/
    ui/presentation/
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
- `decision`: native AI runtime, order publication, utility arbitration,
  reservations, behavior steps and deterministic workforce eligibility.
- `logistics`: courier tasks, delivery dispatch, canteen supply, trade and water
  collection. Domain task state such as `CourierTask` and `TradeOrder` belongs here.
- `needs`: simulation of personal needs that feed AI facts. The AI decides when to
  satisfy them; the needs service owns the values and effects.
- `production`: production-specific rules and systems, currently the sawmill.
- `simulation`: the deterministic clock, day-cycle events and simulation-wide
  scheduling.
- `world`: terrain, obstacle publication and world-only presentation.
- `routing`: navigation grid, route selection and route results. UI belongs in a
  future `ui/presentation` feature.
- `ui`: reusable UI panels that read view models or query results and emit user
  intent as signals. The bootstrap controller wires panel signals to application
  commands; panels never mutate settlement state directly.

## Building model

Keep the three building concepts separate:

- `BuildingDefinition`: immutable content data, eventually an editor-authored
  `Resource` in `game/data/buildings/`.
- `BuildingInstance`: typed runtime gameplay state, addressed by an ID.
- `BuildingView`: the `Node3D` and its collision/mesh representation.

`BuildingRegistry` is the current application-level source of truth for reserved and
completed footprints. Its `BuildingRecord` connects a placement cell and footprint to
the completed runtime node. Construction, navigation and demolition must use this
registry rather than maintain parallel position or footprint arrays.

`ConstructionService` and `DemolitionService` own typed construction and demolition
queues. Their scene, economy, worker and completion dependencies are explicit runtime
callbacks, not a bootstrap-controller reference. Building placement and completion
effects remain the next building subsystems to move behind the same narrow boundary.

`building_blueprints.gd` is presentation code. It may build geometry and collision,
but it must not decide costs, unlocks, production or staffing. Do not use `Node3D`
metadata or arbitrary dictionaries as a new source of building state; introduce a
typed runtime record and registry as the building feature grows.

## Citizen, decision, needs and routing boundaries

`Citizen` is currently a transitional actor that still contains movement, task
execution and some role state. New movement and physics code belongs with the
citizen presentation actor. New task selection belongs in `decision/application`;
new deterministic eligibility rules belong in `decision/domain`.

The native AI runtime is the decision boundary. It reads through `AIWorldFacade`
and issues commands only through `CitizenActuator`; it must not read the
composition root directly.

`SettlementDirector` publishes settlement-scale work through `OrderProvider`
implementations. `CitizenBrain` decides whether the current citizen should execute
that order now or satisfy a personal need first. Do not let a feature bypass this
split by directly steering citizens from a global service.

Personal needs are state, not task selection. `needs/application` owns hunger,
rest, toilet and future need parameters; decision goals read immutable facts and
apply effects only through actuator commands and feature services.

Routing lives in `routing/application` as `NavGrid`, `GridRouteService` and
`RouteResult`. Route selection rules must not depend on `Citizen` nodes or UI
nodes; world code only publishes obstacles and coverage data to the grid.

Logistics owns delivery tasks. Producers publish or request deliveries; they do
not directly pick walkers or mutate courier state except through the logistics
dispatcher and AI order path.

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
7. Add new AI mechanics as vertical slices: facts in the facade, an order provider
   when there is global competition, a goal, behavior steps, actuator commands,
   reservation rules and tests. Delete the old write owner in the same change.
8. Keep citizen identity stable. AI ids, order ids, reservation keys and target
   keys must be stable value identifiers; do not use runtime `ObjectID` as saved or
   cross-system identity.

## Migration boundary

The native AI migration is the primary execution path. Continue extracting
bootstrap implementation into feature modules incrementally without a behavior
rewrite:

1. Extract building placement and completion effects. Construction and demolition
   queues already belong to buildings/application; preserve those boundaries instead
   of adding feature logic back to the bootstrap controller.
2. Keep moving delivery and trade state into `logistics/{domain,application}`.
   `CourierDispatcher` remains the owner of courier task assignment while task
   producers migrate to typed requests.
3. Move remaining need state and effects behind `needs/application` and expose them
   to AI only as facts.
4. Add road coverage and desire-line traffic through the `routing` request/result
   API without pushing routing rules back into the bootstrap controller.
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
headless entries remain `tests/test_domain.gd`, `tests/test_ai.gd`,
`tests/test_materials_yard.gd` and `tests/test_startup.gd` until they are moved
alongside their new test categories.

Run the domain checks with:

```sh
godot --headless --path . --script res://tests/test_domain.gd
```

Run AI and materials-yard checks when changing citizens, orders, workforce,
logistics or early gathering:

```sh
godot --headless --path . --script res://tests/test_ai.gd
godot --headless --path . --script res://tests/test_materials_yard.gd
```
