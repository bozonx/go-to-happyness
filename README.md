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
- Citizen decisions use the native `decision` feature; there is no GOAP runtime or editor dependency.

See [docs/architecture.md](docs/architecture.md) and
[design_docs/citizen_ai.md](design_docs/citizen_ai.md) before adding AI behavior.

## Checks

Run the deterministic domain checks with:

```sh
# Deterministic domain tests
godot --headless --path . --script res://tests/test_domain.gd
godot --headless --path . --script res://tests/test_ai.gd
godot --headless --path . --script res://tests/test_navigation_performance.gd

# Scene smoke tests (need a frame budget so awaited frames resolve in headless mode)
godot --headless --path . --script res://tests/test_startup.gd --quit-after 300
godot --headless --path . --script res://tests/test_materials_yard.gd --quit-after 300
```

`test_ai.gd` covers the native AI runtime without a gameplay scene. `test_startup.gd`
and `test_materials_yard.gd` are integration smoke tests and may print known
dummy-renderer diagnostics in headless mode; their exit status remains authoritative.
Without `--quit-after`, scene tests that `await process_frame` / `await physics_frame`
hang because the headless main loop does not know when to stop.

## Tent Era Survival

The Tent Era implements the following systems:

- New `tarp` resource with a straw/tarp building branch (tents, forager tents, materials yards, craft tents, trade tents, warehouses, toilets).
- Research tree: `straw_tents` -> `tarp_tents` -> `trade` -> `tarp_trade_tent`, with `earth_buildings` and campfire upgrades alongside.
- Entrance sign trading: buy food, water, construction gloves, and buckets.
- Bucket-based water gathering from ponds; the obsolete water `filter_1` tool has been removed.
- Nightly campfire stories with three themes: optimistic wellbeing boost, teaching skill gain, and a focused work plan.
- Daily survival decisions: wet firewood protection, unknown forest berries, and wandering traveler barter.
- Weather-driven rain decay on exposed resources, fire extinguishing, and smoke debuffs from wet firewood.
- Temporary 4-person tent that auto-dismantles at dawn and a starting tarp dilemma (dew collector vs. warehouse cover).
