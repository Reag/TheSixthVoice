# Shared mechanics

Helpers used by more than one frame. Roadmap §4 is the registry; the rule there is that **a helper
is born with its first consumer**, in its own sub-folder, with its own specs — and its interface is
frozen the moment that sub-project ships, recorded in roadmap §4 and in memory
`sixth-voice-build-state`. A later frame that needs more extends the helper in its own sub-project,
with every earlier spec still green.

The shape is usually the Draugr's: a static-function script plus whatever `.tres` it needs, no
autoload, no `class_name`. Every consumer reaches it by `preload`. **Armor is the one family that
isn't**: see its row below — two `Buff` subclasses (one `TO.STATBLOCK`, one `TO.RESIST_DAMAGE`)
parameterised by `@export`s on each consumer's own `.tres`, not a static-function script at all.

**Why no `class_name`**: global class names are registered from `project.godot`'s class list, which
is built at startup — so a `class_name` declared in a script a mod loads at runtime is never
registered, and cannot be referenced by that name at all. (This is a different problem from Godot
#83542, which is why a `class_name` script in the *base game* cannot be reliably script-extended;
that one is why the engine has so many autoloads. Both end at the same advice, for different
reasons.)

Built, and the interface frozen when its sub-project shipped — listed in the order they became
shared families, which is not the order of the frames: Armor's code was born at frame 2 and only
became a family at the Myconid.

| Family | Born with | Interface | Consumers |
|---|---|---|---|
| Overshield | 4 Myconid, SP1 | `current` `has` `grant` `increase` `grit` | Sluagh, Hazard, Naga, Primrose, Black Mountain |
| Armor | 2 Fitzgerald, SP4 (promoted at 4 Myconid, SP2; the Fitzgerald's own `.tres` re-pointed at the frame close) | `buff_armor_statblock.gd` `armor_amount` + `buff_armor_reduction.gd` `reduction_amount` `damage_types` `until` — always applied as a PAIR, with matching `until` | Reinforcement Blast, Fungal Network, Uffish Gyre |
| Teleport | 5 Maiden's Blush, SP1 (observe/intercept) + SP2 (perform) | **Eleven, all frozen.** Observe/intercept: `is_teleport` `destination` `forcer` `movement_type` `is_own` `veto`, plus `OWN_TAG`. Perform: `candidate_tiles` `pathfinder` `pick_tile` `move` `move_along`. **The two move routes are not interchangeable** — `pathfinder` goes through `Pathfinder.create`, so Immobilized and every `MOVEMENT_RESTRICTION` ban apply (Abjuration wants that); `move` sends a hand-built single-step path and so builds no pathfinder at all, which is the only route that beats a ban (Step needs that). `move`/`move_along` run INLINE and hand the move core back, unlike Blinkspace which queues and returns. | Purple Thorn, Leoleth (ZIP), Sluagh (Hunt), Koremasa (Vanish), Six Sky |
| Efficient (core-power refund) | 5 Maiden's Blush, SP2 | `efficient.gd`: `mark_used` `is_marked` `refund` (returns whether it refunded, and is idempotent), plus `USED_KEY` / `UNUSED` / `USED`. A consumer carries TWO files on its core Kit: an `action_efficient_refund.tres` pointing at the shared reaction script (`combat_end` for a living mech, `unit_spawn` as the safety net) **and `passive_efficient_used.tres`**, the `PassiveDieCounter` with `resets_on_spawn = false`. **The passive is not optional**: `GearCore.short_repair` throws away every gear-state key except those of such passives (`gear_core.gd:144-150`) and every spawn runs it, so without it the spawn half is dead code. | Lovers Knot, Black Mountain |
| Terrain (difficult ground) | 6 Vauban, SP1 | **Four statics, all frozen:** `is_difficult(map, tile)` `is_unit_in_difficult(unit)` `is_entering_difficult(unit, next_anchor)` `lay(activation, specific, center, deployable)`, plus `PassiveGatedTerrainZone` with one `state_key` export. `lay` runs INLINE and hands the spawned unit back (the `Teleport.move` shape, not the Apocalypse Rail's queue-at-a-priority). **The unit it spawns is OWNED by `specific.unit`, and a deployable frame that must outlive its owner has to set `is_deactivated_on_owner_death = false` itself** — the export defaults to `true` and `EventService.remove_unit_from_game` kills owned markers that have it. Not born: a lifetime for laid terrain, a Burst 2 frame, "damage in". | Leoleth, Shackleton |

Planned:

| Family | Born with | Consumers |
|---|---|---|
| Lock-on consumed hook | 7 Naga | Black Mountain |
| Attack redirection | 3 Subutai | Sluagh, Rakshasa, Lovers Knot — shape set by that frame's spike |
| Once-per-round on-hit | 2 Fitzgerald, `mt_knock_em_down` | 5 Maiden's Blush, `mt_rend` — already two in-mod instances of the same two-method shape (`check_if_passive_applies` gating on `get_uses_this_round_alt(...) == 0`, and a `should_abort` that increments before `super`), differing only in `TRAIT_ID`/`USAGE_KEY` and the weapon type. **Trigger: extract into a shared parametrised base at the THIRD in-mod instance — or now, if the author says so.** Not done at two, deliberately: vanilla's Crack Shot III (`buff_watch_this.gd`) is the same one-script-per-trait duplication, both headers already say they are the same mechanism written the same way, and extracting means turning those two constants into `@export`s on a SHIPPED trait's `.tres`. |

Nothing with a vanilla precedent belongs here: limited weapons that attack without charges follow
the Injector Drill, and `mt_guardian` / `mt_fragile` / `mt_slow` / `mt_exposed_reactor` are vanilla
trait Kits to be referenced, not reimplemented.
