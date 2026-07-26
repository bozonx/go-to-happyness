# Agent Guide

Working context for **Go To Happyness**, a Godot 4.7 settlement-simulation prototype.

This file covers **how to work in this repo**. It does not restate the architecture —
[`docs/architecture.md`](docs/architecture.md) is the single source of truth for layers,
feature ownership and the rules for new code. Read it first; read this for the
operational parts it does not cover.

## Project basics

- Engine **Godot 4.7**, Forward Plus, **Jolt Physics** for 3D. GDScript only.
- `project.godot` boots `game/features/ui/presentation/main_menu/main_menu.tscn`.
  The gameplay scene is `game/bootstrap/settlement_game.tscn`, reached through
  `GameLaunchManager`.
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
  `engine/grid_terrain_system.md` §9). It is authored, never simulated. Depth is **not** stored —
  it is water level minus ground — so raising a lake bed drains it.
- **All terrain and water edits go through `TerrainService` / `WaterService`.** The commit
  is what republishes navigation and keeps undo and the mesher in step. Writing the grid
  directly means republishing by hand (`TerrainNavigationPublisher.publish_all`) — a bug
  waiting to happen. Water *is* passability: ford ×3, deeper is a wall, lava never, ice by
  thickness.
- Re-run `tests/repro/diag_terrain_nav_publish_cost.gd` after touching the publisher or
  `NavGrid` hot paths; budgets are in `engine/grid_terrain_system.md` §10.5.

## Map editor and `.gdmap`

A map is a folder package (`map.json` + `terrain.bin` + `preview.png`) under
`res://game/content/core/maps/` or `user://custom_maps/`, opened by `MapDocumentService`.
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
- `tests/features/world/test_map_editor.gd` drives the real scene end to end. Unit tests
  over the brush and format prove the parts; only that one proves the editor.

## Weather and lighting laboratory

Weather, time of day, sky, stars, sun/moon, atmospherics and world lighting start in
`res://tools/weather_lab/weather_lab.tscn`, using the production
`SkyAndWeatherController`, cloud shader, rain and firefly effects with a fixed camera and
calibration geometry.

- Make and inspect the relevant preset before wiring a visual change into gameplay:
  F1–F5 interactively, or `godot --path . res://tools/weather_lab/weather_lab.tscn -- --capture`
  to write PNGs to `user://weather_lab/`. Open the captures after a visual change.
- `CloudCamera` (`2`) for cloud work, `ContextCamera` (`1`) to confirm it still reads over
  the settlement, `ZenithCamera` (`3`) for tiling/stars, `HorizonCamera` (`4`) for
  atmospheric perspective. Batch presets capture as `cloud_noon`, `cloud_sunset`,
  `cloud_storm`.
- Keep deterministic time and forecast rules in `simulation/domain`; the lab and the game
  both feed visual values into `world/presentation`. A weather feature must not depend on
  `SettlementGame` to render.
- Add or update a named preset whenever a change needs a repeatable visual case.

## Pitfalls

- `building_blueprints.gd` is presentation-only. It builds geometry; it must not decide
  costs, unlocks, production or staffing.
- Never leave two write-owners for one mechanic. A behaviour change replaces the legacy
  owner in the same commit.
- Tests that preload `settlement_game.gd` parse the whole bootstrap controller: a missing
  function referenced there fails unrelated tests at load time.
- Design docs live in `design_docs/` (what to build), split by subsystem:
  `engine/` (terrain, water, maps, building format, packs), `citizens/` (AI, needs,
  orders, labour) and `settlement/` (eras, economy, content). `design_docs/README.md`
  is the index; start there rather than guessing a path. `docs/` holds engineering
  docs (how it is built): `architecture.md` and `gameplay.md`.
- `design_docs/ideas.md` holds directions beyond the development horizon. It is not a
  source of truth — do not implement from it, and do not leave far-future design in a
  subsystem doc where it reads as a requirement.
