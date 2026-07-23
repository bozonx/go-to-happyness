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
