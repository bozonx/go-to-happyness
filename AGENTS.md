# Agent Guide

This document contains the essential context for AI assistants working on **Go To Happyness**, a Godot 4.6 settlement-simulation prototype.

## Project basics

- Engine: **Godot 4.7**, Forward Plus renderer, **Jolt Physics** for 3D.
- Main scene: `game/bootstrap/settlement_game.tscn`.
- Optional voxel extension: install with `./install_voxel.sh`. It is Git-ignored because it contains large platform binaries.
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
- `routing`: navigation grid, route selection, route results.

## Key rules

1. Add code to the feature that owns the behavior, not to generic `utils`, `helpers`, or `managers` folders.
2. Keep one source of truth. UI reads view models or query results; it never mutates settlement state directly.
3. Prefer typed records (`ConstructionSite`, `TradeOrder`, `ResourcePile`, `SawmillStock`) over ad hoc dictionaries.
4. Use `StringName` or constants for stable IDs. Do not use runtime `ObjectID` as saved or cross-system identity.
5. Keep service dependencies narrow. Inject the specific state, registry, or callable a service needs.
6. Emit typed gameplay events at feature boundaries. UI formatting and colours belong in a future UI feature.

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

### Deterministic domain tests

```sh
godot --headless --path . --script res://tests/test_domain.gd
godot --headless --path . --script res://tests/test_ai.gd
godot --headless --path . --script res://tests/test_navigation_performance.gd
```

These tests extend `SceneTree`, run in `_init()`, call `quit(0)`, and do not `await` frame events.

### Scene smoke tests (require frame processing)

```sh
godot --headless --path . --script res://tests/test_startup.gd --quit-after 300
godot --headless --path . --script res://tests/test_materials_yard.gd --quit-after 300
```

### Why scene tests need `--quit-after`

Tests that instantiate the main scene use `await process_frame` / `await physics_frame` to let the scene settle. In headless mode with `--script`, Godot only advances the main loop when the engine knows when to stop. Without `--quit-after`, the process suspends on the first awaited frame and never resumes, appearing to hang.

Adding `--quit-after <frames>` tells the engine to run the loop for a bounded number of frames, so awaited frame signals resolve and the script reaches `quit(0)`.

### Recommended test runner

Wrap tests in `timeout` to avoid runaway hangs during experimentation:

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

run_test res://tests/test_domain.gd
run_test res://tests/test_ai.gd
run_test res://tests/test_navigation_performance.gd
run_test res://tests/test_startup.gd 300
run_test res://tests/test_materials_yard.gd 300
```

Use a frame budget generous enough for the slowest machine running CI; 300 frames is enough for the current smoke tests.

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
