# Citizen AI Architecture (GOAP removal + native planner)

Status: **native foundation implemented and connected in shadow mode**. The new
runtime is live, but its goal catalog and order-provider catalog are intentionally
empty. The vendored `addons/goap` brain remains the behavior owner only until
gameplay tasks are migrated in the next phase.

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

Composites (each ~10–15 lines, written once, reused forever) — **implemented**:

- `SequenceStep(children)` — run in order; fail fast; SUCCESS when all succeed.
- `SelectorStep(children)` — first child that doesn't FAIL wins (fallbacks).
- `ParallelStep(children, ALL|ANY)` — run children together; SUCCESS on all (ALL)
  or the first (ANY), cancelling the rest.

Leaf steps (`WalkTo`, `WorkAt`, `PickUp`, `Deposit`, `Wait`, …) are **not written
yet**: they arrive with their owning mechanic in phase two, because each one pins
down a verb on the actuator and we only add verbs we actually use.

**Interruption is runner-level, not a Parallel guard.** When a higher-utility goal
wins mid-task, `BehaviorRunner` *suspends* the current resumable task onto a stack,
runs the interrupt, and *resumes* the prior task when it finishes — the whole
suspend/resume/cancel lifecycle lives on `BehaviorStep`. This is cleaner than a
magic guard child: any goal can pre-empt any other, and a resumed task first
re-checks its optional `guard(context)` — if the world moved on (target claimed,
order expired, tree felled) the stale task is dropped and the arbiter rebuilds.

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

**Failure cooldown.** When a task ends in FAILURE the brain marks its goal on a
short, decaying cooldown in the blackboard; the arbiter dampens that goal's utility
until the window elapses. This kills the tight fail-rebuild-fail loop the old GOAP
idle behavior suffered, while a genuinely rising need (starvation) still overtakes
the penalty and wins — nothing is permanently suppressed.

**Reservations.** Directors allocate work globally, but two citizens can still race
for the same physical target (one tree, one workbench slot, one unit of cargo). A
shared `ReservationLedger` — the single mutable reference on the otherwise-immutable
snapshot — lets a goal score "is this free for me?" and a Step `claim`/`release` it.
Claims carry a TTL so an abandoned task never wedges a target, and are dropped
automatically when a citizen unregisters.

`WorldSnapshot` is the grown-up `CitizenDecisionContext`: a pure data struct built
once per think-tick by the Sensor from the facade. All goal scoring and the whole
`WorkforcePolicy` run on it → **headless testable, deterministic**.

---

## 6. Killing the god-object coupling: typed façades

Today `CitizenGoapBrain` and `WorkforceCoordinator` call dozens of
`simulation._private()` methods on a 6589-line `Node` typed as `Node` (no type
safety). We introduce two narrow, typed seams:

- **`AIWorldFacade`** (read side): captures a coherent `WorldSnapshot`. The
  connected adapter currently exposes identity, position, time and settlement
  identity only. Each migrated mechanic adds its owned facts to this boundary;
  goals never reach through to `simulation._private()` methods. Citizen identity in
  the snapshot is a stable, settlement-issued `ai_id` (a monotonic counter), **not**
  `get_instance_id()` — so orders, reservations and blackboard memory keep referring
  to the same citizen across save/load and stay deterministic for headless tests.
- **`CitizenActuator`** (write side): the verbs a Step may perform on a citizen —
  movement plus mechanic-level actions. Phase one uses a
  `ShadowCitizenActuator` that cannot issue commands. We will implement new verbs
  as tasks migrate rather than wrap old FSM setters.

Result: the AI layer depends on **two small interfaces**, not the god-object. This
also makes the eventual `settlement_game.gd` breakup safe — the AI won't shatter
when it moves.

---

## 7. Target file layout

```
game/features/decision/
  domain/                         # pure, RefCounted, headless
    ai_fact_set.gd                # immutable namespaced extension facts
    reservation_ledger.gd         # shared claims on contested targets (TTL'd)
    citizen_snapshot.gd
    world_snapshot.gd             # coherent facts for one think cycle
    citizen_order.gd              # Director → Brain assignment payload
    ai_blackboard.gd              # per-citizen decision memory + goal cooldowns
    citizen_goal.gd               # AICitizenGoal: score() / build_task()
    workforce_policy.gd           # UNCHANGED — role scoring stays
    behavior/
      behavior_context.gd
      behavior_step.gd            # lifecycle + Status contract
      behavior_task.gd
      sequence_step.gd
      selector_step.gd
      parallel_step.gd
    goals/                        # intentionally empty until phase two
  application/
    citizen_ai_system.gd          # lifecycle, snapshots and bounded think budget
    citizen_brain.gd
    behavior_runner.gd            # task pre-emption and resume stack
    utility_arbiter.gd            # scoring, hysteresis, deterministic ties
    order_board.gd                # competing director proposals
    order_provider.gd
    settlement_director.gd
    world_facade.gd
    settlement_ai_world_facade.gd
    citizen_actuator.gd
    shadow_citizen_actuator.gd

addons/goap/                      # deleted after migrated tasks own behavior
```

---

## 8. Migration — connected foundation, then vertical slices

**Phase 1 — Complete native foundation in shadow mode — DONE.**
- All domain primitives, composites, utility arbitration, interruption/resume,
  order reconciliation, director, per-citizen brains and scalable runtime
  scheduling exist now.
- `SettlementGame` owns a live `CitizenAISystem`. Citizens are registered and
  unregistered with scene lifetime, snapshots are captured, and brains tick.
- Goal and provider catalogs are empty. The shadow actuator rejects writes, so
  this phase has no gameplay behavior and cannot compete with GOAP.
- `tests/test_ai.gd` covers the pure runtime; the startup smoke test verifies the
  live system and one brain per resident.

**Phase 2 — Migrate gameplay as owned vertical slices.**
- Add task-specific snapshot facts and actuator verbs from the mechanic that owns
  them. Do not add generic access to `SettlementGame` and do not wrap FSM states.
- Add the concrete Goal, Steps and (where global allocation is needed)
  `OrderProvider` for one complete scenario.
- Switch that scenario to the native owner, test it, then delete its old scheduler
  and `_process_*` arms immediately. There is never dual write ownership.
- Start with personal needs and the basic gather/deposit loop, then move
  forestry, farming, construction, services and logistics.

**Phase 3 — Native ownership and legacy deletion.**
- Once all top-level needs and work assignment run natively, remove
  `CitizenGoapBrain`, `WorkforceCoordinator`, the GOAP plugin and addon.
- Delete the remaining citizen behavior FSM arms. Keep `Citizen` focused on
  movement, animation and actuator-level execution.

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

- **Domain stays pure** → `tests/test_ai.gd`: goal scoring (utility ordering,
  hysteresis, failure cooldown), `WorldSnapshot`/fact construction, Step composites
  (Sequence fail-fast, Selector fallback, Parallel ANY), runner interrupt/resume,
  stale-task drop on resume, order reconciliation, and the `ReservationLedger`
  (claim/deny/re-affirm/wrong-owner-release/expiry) with a fake actuator. All
  headless, deterministic, no scene.
- `WorkforcePolicy` tests unchanged (it doesn't move).
- Each migration phase must keep `godot --headless --script res://tests/test_domain.gd`
  green before merge.

---

## 11. Risks & mitigations

- **Dual ownership during migration.** Mitigation: shadow mode cannot write. In
  phase two, switch and delete each vertical slice together; never let two
  schedulers command the same scenario.
- **Utility tuning regressions.** Mitigation: define continuous curves from the
  simulation's intended needs and cover their crossing points in `test_ai.gd`.
- **Actuator surface creep.** Keep it to verbs actually used; grow per phase, don't
  pre-model all 55 states.
- **Scope temptation.** God-object breakup is *enabled* by the facade but is out of
  scope for this plan — do not couple the two efforts.
