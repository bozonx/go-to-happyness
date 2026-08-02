# Agent Guide

Working context for **Go To Happyness**, a Godot 4.7 settlement-simulation prototype.

This file covers **how to work in this repo**. It does not restate the architecture —
[`docs/architecture.md`](docs/architecture.md) is the single source of truth for layers,
feature ownership and the rules for new code. Read it first; read this for the
operational parts it does not cover.

## Project basics

- Engine **Godot 4.7**, Forward Plus, **Jolt Physics** for 3D. GDScript only.
- `project.godot` boots `game/features/ui/presentation/main_menu/main_menu.tscn`.
  The gameplay runtime is `game/bootstrap/game_runtime.tscn`, reached through
  `GameLaunchManager`. The settlement scene `game/bootstrap/settlement_game.tscn`
  is a temporary presentation adapter owned by `SettlementGameModule`.
- Feature-first layout under `game/features/<feature>/{domain,application,presentation}/`,
  composed by `game/bootstrap/`.
- Authored content is a pack tree under `game/content/` (`pack.json`, `*.gdbuilding.json`,
  `*.gdmap/`), not `Resource` files. User content lives in `user://`.

## Conventions

**Reference other scripts by `class_name`, not by `preload` path.** Every script in
`game/` declares one. `const FooScript = preload("res://.../foo.gd")` is not a pattern
here — it hides the type, goes stale when files move, and duplicates what the global
class cache already provides. Keep `preload` only for `PackedScene` (`.tscn`), which has
no global name.

Those globals resolve through `.godot/global_script_class_cache.cfg`, which **only an
import pass writes**. On a cold checkout, or right after adding a new `class_name`, run
`godot --headless --path . --import` before anything else — otherwise scripts fail with
`Could not find type X in the current scope`, a parse error that looks nothing like its
cause. `scripts/run_tests.sh` does this for you.

**A leading `_` must mean private.** If something outside the class calls it, it is part
of that class's API — name it accordingly. `SettlementGame` in particular has no hidden
API left; do not add one back.

**Static node hierarchies belong in `.tscn`.** Fixed, single-instance children of the
main scene are declared in `settlement_game.tscn` and picked up with `@onready`
(`CameraController`, `UIManager`). Build nodes in code only for genuinely dynamic
content — citizens, construction sites, the world built from the launched map.

## Tests

```sh
./scripts/run_tests.sh              # import + unit suites + every scene test
```

Individual runs (after an import pass):

```sh
godot --headless --path . --script res://tests/run_all.gd
godot --headless --path . --script res://tests/features/simulation/test_startup.gd --quit-after 300
```

- `tests/domain/` pure rules, `tests/ai/` application/system, `tests/features/` scene
  smoke tests. Print-only diagnostics go in `tests/repro/` with a `diag_` prefix so the
  runner's `test_*.gd` pattern skips them.
- Unit tests run in `_init()` and `quit(0)` without awaiting frames. Scene tests need a
  frame budget: use `--quit-after 300`, never `--quit` (it exits after the first
  iteration and can cut awaited setup short).
- Use `SimulationTestHelper` for scene tests: `setup_simulation`, `cleanup_simulation`,
  `appoint_test_official`.
- `--headless` already implies `--display-driver headless --audio-driver Dummy`.
- **Sandbox: always set `XDG_DATA_HOME` to a temp dir.** Godot creates `user://logs/`
  during engine startup, before any project script runs. In a sandboxed environment the
  default `user://` path (`~/.local/share/godot/...`) is not writable, so the engine exits
  before the project loads — the error looks like a project failure but is a permissions
  issue. `scripts/run_tests.sh` handles this; when running Godot manually, replicate it:
  `XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . ...`

## AI system

Native runtime, **not GOAP**. See `design_docs/citizens/citizen_ai.md`.

- `AIWorldFacade` is the only read boundary (it produces a `WorldSnapshot`);
  `CitizenActuator` is the only write boundary.
- `SettlementDirector` publishes settlement-scale work via `OrderProvider`s;
  `CitizenBrain` chooses between the current order and a personal need.
- Goals score utility in `[0, 1]` and build a `BehaviorTask` of `BehaviorStep`s.
- Add a mechanic as a vertical slice: facts, order provider, goal, behavior steps,
  actuator commands, reservations, tests. Never reach `SettlementGame` from a goal or
  step. Keep identity on `ai_id`, never `get_instance_id()`.

## Terrain laboratory

Terrain changes — heights, slopes, cascade, meshing, how navigation reads the ground —
start in `res://tools/terrain_lab/terrain_lab.tscn`, not the settlement scene. It runs
the production `TerrainGrid`, `TerrainService`, chunk mesher and `NavGrid` in isolation.

- Passability is invisible in a rendered mesh: two terraces and a slope look identical.
  Press `M` for the navigation overlay and `T` to switch traveller profile before judging
  a change. A green board with no red walls proves nothing until the overlay is on.
- `godot --path . res://tools/terrain_lab/terrain_lab.tscn -- --capture` writes
  references to `user://terrain_lab/`. `nav_pedestrian`, `nav_cart` and `nav_ramps_closeup`
  are the passability set; `water_overview`, `water_nav_pedestrian` and
  `water_lava_closeup` the water set. If you can read images, open them after a visual
  change — a clean parse is not evidence.
- The brush is not in the lab. Raise, level, paint, wear, snow, hole and ramp live in
  `TerrainBrushController` (`game/features/world/presentation/editor/`), with
  `WaterBrushController` beside it — shared by the lab, the map editor and the building
  editor's terrain layer. A host binds keys and draws the hover marker; it never
  reimplements a tool.
- Water is a second layer over the same board (`WaterGrid` + `WaterBody` registry,
  `engine/water.md`). It is authored, never simulated. Depth is **not** stored —
  it is water level minus ground — so raising a lake bed drains it.
- **There is exactly one water system.** The old pond props plus hand-written
  `terrain_blocked_cells` are gone; a session with no map digs the biome's ponds into the
  real grids (`StarterWater`), and everything gameplay asks about water goes through
  `WaterAccessService`. Do not reintroduce a second list of "where the water is".
- `border.kind` in the map header is a global option: `ocean` draws the horizon plane and
  makes `BorderOceanService` flood any rim-connected lowland below `border.level` after
  every terrain stroke; `nothing` draws nothing and floods nothing (`engine/map_editor.md`
  §6.1). The fill joins the stroke's undo entry — one author action, one Ctrl+Z.
- Frozen water has a collider and open water does not. Routing walks ice at the water
  level, so without that floor `move_and_slide` drops the walker to the lake bed.
- A registry change publishes only the cells it reaches. Creating an empty body must stay
  free: republishing the board for it cost 2.5 s per palette click at 256×256.
- **All terrain and water edits go through `TerrainService` / `WaterService`.** The commit
  is what republishes navigation and keeps undo and the mesher in step. Writing the grid
  directly means republishing by hand (`TerrainNavigationPublisher.publish_all`) — a bug
  waiting to happen. Water *is* passability: ford ×3, deeper is a wall, lava never, ice by
  thickness.
- Re-run `tests/repro/diag_terrain_nav_publish_cost.gd` after touching the publisher or
  `NavGrid` hot paths; budgets are in `engine/grid_terrain_system.md` §10.5.

## Map editor and `.gdmap`

A map is a folder package (`map.json` + `terrain.bin` + `preview.png`) under
`res://game/content/core/maps/` or a user pack's `maps/`, opened by `MapDocumentService`.
It owns the board size and starting conditions; `SettlementGame.BOARD_CELLS` is only the
no-map fallback. See `design_docs/engine/map_editor.md`.

- The editor is `game/features/world/presentation/editor/map_editor.tscn`. `map_editor.gd`
  loads the document, switches modes, routes input and owns the one undo stack —
  **nothing else**. Mode behaviour goes in a `<mode>_mode_controller.gd` reached through
  `MapEditorContext`. An `if mode == ...` in the editor's input handling means logic leaked
  out of a controller; that is what took `building_editor.gd` to 2159 lines.
- Static editor UI is authored as `.tscn` under `editor/ui/`, one scene per panel. Build
  nodes in code only for genuinely dynamic children.
- One undo stack across all modes (`MapEditorHistory`), deliberately unlike the building
  editor's per-mode decor stack. Terrain commands delegate to `TerrainService`'s delta
  stack rather than copying it.
- `MapDocument` carries sections this build does not interpret (rules, markers,
  placements) and writes them back untouched. A phase-1 editor must not eat the rules of a
  phase-5 map.
- Never write a map package non-atomically. `MapDocumentService.save_map_to` stages into
  `.tmp` and swaps; a crash must leave the previous map intact.
- **Board cells are centred on the origin**, `-N/2 … N-N/2-1`, in `TerrainGrid`, `NavGrid`
  and the zone layer alike. A `0 <= cell < board_cells` check is the recurring bug of this
  codebase: it looks right, passes every test whose fixture sits east of the origin, and
  silently drops three quarters of the map. Ask `MapZoneLayer.is_board_cell` /
  `TerrainGrid.is_inside`, and put at least one negative cell in any fixture that covers
  board geometry.
- Zones are one model for two editors, so their authoring code is shared on purpose:
  `ZoneAuthoring` (drag rectangle, unique ids, cascading delete), `ZoneMarkerStyle`
  (colours, sizes, glyphs), `ZoneFunctionCatalog`. Adding a second copy inside either
  editor is how the two drifted last time — see `design_docs/engine/active_zones.md` §19.
- `tests/features/world/test_map_editor.gd` drives the real scene end to end. Unit tests
  over the brush and format prove the parts; only that one proves the editor.

## Map generation laboratory

Procedural map generation starts in `res://tools/map_gen_lab/map_gen_lab.tscn`, not in
the map editor. It runs the real `TerrainGenerationService` over the real `TerrainGrid`,
`WaterGrid`, mesher and `NavGrid`. The rules are in
`design_docs/engine/procedural_map_generation.md`; read §10.1 before changing anything
about slopes, rivers or metrics, because that is where the non-obvious constraints are.

- A recipe is data (`*.gdmapgen.json`), parsed and **validated** by `MapRecipe`. A
  contradictory request (`inland` with an ocean border, `archipelago` at 80 % land) is
  refused with a reason before any expensive stage runs — never clamped.
- The pure stages live in `world/domain/generation/` and are functions over
  `Packed*Array`s: no Node, no files, no services. The three that need the real grids —
  slopes, water, the verdict — live in `TerrainGenerationService`, which is the only
  application entry point.
- **Generation is not an undoable edit.** It writes the board in one bulk sweep,
  publishes navigation once and clears both histories; it creates a document rather than
  modifying one.
- Judge a recipe on **neighbouring seeds**, not on one pretty map: `[` and `]` step the
  seed and the metrics panel keeps the previous numbers beside the current ones. Press
  `M` before believing a range is crossable and `K` to see the crest graph the recipe
  actually produced.
- `tests/repro/diag_map_generation_presets.gd` runs every preset over three seeds
  without a display; `map_gen_lab.tscn -- --capture` does the same with views and a
  `metrics.json` in `user://map_gen_lab`. A preset that stops passing §6 is a regression
  of quality, and it is allowed to fail on a deliberate change of algorithm.

## Weather and lighting laboratory

Weather, time of day, sky, stars, sun/moon, atmospherics and world lighting start in
`res://tools/weather_lab/weather_lab.tscn`, not the settlement scene. It runs the
production `SkyAndWeatherController`, cloud shader, rain and firefly effects with fixed
cameras and calibration geometry. The rules themselves are in
`design_docs/engine/weather.md`; read it before changing how weather looks or behaves.

- Make and inspect the relevant scenario before wiring a visual change into gameplay:
  F-keys interactively, or `godot --path . res://tools/weather_lab/weather_lab.tscn -- --capture`
  to write PNGs to `user://weather_lab/`. Open the captures after a visual change — a
  clean parse is not evidence.
- Cameras: `CloudCamera` for cloud work, `ContextCamera` to confirm it still reads over
  the settlement, `ZenithCamera` for tiling and stars, `HorizonCamera` for atmospheric
  perspective, `TrackingCamera` to keep a sun/moon disc in frame at any hour, and
  `GameplayCamera` for anything that depends on where the player actually looks.
- **Cloud cover and storm murk are two independent axes** (`weather.md` §4). Grey and
  haze come only from the storm front; cloudiness alone never seals the sky. Do not
  collapse them because one preset would look better.
- Wind is a general weather parameter, not a cloud-shader input: flags and smoke
  read the same `wind_*` accessors so everything drifts one way. Water waves are a future idea.
- Keep deterministic forecast and time rules in `simulation/domain`; the lab and the game
  both feed visual values into `world/presentation`. A weather feature must not depend on
  `SettlementGame` to render.
- Add or update a named scenario whenever a change needs a repeatable visual case.

## Pitfalls

- `building_blueprints.gd` is presentation-only. It builds geometry; it must not decide
  costs, unlocks, production or staffing.
- Never leave two write-owners for one mechanic. A behaviour change replaces the legacy
  owner in the same commit.
- Tests that preload `settlement_game.gd` parse the whole bootstrap controller: a missing
  function referenced there fails unrelated tests at load time.
- Design docs live in `design_docs/` (what to build), split by subsystem:
  `engine/` (terrain, materials, water, weather, navigation, maps, building format,
  zones, packs, platform), `citizens/` (AI, orders, needs, workforce, labour, FPP) and
  `settlement/` (eras, buildings, survival, storage, food, fire, events).
  `design_docs/README.md` is the index; start there rather than guessing a path.
  `docs/` holds engineering docs (how it is built): `architecture.md` and `gameplay.md`.
  One mechanic has exactly one owning doc — a second mention links, it does not restate.
- `design_docs/ideas.md` holds directions beyond the development horizon. It is not a
  source of truth — do not implement from it, and do not leave far-future design in a
  subsystem doc where it reads as a requirement.
