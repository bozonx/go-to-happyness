# Gameplay reference

What the build currently does, from the player's side: controls, storage rules
and the systems the Tent Era ships with. This describes the **implemented**
behaviour — the intended design lives in `design_docs/`, and where the two
disagree, the design doc is the target and this file is the fact.

## First-person controls

Movement, jump, sprint and look use the usual bindings; the rest of the mode runs on
two context actions and a few mode switches:

- switch between the hero overview and first-person view;
- context action — perform one applicable action at the crosshair;
- full context action — the "all" version (deliver everything, gather until the pocket is full);
- open the construction menu (first-person requires the hero);
- drop all pocket contents at your feet as a ground pile;
- dig terrain (hero only).

Actual key bindings live in the input map, not in this document.

The hero has an 8-slot pocket that can hold any mix of resources. Gathered items go
into the pocket first and can be delivered to the sawmill or warehouse. After the
pocket is empty at a warehouse, `F` opens a menu to take goods back into the pocket.
Only the hero can gather, deliver, or occupy workplace jobs from first-person mode.
Other citizens can be controlled only for movement (observation / rescue).

Design: [design_docs/citizens/first_person_hero_control.md](../design_docs/citizens/first_person_hero_control.md).

## Storage & logistics

- **Backpack**: Before the first warehouse is built, resources live in a starter backpack shown separately in the HUD. It never decays, cannot receive new resources after the start, and its consumables (food, water) are used directly by the settlement. Today this is a virtual dictionary seeded from a `core:starter_backpack` entity on the map; the target model replaces both with an ordinary container entity tagged `core:party_stash`, so a chest or a cart works the same way (`design_docs/engine/map_start.md` §6.5).
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

Design: [design_docs/settlement/storage_warehouses.md](../design_docs/settlement/storage_warehouses.md).

## Cheats

- `Ctrl+F` grants extra resources, but only after the first warehouse has been built.
- Money cheat adds virtual currency directly and is not restricted.

## Tent Era

The Tent Era ships with these systems:

- New `tarp` resource with a straw/tarp building branch (tents, forager tents, materials yards, craft tents, trade tents, warehouses, toilets).
- Research tree: `straw_tents` -> `tarp_tents` -> `trade` -> `tarp_trade_tent`, with `earth_buildings` and campfire upgrades alongside.
- Entrance sign trading: buy food, water, and buckets.
- Bucket-based water gathering from the bank of any fresh water on the map.
- Nightly campfire stories with three themes: optimistic wellbeing boost, teaching skill gain, and a focused work plan.
- Data-driven random event system with 12 tent-era events: conditions, cooldowns, event chains (forest ranger -> wild boars), delayed consequences (smoky firewood), and random chance outcomes.
- Weather-driven rain decay on exposed resources, fire extinguishing, and smoke debuffs from wet firewood.
- Temporary 4-person tent that auto-dismantles at dawn and a starting tarp dilemma (dew collector vs. warehouse cover).

Design: [design_docs/settlement/tent_era_survival.md](../design_docs/settlement/tent_era_survival.md)
and [design_docs/settlement/event_system.md](../design_docs/settlement/event_system.md).
