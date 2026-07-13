# Citizen AI Architecture (GOAP removal + native planner)

Status: **design / target architecture**. Supersedes the vendored `addons/goap`
brain. Bold end-state is described first; a safe migration path follows so we can
land it in phases without freezing the game.

---

## 1. Why we are replacing GOAP

The GOAP layer is **degenerate**: 3 goals map 1:1 onto 3 effect-only actions with
**no preconditions**, so the planner never chains — every "plan" is a single
action. It is a priority `switch` wearing a 450-line planner + editor debugger.
Meanwhile the real intelligence (role scoring, workplace choice, scarcity, era
rules) lives entirely **outside** GOAP in `WorkforcePolicy`, `WorkforceCoordinator`
and the `settlement_game.gd` god-object. GOAP adds indirection and bugs (dict
mutation during iteration, `set_meta` lifecycle hacks, exponential plan expansion)
for **zero** planning value.

We build our own, because our behavior is **scripted sequences + data scoring**,
not emergent search. That is exactly what a small utility-arbiter + behavior-tree
does best — and we already write all of it by hand anyway.

---

## 2. Design goals

1. **No external AI dependency.** Delete `addons/goap` entirely.
2. **One owner per decision.** Global scheduling vs. local behavior clearly split.
3. **Extensible by addition.** A new scenario = add one Goal class + one Task.
   No edits to the arbiter or the runner.
4. **Headless-testable core.** Selection and scoring run on plain data
   (`RefCounted`), no scene nodes — keeps `tests/test_domain.gd` green and cheap.
5. **Typed boundaries.** Kill `simulation._private()` coupling behind a facade.
6. **Interruptible, composable behavior.** Toilet break / meal / danger can
   pre-empt the current task and resume it — first-class, not special-cased.

---

## 3. The layered model

```
            ┌────────────────────────────────────────────────┐
            │ SettlementDirector  (global, one per world)     │
            │  · vacancies, hiring, scarcity, era rules       │
            │  · emits Orders to citizens (role + workplace)  │
            └───────────────┬────────────────────────────────┘
                            │ Order (data)
                            ▼
   Sensors ─► WorldSnapshot (facts) ─► CitizenBrain (local, per citizen)
                                          │
                       ┌──────────────────┴───────────────────┐
                       │ Arbiter: utility scoring over Goals   │
                       │   Sleep / Eat / Toilet / Work / Relax │
                       └──────────────────┬───────────────────┘
                                          │ winning Goal.build_task()
                                          ▼
                              BehaviorRunner ticks a Task
                                          │
                       Task = micro behavior tree of Steps
                       (Sequence / Selector / Parallel / leaf)
                                          │
                             Steps drive the Citizen via
                             CitizenActuator (typed façade)
```

Two brains, two responsibilities:

| Brain | Scope | Owns | Runs |
|-------|-------|------|------|
| **SettlementDirector** | whole settlement | who is hired, which role fills which vacancy, global scarcity, registration | on a slow global tick (replaces `WorkforceCoordinator.update_workers`) |
| **CitizenBrain** | one citizen | personal need arbitration (sleep/eat/toilet vs. the assigned order), running the active Task | per-citizen tick (replaces `CitizenGoapBrain`) |

The Director **proposes** (an `Order`: role + workplace + payload). The Brain
**disposes** — it may override the order when a higher-utility personal need wins
(hungry, night, toilet). This is the split GOAP muddled by having the coordinator
poke world-state flags into per-citizen agents.

---

## 4. The native behavior primitive (our own micro-BT)

A **Task** is a tree of **Steps**. One Step contract, ~1 enum, no library:

```gdscript
# domain/behavior/step.gd  — pure logic, no scene node
class_name Step extends RefCounted
enum Status { RUNNING, SUCCESS, FAILURE }

func tick(ctx: BehaviorContext, delta: float) -> Status:  # override
    return Status.SUCCESS
func reset() -> void: pass          # called when re-entered after interruption
```

Composites (each ~10–15 lines, written once, reused forever):

- `Sequence(steps)` — run in order; fail fast; SUCCESS when all succeed.
- `Selector(steps)` — first child that doesn't FAIL wins (fallbacks).
- `Parallel(main, guards)` — run `main`; if a guard fires, pre-empt + resume.
- Leaves: `WalkTo(target)`, `WorkAt(workplace, duration)`, `PickUp(resource)`,
  `Deposit(warehouse)`, `Wait(seconds)`, `PlayState(fsm_state)` (migration bridge).

A whole scenario becomes declarative data-ish composition:

```gdscript
# "gather branches" — the entire behavior, no new engine code
Sequence([
    WalkTo(tree_access),
    WorkAt(tree, chop_time),
    PickUp("branches"),
    WalkTo(materials_yard),
    Deposit(yard),
])
```

**This is the extensibility promise.** Complex future scenarios (multi-stop
supply runs, cooperative building, hauling chains) are new Step compositions, not
new `match state` arms. Interruption (`Parallel` with a `NeedsToilet` guard) is
built in, so we stop special-casing 7 toilet states in every tick.

`BehaviorContext` carries the `CitizenActuator` (typed handle to move/animate/act
on the citizen), the current `WorldSnapshot`, and the active `Order`.

Why not a BT library? Same reason as GOAP: the primitive is ~80 lines total, we
want zero black-box execution, full determinism for headless tests, and no
editor-plugin baggage. If we ever want visual editing, we own the tree and can add
a debugger later on our terms.

---

## 5. Utility arbitration (replaces GOAP goal priority)

Each top-level need is a **Goal** class:

```gdscript
# domain/goals/goal.gd
class_name Goal extends RefCounted
func score(s: WorldSnapshot) -> float:  return 0.0    # 0 = inapplicable
func build_task(s: WorldSnapshot, order: Order) -> Step:  return null
```

The Arbiter is trivial and **never changes** as goals are added:

```gdscript
func choose(snapshot) -> Goal:
    var best: Goal = null; var best_score := 0.0
    for g in goals:
        var v := g.score(snapshot)
        if v > best_score: best = g; best_score = v
    return best
```

Scores are **continuous utility**, not fixed priority integers — this is the
upgrade over the current 100/80/10 switch. Examples:

- `SleepGoal.score` ramps with tiredness + how far past shift-end it is.
- `EatGoal.score` ramps with hunger; spikes when a meal is requested.
- `WorkGoal.score` is a modest baseline (the Director's order gives it substance).
- Future `RelaxGoal`, `FleeGoal`, `SocializeGoal` slot in by adding a file.

Hysteresis (avoid flip-flopping between two near-equal goals) lives in the Arbiter
as a small "stickiness" bonus for the currently-running goal — one place, not
scattered.

`WorldSnapshot` is the grown-up `CitizenDecisionContext`: a pure data struct built
once per think-tick by the Sensor from the facade. All goal scoring and the whole
`WorkforcePolicy` run on it → **headless testable, deterministic**.

---

## 6. Killing the god-object coupling: typed façades

Today `CitizenGoapBrain` and `WorkforceCoordinator` call dozens of
`simulation._private()` methods on a 6589-line `Node` typed as `Node` (no type
safety). We introduce two narrow, typed seams:

- **`WorldFacade`** (read side): everything the Sensor needs to build a
  `WorldSnapshot` — canteen position, work-time, storage room, vacancies. One
  typed interface; `SettlementGame` implements it. Snapshot-building no longer
  reaches into privates.
- **`CitizenActuator`** (write side): the verbs a Step may perform on a citizen —
  `walk_to`, `work_at`, `pick_up`, `deposit`, `go_home`, `is_arrived`. Wraps the
  existing FSM setters during migration, then absorbs them.

Result: the AI layer depends on **two small interfaces**, not the god-object. This
also makes the eventual `settlement_game.gd` breakup safe — the AI won't shatter
when it moves.

---

## 7. Target file layout

```
game/features/decision/
  domain/                         # pure, RefCounted, headless
    world_snapshot.gd             # facts (grown CitizenDecisionContext)
    order.gd                      # Director → Brain assignment payload
    workforce_policy.gd           # UNCHANGED — role scoring stays
    goals/
      goal.gd                     # base: score() / build_task()
      sleep_goal.gd
      eat_goal.gd
      toilet_goal.gd
      work_goal.gd
      (relax_goal.gd, flee_goal.gd … future)
    behavior/
      step.gd                     # Status enum + contract
      sequence.gd  selector.gd  parallel.gd
      leaves/ walk_to.gd work_at.gd pick_up.gd deposit.gd wait.gd
      legacy_fsm_step.gd          # migration bridge (see §8)
  application/
    citizen_brain.gd              # replaces citizen_goap_brain.gd
    behavior_runner.gd            # ticks the active Task tree
    arbiter.gd                    # utility selection over goals
    settlement_director.gd        # replaces/renames workforce_coordinator.gd
    world_facade.gd               # typed read seam over SettlementGame
    citizen_actuator.gd           # typed write seam over Citizen

addons/goap/                      # DELETED
```

---

## 8. Migration — bold end-state, safe path

We do **not** rewrite 55 FSM states before the game runs again. Four phases; the
game is playable after each.

**Phase 0 — Scaffolding (no behavior change).**
Add `WorldFacade` + `CitizenActuator` interfaces implemented by pass-through to
today's `simulation._x()` / `citizen.setter()`. Add `WorldSnapshot`, `Order`, the
`Step`/composites, `Arbiter`, `BehaviorRunner`. Nothing wired yet. Tests still green.

**Phase 1 — Swap the brain, keep the FSM (the GOAP removal).**
- `CitizenBrain` replaces `CitizenGoapBrain`. Goals: Sleep/Eat/Work as today, but
  as `Goal.score()` utility classes reading `WorldSnapshot`.
- Each goal's `build_task()` returns a **`LegacyFsmStep`**: it calls the existing
  actuator verb (`go_home`, `go_to_canteen`, assign work) and reports SUCCESS when
  the citizen reaches the matching FSM state — i.e. *exactly what GOAP's
  `is_intent_complete` does now*, minus the addon.
- Delete `addons/goap`, `citizen_goap_brain.gd`, GOAP debugger wiring.
- **Net:** identical behavior, native code, one brain, typed seams. This is the
  commit that removes GOAP.

**Phase 2 — Real Steps for the common loops.**
Peel the highest-traffic FSM chains (gather / forestry / farming / deliver) out of
`citizen_actor`'s `match state` into composed `Sequence` Tasks driven through the
actuator. `WorkGoal.build_task` now returns real trees. FSM handlers for migrated
states are deleted as they are replaced. Toilet/meal become `Parallel` guards, so
the 7-state interrupt special-casing disappears.

**Phase 3 — Director cleanup + god-object seam.**
Rename/refactor `WorkforceCoordinator` → `SettlementDirector`; it now emits typed
`Order`s instead of poking flags + calling `_agent.process(0.0)`. Remove the
double-scheduler dance (`request_decision`/`request_goap_decision`). Route all its
`simulation._x()` calls through `WorldFacade`.

End-state: `citizen_actor.gd` shrinks to movement + animation + actuator verbs;
all "what/why" lives in goals+tasks; all "who works where" in Director+Policy;
zero private-method reach-through.

---

## 9. What gets deleted

- `addons/goap/**` (runtime + debugger + plugin) and the `enabled_plugins` entry.
- `game/features/decision/application/citizen_goap_brain.gd`.
- GOAP `set_meta("_entered")` lifecycle, `has_method` duck-typing, `_agent.process`
  re-entrancy, the `assigned/fed/resting` world-state flag poking.
- Eventually: the migrated `_process_*` FSM arms in `citizen_actor.gd`.

---

## 10. Testing strategy

- **Domain stays pure** → new `tests/test_ai.gd`: goal scoring (utility ordering,
  hysteresis), `WorldSnapshot` construction from a fake facade, and Step composites
  (Sequence fail-fast, Selector fallback, Parallel pre-empt/resume) with a fake
  actuator. All headless, deterministic, no scene.
- `WorkforcePolicy` tests unchanged (it doesn't move).
- Each migration phase must keep `godot --headless --script res://tests/test_domain.gd`
  green before merge.

---

## 11. Risks & mitigations

- **Behavior drift during Phase 1.** Mitigation: `LegacyFsmStep` reproduces
  `is_intent_complete` verbatim; behavior is byte-for-byte the old brain minus the
  planner. Diff is mechanical.
- **Utility tuning regressions.** Mitigation: seed goal scores to reproduce the old
  100/80/10 ordering exactly on day one; only introduce continuous ramps once
  covered by `test_ai.gd`.
- **Actuator surface creep.** Keep it to verbs actually used; grow per phase, don't
  pre-model all 55 states.
- **Scope temptation.** God-object breakup is *enabled* by the facade but is out of
  scope for this plan — do not couple the two efforts.
```
