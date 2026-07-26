# Agent Guide

This document contains the essential context for AI assistants working on **Go To Happyness**, a Godot 4.7 settlement-simulation prototype.

## Project basics

- Engine: **Godot 4.7**, Forward Plus renderer, **Jolt Physics** for 3D.
- Main scene: `game/bootstrap/settlement_game.tscn`.
- Language: GDScript. Prefer typed classes, `StringName` for stable identifiers, and interfaces (object shapes) over `type` aliases.

## Architecture

The project uses a **feature-first** layout under `game/features/<feature>/`.

```text
presentation -> application -> domain
bootstrap -> all features
```

Layers:

- `domain/`: deterministic rules and gameplay state. No nodes, rendering, physics, input, UI, or wall-clock time.
- `application/`: use cases and systems that coordinate domain state, actors, and feature services.
- `presentation/`: Godot nodes, procedural visuals, terrain, camera, and input.

Feature ownership:

- `content`: content packs, content ids, style resolution, shared save stamp.
- `settlement`: economy, stored resources, eras, wellbeing, progression.
- `buildings`: definitions, placement, construction, demolition, visuals.
- `citizens`: citizen profiles, task state, actor movement, task execution.
- `decision`: native AI runtime, order publication, utility arbitration, reservations, behavior steps.
- `logistics`: courier tasks, delivery dispatch, canteen supply, trade, water collection.
- `needs`: personal need simulation that feeds AI facts.
- `production`: production-specific rules, currently the sawmill.
- `simulation`: deterministic clock, day-cycle events, simulation-wide scheduling.
- `world`: terrain, obstacle publication, world-only presentation.
- `routing`: navigation grid, route selection, route results, route requests.
- `events`: random event definitions, event resolution, survival decision UI.

## Key rules

1. Add code to the feature that owns the behavior, not to generic `utils`, `helpers`, or `managers` folders.
2. Keep one source of truth. UI reads view models or query results; it never mutates settlement state directly.
3. Prefer typed records (`ConstructionSite`, `TradeOrder`, `ResourcePile`, `SawmillStock`) over ad hoc dictionaries.
4. Use `StringName` or constants for stable IDs. Do not use runtime `ObjectID` as saved or cross-system identity.
5. Keep service dependencies narrow. Inject the specific state, registry, or callable a service needs.
6. Emit typed gameplay events at feature boundaries. UI formatting and colours belong in a future UI feature.
7. Prefer `.tscn` scenes for static node hierarchies; use procedural creation only for dynamic/runtime-generated content.
8. Application services must not load presentation scenes or create visual nodes. Emit events or call bootstrap callbacks for visual side-effects.

## AI system

The game uses a **native AI runtime**, not GOAP. The key contract:

- `AIWorldFacade` is the only read boundary; it produces a `WorldSnapshot`.
- `CitizenActuator` is the only write boundary.
- `SettlementDirector` publishes settlement-scale work through `OrderProvider` implementations.
- `CitizenBrain` decides whether to execute the current order or satisfy a personal need first.
- Goals score utility in `[0, 1]` and build a `BehaviorTask` of `BehaviorStep` nodes.
- New AI mechanics must be added as vertical slices: facts, order provider, goal, behavior steps, actuator commands, reservations, and tests.

See `docs/architecture.md` and `design_docs/citizen_ai.md` before modifying AI behavior.

## Running tests and headless Godot

### Master & Domain Unit Tests

```sh
godot --headless --path . --script res://tests/run_all.gd
```

These tests run deterministically in `_init()`, call `quit(0)`, and do not `await` frame events.

### Feature Scene Smoke Tests (require frame processing)

```sh
godot --headless --path . --script res://tests/features/simulation/test_startup.gd --quit-after 300
godot --headless --path . --script res://tests/features/construction/test_materials_yard.gd --quit-after 300
```

### Recommended Test Runner

Use the consolidated test runner script:

```sh
./scripts/run_tests.sh
```

Or run individual tests with `timeout`:

```sh
run_test() {
  local script=$1
  local frames=${2:-0}
  shift 2
  if [[ "$frames" -gt 0 ]]; then
    timeout 60 godot --headless --path . --script "$script" --quit-after "$frames" "$@"
  else
    timeout 30 godot --headless --path . --script "$script" "$@"
  fi
}

run_test res://tests/run_all.gd
run_test res://tests/features/simulation/test_startup.gd 300
run_test res://tests/features/construction/test_materials_yard.gd 300
```

Use a frame budget generous enough for the slowest machine running CI; 300 frames is enough for the current smoke tests.

### Feature test conventions

- Use `SimulationTestHelper` (`res://tests/helpers/simulation_test_helper.gd`) for scene-based tests: `setup_simulation(self)` handles instantiation + frame warmup, `cleanup_simulation(self, sim)` handles teardown, and `appoint_test_official(sim, citizen)` replaces the duplicated helper.
- Diagnostic scripts (print-only, no assertions) go in `tests/repro/` with a `diag_` prefix so they are excluded from the test runner's `test_*.gd` pattern.
- Each feature test should focus on one area (startup, housing, construction, etc.) rather than testing everything in a single `_init()`.

### General headless notes

- `--headless` already sets `--display-driver headless --audio-driver Dummy`.
- Avoid `--quit` with scene tests; it exits after the first iteration and can interrupt awaited setup.
- If a headless run still stalls, check whether the script awaits frame signals. Add `--quit-after` or rewrite the test to perform frame-independent setup.
- For server-like runs, prefer `--quit-after 0` to disable the automatic quit.

## Common pitfalls

- Do not reference `SettlementGame` directly from AI goals or steps. Use the facade/actuator boundary.
- Do not add new building logic to `building_blueprints.gd`; that file is presentation-only.
- Do not leave two write-owners for the same mechanic. A behavior change must replace the legacy owner in the same commit.
- Keep citizen identity stable: use `ai_id`, not `get_instance_id()`, for saved or cross-system identifiers.
- Tests that preload `settlement_game.gd` parse the whole bootstrap controller; any missing function referenced in it will fail at load time, even for unrelated tests.

## Terrain laboratory

Changes to the grid terrain — heights, slopes, the cascade, meshing, or how
navigation reads the ground — must start in `res://tools/terrain_lab/terrain_lab.tscn`,
not in the settlement bootstrap scene. It runs the production `TerrainGrid`,
`TerrainService`, chunk mesher and `NavGrid` with nothing from the game around them.

- Passability is invisible in a rendered mesh: two terraces and a slope look
  identical. Press `M` for the navigation overlay and `T` to switch traveller
  profile before judging a terrain change. A green board with no red walls is not
  proof of anything until the overlay is on.
- Capture reference views with
  `godot --path . res://tools/terrain_lab/terrain_lab.tscn -- --capture`; they land
  in `user://terrain_lab/`. Agents that can inspect images must open them after a
  visual change. `nav_pedestrian` / `nav_cart` / `nav_ramps_closeup` are the
  passability set.
- The brush is not in the lab. Raise, level, paint, wear, snow, hole and ramp live
  in `TerrainBrushController`
  (`game/features/world/presentation/editor/terrain_brush_controller.gd`), shared
  by the lab, the map editor and the `Terrain Base` layer of the building editor.
  A host binds keys, draws the hover marker and reads `last_message`; it does not
  reimplement a tool.
- Terrain edits must go through `TerrainService`, never straight into the grid:
  that signal is what keeps undo, the chunk mesher and the published navigation
  field in step. A tool that writes the grid directly has to republish by hand
  (`TerrainNavigationPublisher.publish_all`), which is a bug waiting to happen.
- `tests/repro/diag_terrain_nav_publish_cost.gd` measures publication cost. Re-run
  it after touching the publisher or `NavGrid`'s hot paths; the budgets it guards
  are in `design_docs/core/grid_terrain_system.md` §10.5.

## Map editor and the `.gdmap` format

A map is a folder package (`map.json` + `terrain.bin` + `preview.png`) under
`res://game/features/world/data/maps/` or `user://custom_maps/`, opened by
`MapDocumentService`. It is the source of the board size and the starting
conditions; `SettlementGame.BOARD_CELLS` is now only the no-map fallback.
See `design_docs/core/map_editor.md`.

- The editor is `res://game/features/world/presentation/editor/map_editor.tscn`.
  `map_editor.gd` loads the document, switches modes, routes input and owns the
  one undo stack — **nothing else**. Mode behaviour goes in a
  `<mode>_mode_controller.gd` reached through `MapEditorContext`. An
  `if mode == ...` inside the editor's input handling means logic leaked out of a
  controller; that is what took `building_editor.gd` to 2159 lines.
- Static editor UI is authored as `.tscn` under `editor/ui/`, one scene per
  panel. Build nodes in code only for genuinely dynamic children (palette
  entries, list rows).
- One undo stack for every mode (`MapEditorHistory`), deliberately unlike the
  building editor's per-mode decor stack. Terrain commands delegate to
  `TerrainService`'s own delta stack rather than copying it.
- `MapDocument` carries the sections this build does not interpret (rules,
  markers, placements…) and writes them back untouched. Do not drop unknown keys
  on save — a phase-1 editor must not eat the rules of a phase-5 map.
- Never write a map package non-atomically. `MapDocumentService.save_map_to`
  stages into `.tmp` and swaps; a crash must leave the previous map intact.
- `tests/features/world/test_map_editor.gd` runs the real scene end to end. Unit
  tests over the brush and the format prove the parts; only that one proves the
  editor.

## Weather and lighting laboratory

Changes to weather, time of day, sky, stars, sun/moon, atmospheric effects, or
world lighting must start in `res://tools/weather_lab/weather_lab.tscn`, not in
the settlement bootstrap scene. The lab is the isolated visual integration
surface: it uses the production `SkyAndWeatherController`, cloud shader, rain,
and firefly effects with a fixed camera and calibration geometry.

- Make and inspect the relevant lab preset before wiring a visual change into
  gameplay. Use F1–F5 for interactive presets, or run
  `godot --path . res://tools/weather_lab/weather_lab.tscn -- --capture` to
  write the deterministic set of PNGs to `user://weather_lab/`.
- Agents that can inspect images must open the generated captures after visual
  changes. Do not rely only on a successful GDScript parse for visual work.
- Use the lab's fixed `CloudCamera` (key `2`) for cloud work, alongside the
  `ContextCamera` (key `1`) to ensure the same change still works over the
  settlement. `ZenithCamera` (`3`) exposes tiling/stars and `HorizonCamera`
  (`4`) exposes atmospheric perspective. Cloud batch presets are captured with
  `--capture` as `cloud_noon`, `cloud_sunset`, and `cloud_storm`.
- Keep deterministic time/forecast rules in `simulation/domain`; the lab and
  game both feed visual values into `world/presentation`. Do not make a weather
  feature depend on `SettlementGame` to render it.
- Add or update a named lab preset whenever a weather/lighting change needs a
  repeatable visual case (for example a new moon, storm, or seasonal sky).
