# Go To Happyness

Godot 4.7 settlement simulation prototype.

## Run

1. Open `project.godot` in Godot 4.7.
2. Run the `SettlementPrototype` main scene at `game/bootstrap/settlement_game.tscn`.

## Project layout

- `game/bootstrap/` contains the main scene and its composition root.
- `game/features/<feature>/domain/` contains rules and state without scene or UI concerns.
- `game/features/<feature>/application/` coordinates gameplay use cases and services.
- `game/features/<feature>/presentation/` contains Godot nodes, procedural visuals and scene-facing actors.
- Citizen decisions use the native `decision` feature; there is no GOAP runtime or editor dependency.
- `ResourceIds` (`game/features/settlement/domain/resource_ids.gd`) is the single source of truth for resource `StringName` constants, era-scoped resource lists, and storage weights. Use these constants instead of raw string literals.
- `BuildingRuntimeState` (`game/features/buildings/domain/building_runtime_state.gd`) provides typed access to building node metadata (condition, repair, accepting_workers, service_position, etc.) via `BuildingRecord.runtime_state()`. New code should use this instead of raw `get_meta`/`set_meta` calls.

See [docs/architecture.md](docs/architecture.md),
[design_docs/core/citizen_ai.md](design_docs/core/citizen_ai.md), and
[design_docs/core/navigation_and_roads.md](design_docs/core/navigation_and_roads.md)
before changing AI or navigation behavior.

## Checks

Run the deterministic domain checks with:

```sh
# Deterministic domain tests
godot --headless --path . --script res://tests/test_domain.gd
godot --headless --path . --script res://tests/test_ai.gd
godot --headless --path . --script res://tests/test_navigation_performance.gd
godot --headless --path . --script res://tests/test_events.gd

# Scene smoke tests (need a frame budget so awaited frames resolve in headless mode)
godot --headless --path . --script res://tests/test_startup.gd --quit-after 300
godot --headless --path . --script res://tests/test_materials_yard.gd --quit-after 300
godot --headless --path . --script res://tests/test_toilet_needs.gd --quit-after 300
```

`test_ai.gd` covers the native AI runtime without a gameplay scene. `test_startup.gd`
and `test_materials_yard.gd` are integration smoke tests and may print known
dummy-renderer diagnostics in headless mode; their exit status remains authoritative.
Without `--quit-after`, scene tests that `await process_frame` / `await physics_frame`
hang because the headless main loop does not know when to stop.

## First-person controls

Press `R` to switch between the hero overview and first-person view.

- `WASD` / arrows — move.
- `Space` — jump, `Shift` — sprint.
- `Mouse` — look around.
- `F` — perform one context action.
- `Shift+F` — perform the "all" version of the action (deliver everything, gather until pocket is full, etc.).
- `B` — open construction menu (works in overview and first-person; first-person requires the hero).
- `T` — drop all pocket contents at your feet as a ground pile (first-person).
- `RMB` — dig terrain (hero only); for other citizens it returns to overview.

The hero has an 8-slot pocket that can hold any mix of resources. Gathered items go
into the pocket first and can be delivered to the sawmill or warehouse. After the
pocket is empty at a warehouse, `F` opens a menu to take goods back into the pocket.
Only the hero can gather, deliver, or occupy workplace jobs from first-person mode.
Other citizens can be controlled only for movement (observation / rescue).

## Storage & Logistics

- **Backpack**: Before the first warehouse is built, resources live in a virtual starter backpack shown separately in the HUD. The backpack never decays, cannot receive new resources after the start, and its consumables (food, water, construction gloves) are used directly by the settlement.
- **Migration**: Building the first warehouse automatically moves backpack contents into the new warehouse.
- **Ground piles**: Dropped resources form piles on the ground. They decay daily based on type and weather:
  - Biological (food, grass, branches, logs, wood, hides): 5% per day, 10% while raining.
  - Crafted (goods, boards, tarp): 3% per day only while raining.
  - Inert (stone, clay, bricks, soil): no decay.
  - Water: evaporates 5% per day on non-rain days.
- **Balanced warehouse mode**: In the campfire orders menu you can enable balanced storage, which spreads each resource evenly across warehouses by fill percentage instead of always filling the nearest one.
- **Daily Courier order**: In the daily orders menu, assign a citizen as a Courier for the day. They will move ground piles (and backpack leftovers if any) into the warehouse.
- **Warehouse reservation**: When a courier is assigned to move resources to a warehouse, the destination room is reserved immediately so another delivery cannot steal the space before arrival.
- **Construction sites**: You can place a building even if you do not have all required resources. The missing resources are shown in red in the construction menu. Available resources are reserved for the site, couriers transport them from warehouses, and builders can start working as soon as the first materials arrive. Construction pauses when it catches up to the delivered resources and resumes when more arrive.
- **FPP storage interaction**: In first-person mode, stand next to a warehouse and press `F` to deposit one pocket item or `Shift+F` to deposit everything. With an empty pocket, `F` opens a menu to take goods from the warehouse.

## Cheats

- `Ctrl+F` grants extra resources, but only after the first warehouse has been built.
- Money cheat adds virtual currency directly and is not restricted.

## Tent Era Survival

The Tent Era implements the following systems:

- New `tarp` resource with a straw/tarp building branch (tents, forager tents, materials yards, craft tents, trade tents, warehouses, toilets).
- Research tree: `straw_tents` -> `tarp_tents` -> `trade` -> `tarp_trade_tent`, with `earth_buildings` and campfire upgrades alongside.
- Entrance sign trading: buy food, water, construction gloves, and buckets.
- Bucket-based water gathering from ponds; the obsolete water `filter_1` tool has been removed.
- Nightly campfire stories with three themes: optimistic wellbeing boost, teaching skill gain, and a focused work plan.
- Data-driven random event system with 12 tent-era events: conditions, cooldowns, event chains (forest ranger -> wild boars), delayed consequences (smoky firewood), and random chance outcomes. See `design_docs/event_system.md` for architecture.
- Weather-driven rain decay on exposed resources, fire extinguishing, and smoke debuffs from wet firewood.
- Temporary 4-person tent that auto-dismantles at dawn and a starting tarp dilemma (dew collector vs. warehouse cover).
