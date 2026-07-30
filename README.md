# Go To Happyness

Godot 4.7 settlement simulation prototype.

## Run

1. Open `project.godot` in Godot 4.7.
2. Run the project. It boots the main menu
   (`game/features/ui/presentation/main_menu/main_menu.tscn`), which launches the
   gameplay runtime `game/bootstrap/game_runtime.tscn` through `GameLaunchManager`.

## Checks

```sh
# Everything: import + unit suites + every scene test
./scripts/run_tests.sh

# Domain and native AI rules only, no gameplay scene
godot --headless --path . --script res://tests/run_all.gd

# One feature test (scene tests need a frame budget so awaited frames resolve)
godot --headless --path . --script res://tests/features/simulation/test_startup.gd --quit-after 300
```

Without `--quit-after`, scene tests that `await process_frame` / `await physics_frame`
hang because the headless main loop does not know when to stop. Scene tests may print
known dummy-renderer diagnostics in headless mode; their exit status is authoritative.

## Project layout

- `game/bootstrap/` — the main scene and its composition root.
- `game/features/<feature>/{domain,application,presentation}/` — rules, use cases and
  Godot-facing code, kept close to the feature that owns them.
- `game/content/` — authored content packs (`pack.json`, `*.gdbuilding.json`, `*.gdmap/`).
- `tools/` — the terrain, weather and building laboratories.
- `tests/` — `domain/`, `ai/`, `features/`, plus print-only diagnostics in `repro/`.

## Documentation

| Where | What |
| --- | --- |
| [AGENTS.md](AGENTS.md) | How to work in this repo: conventions, tests, labs, pitfalls. |
| [docs/architecture.md](docs/architecture.md) | Layers, feature ownership, rules for new code. **Read before adding code.** |
| [docs/gameplay.md](docs/gameplay.md) | What the build does today: controls, storage, Tent Era systems. |
| [design_docs/](design_docs/README.md) | What to build: engine specs, citizen systems, settlement design. |

Two conventions worth knowing before writing code:

- `ResourceIds` (`game/features/settlement/domain/resource_ids.gd`) is the single source
  of truth for resource `StringName` constants, era-scoped resource lists and storage
  weights. Use the constants, not raw string literals.
- `BuildingRuntimeState` (`game/features/buildings/domain/building_runtime_state.gd`)
  gives typed access to building node metadata via `BuildingRecord.runtime_state()`.
  Use it instead of raw `get_meta` / `set_meta`.

## Main menu

The main menu is the host game library. It lists every installed game definition
on equal terms — built-in games (📦) and user-created games (🎮) appear in the same
picker. Each game shows its description, and the selected map displays a preview
image when available.

- **F6** — load quicksave (if one exists).
- **F12** — open the Editor Hub in dev mode (only when running from the Godot editor).
- **💾 Сохранения** — open the save manager to load or delete save files.

## Dev mode

Running any editor scene directly from Godot (F5 on `map_editor.tscn`,
`building_editor.tscn`) enters dev mode automatically, writing to
`res://game/content/core`. F12 from the main menu opens the Editor Hub in dev mode
with the core pack exposed as a writable project.
