# Go To Happyness

Godot 4.6 settlement simulation prototype.

## Run

1. Install the optional voxel extension with `./install_voxel.sh`.
2. Open `project.godot` in Godot 4.6.
3. Run the `SettlementPrototype` main scene at `game/bootstrap/settlement_game.tscn`.

The voxel extension is intentionally ignored by Git because it contains large platform binaries.

## Project layout

- `game/bootstrap/` contains the main scene and its composition root.
- `game/features/<feature>/domain/` contains rules and state without scene or UI concerns.
- `game/features/<feature>/application/` coordinates gameplay use cases and services.
- `game/features/<feature>/presentation/` contains Godot nodes, procedural visuals and scene-facing actors.
- `addons/goap/` is a vendored editor/runtime dependency; keep game-specific behavior outside it.

See [docs/architecture.md](docs/architecture.md) before adding a gameplay system.

## Checks

Run the deterministic domain checks with:

```sh
godot --headless --path . --script res://tests/test_domain.gd
```
