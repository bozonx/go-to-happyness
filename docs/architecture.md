# Architecture

## Structure

The project uses a feature-first layout. Gameplay code lives under `game/features`,
with its rules, orchestration and Godot-facing code kept close to the feature that
owns it.

```text
game/
  bootstrap/
    game_runtime.tscn
    game_runtime.gd
    settlement_game.tscn
    settlement_game.gd
  content/
  features/
    buildings/{domain,application,presentation}/
    citizens/{domain,application,presentation}/
    content/{domain,application,presentation}/
    decision/{domain,application,presentation}/
    entities/{domain,application}/
    events/{domain,application,presentation}/
    logistics/{domain,application,presentation}/
    needs/application/
    production/{domain,application,presentation}/
    runtime/{domain,application,presentation}/
    routing/{domain,application,presentation}/
    save_load/{domain,application}/
    settlement/{domain,application,presentation}/
    simulation/{domain,application}/
    ui/{domain,application,presentation}/
    world/{domain,application,presentation}/
```

`game/content/` holds the authored content packs (`pack.json`, `*.gdbuilding.json`,
`*.gdarchetype.json`, `*.gdmap/`); `game/features/content/` holds the code that reads
them.

`features/entities/` owns what a placed thing *is* — archetypes, their property
schema and their states, all of it pack data
(`design_docs/engine/map_fill_mode.md` §4). It deliberately knows no component by
name: the module that executes a component introduces and validates it.

`project.godot` starts the host main menu. `GameRuntime` is the composition root of one
selected game session; `game/bootstrap/settlement_game.tscn` is the temporary
presentation root of the `gth.settlement` module. Its controller still wires the
settlement services and simulation tick, but it must not become the owner of new feature
rules, host UI or session-wide infrastructure.

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

- `content`: authored content packaging — packs, content ids, style resolution and
  the save stamp shared by blueprints, maps and game definitions. `ContentIndex.shared()`
  is the one index every reader uses; every writer calls `ContentIndex.invalidate()`.
  See `design_docs/engine/content_packaging.md`.
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
- `runtime`: game definitions, session configuration, the registry of built-in
  game modules and their composition order, and the two host features a
  code-free pack opts into with data — **progression** (`GameProgressionDefinition`,
  `ProgressionPolicy`, `SessionProgression`) and **declared start parameters**
  (`StartParameterDef`). It owns no settlement rule, actor type or UI panel.
  `GameRuntime` is the generic session root. `core.world` creates the session's
  `WorldSession` (map, `WorldSetup`, and terrain/water navigation) and validates
  the map's `required_content` and its pack's `requires` before any gameplay
  module starts; a game module may add its own overlays and obstacles but never a
  second map world. `SettlementGameModule` temporarily starts the existing
  settlement bootstrap through this boundary while its services are extracted
  incrementally.
- `simulation`: the deterministic clock, day-cycle events and simulation-wide
  scheduling.
- `events`: data-driven random events — definitions, conditions, outcomes,
  delayed effects and the choice UI. See `design_docs/settlement/event_system.md`.
- `save_load`: save file schema and the save/load service. `SessionSaveCoordinator`
  owns the generic save envelope — `game`/`map`/`engine` headers plus one section per
  participating module, each stamped with its owner's `section_version()`; per-game
  sections are still read through `SaveGameService` by the owning module. The envelope
  itself does not migrate: an unreadable `format_version` is refused, and a section from
  an older module version goes through that module's `migrate_section`. See
  `design_docs/engine/multi_purpose_engine.md` §3.5.
- `world`: terrain, water, maps, the map editor and world-only presentation.
- `routing`: navigation grid, route selection and route results. UI belongs in a
  future `ui/presentation` feature.
- `ui`: reusable UI panels that read view models or query results and emit user
  intent as signals. The bootstrap controller wires panel signals to application
  commands; panels never mutate settlement state directly.

## Building model

Keep the three building concepts separate:

- `BuildingBlueprint`: immutable authored content in a `.gdbuilding.json` pack file.
- `BuildingInstance`: typed runtime gameplay state, addressed by an ID.
- `BuildingView`: the `Node3D` and its collision/mesh representation.

`BuildingPlacementService` is the source of truth for putting a blueprint on terrain:
the dry-run plan, terrain merge, `MapPlacementRecord`, overlap and terrain anchors are
one lifecycle. The map editor and player construction differ only by `PlacementPolicy`.
During a session, `WorldSession.placement_layer` copies authored placements and owns
dynamic player records without mutating the authored map.

`BuildingRegistry` is the gameplay index for reserved and completed runtime nodes. Its
`BuildingRecord` connects the placement's centre cell and footprint to a node, but it
does not validate terrain or write anchors. Construction, navigation and demolition use
this registry for gameplay lookup and release the corresponding placement record when
the node leaves the world.

`ConstructionService` and `DemolitionService` own typed construction and demolition
queues. Their scene, economy, worker and completion dependencies are explicit runtime
callbacks, not a bootstrap-controller reference. `BuildingPlacementController` is the
session adapter that resolves authored blueprints and supplies settlement policy to the
world-owned placement service; it contains no second placement calculation.

`building_blueprints.gd` is presentation code. It builds authored geometry and collision,
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

Routing lives in `routing/application` as `NavGrid`, `GridRouteService`,
`NavigationFacade` and `RouteResult`. Route selection rules must not depend on
`Citizen` nodes or UI nodes; world code only publishes obstacles and coverage
data to the grid. New graph implementations are introduced only for a genuinely
different topology (indoor rooms/doors, road lanes, or 3D air), behind
`RouteSolver` and explicit portals. New vehicles and robots normally add a
`TravelerProfile` with physical constraints rather than a new router. Patrols,
bus lines, formations and convoys consume route results from their owning
feature; they are not routing graph layers.

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

## Session and launch boundary

The player launch path is `game definition -> GameSessionConfig ->
RuntimeLaunchManager -> GameRuntime -> registered modules`. The host menu indexes
installed game definitions from content packs, and `Esc` returns any running game to
that library. The shipped `core:settlement` definition selects `core.world` and
`gth.settlement`; `core:world_showcase` proves another game can use the same world
module without Settlement.

- **`GameRuntime` carries no game-specific field** — no citizen, era, wellbeing,
  building or settlement resource. Game-specific values live in a module's start
  parameters. `GameSessionConfig` may hold a map, seed and definition, and nothing else.
- **`SettlementGame` is the settlement module's presentation adapter**, created only by
  `SettlementGameModule`. Scene tests enter through `GameRuntime` too; do not add a
  launch path that bypasses it.
- **`SessionSaveCoordinator` owns the save envelope.** `SaveData` v5 persists the
  `game`, `map` and `engine` headers plus one versioned section per participating
  module. The settlement scene has no save entry point of its own. Pre-v5 saves are not
  migrated: the project has no released save format, and an adapter would outlive the
  formats it reads.
- **Eras are host functionality, not a settlement rule.** A definition declares the
  catalogue, a map narrows it in `start.progression`, and `SessionProgression` resolves
  the two plus the player's choice once per session. A module projects the resolved
  record onto its own stage type. Do not add a second owner of era state.
- **The launch screen and the game editor build controls from
  `GameModule.start_parameters()` and the definition's `menu_parameters`.** Neither may
  contain a widget keyed to a module id.
- **`HostInputController` handles registered profile shortcuts before module scenes.**
  The first supported profile is `rts` (`F5` quicksave, `Esc` back to the library, or
  back to the originating editor when the session is a test run).

### Extraction still in progress

`settlement_game.gd` remains a transitional controller. Extract from it incrementally,
without a behaviour rewrite, and delete the old write owner in the same change:

1. Building placement and completion effects. Construction and demolition queues already
   belong to `buildings/application`; do not add feature logic back to the controller.
2. Delivery and trade state into `logistics/{domain,application}`. `CourierDispatcher`
   stays the owner of courier task assignment while producers migrate to typed requests.
3. Remaining need state and effects behind `needs/application`, exposed to AI as facts.
4. Road coverage and desire-line traffic through the `routing` request/result API.
5. Each UI panel into `ui/presentation`, consuming commands and query results.
6. The citizen actor split — only after its movement and task-execution contracts are
   covered by tests.

Compatibility delegates in the controller live only while a caller is being migrated.
Delete them with the final caller; they must not become a permanent API.

## Tests

Put pure rule tests in `tests/domain/`, application/system tests in
`tests/ai/`, and scene smoke tests in `tests/features/`. Diagnostic scripts
that only print output (no assertions) live in `tests/repro/` with a `diag_`
prefix so they are excluded from the test runner.

Run the domain and master unit checks with:

```sh
godot --headless --path . --script res://tests/run_all.gd
```

Run AI and materials-yard checks when changing citizens, orders, workforce,
logistics or early gathering:

```sh
godot --headless --path . --script res://tests/run_all.gd
godot --headless --path . --script res://tests/features/construction/test_materials_yard.gd --quit-after 300
```
