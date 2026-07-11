# Go To Happyness

Godot 4.6 settlement simulation prototype.

## Run

1. Install the optional voxel extension with `./install_voxel.sh`.
2. Open `project.godot` in Godot 4.6.
3. Run the `SettlementPrototype` main scene.

The voxel extension is intentionally ignored by Git because it contains large platform binaries.

## Project layout

- `scenes/` contains composition-only entry scenes.
- `scripts/domain/` contains immutable gameplay definitions and rules.
- `scripts/services/` contains game orchestration services.
- `scripts/` contains scene controllers and actors.
- `addons/goap/` is a vendored editor/runtime dependency; keep game-specific behavior outside it.

See [docs/architecture.md](docs/architecture.md) before adding a gameplay system.

## Checks

Run the deterministic domain checks with:

```sh
godot --headless --path . --script res://tests/test_domain.gd
```
