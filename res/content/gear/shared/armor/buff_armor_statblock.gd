## THE MOD'S SHARED ARMOR-GRANT: the DISPLAY half of "gains N armor".
##
## The visible sibling of buff_armor_reduction.gd, in this same folder. Read that file's header
## first - it carries the full account of why an armor grant is TWO buffs, why a STATBLOCK buff
## reduces nothing, and the four accepted divergences from real armor. This file is the half the
## player can see, and it is the half that reduces nothing.
##
## THE FOLD. Until 2026-09-16 this file had a duplicate: the Fitzgerald's REINFORCEMENT BLAST ran
## its own copy, res/content/gear/ipsn/systems/ms_grit_latch_magnets/buff_reinforcement_blast.gd,
## identical to this one except `statblock.armor = 1` hardcoded where this file reads the `.tres`
## export below. Its REDUCTION sibling was promoted to buff_armor_reduction.gd at Myconid SP2
## (2026-09-16, design ruling 8); this DISPLAY half stayed un-folded a while longer because most of
## the old file's length was a RECORD of Fitzgerald SP3/SP4 measurements rather than a description of
## the code - the get_armor() gate survey and the Ripper Mod interaction said the same thing "WHAT
## THIS BUFF ACTUALLY BUYS" below already said, and are not repeated a third time; the
## `on_application` mutation run is folded into that section's own paragraph below, with its
## citations corrected against 1.4.3 source rather than just carried over. THE FOLD LANDED at the
## frame close (2026-09-16): buff_reinforcement_blast.tres now points here with `armor_amount = 1`,
## and the old dedicated .gd and its .gd.uid are deleted.
##
## USERS OF THIS FILE:
##   - Fitzgerald, REINFORCEMENT BLAST: buff_reinforcement_blast.tres, amount 1, until the end of the
##     OWNER's next turn (Lancer.UNTIL.END_OF_OWNERS_NEXT_TURN = 7). The first user; folded in at the
##     frame close, 2026-09-16 - see "THE FOLD" above.
##   - Myconid, FUNGAL NETWORK: buff_fungal_network_armor.tres, amount 1, held by the aura (MANUAL).
##   - Myconid, UFFISH GYRE: buff_uffish_gyre_armor.tres, amount 2, until the struck ALLY's own next
##     turn start (START_OF_TURN).
##   - Gloire, RAPID RUSHDOWN: buff_rapid_rushdown_armor.tres, amount 1, until START_OF_TURN.
##
## EACH USER MUST ALSO APPLY ITS buff_armor_reduction.tres SIBLING, WITH THE SAME `until`. This buff
## alone is an armor number on the readout that blunts nothing; that buff alone is damage quietly
## going missing with no chip to explain it. The pair is the mechanic. Author's ruling of 2026-09-14
## (rulings.md row 37); do not "simplify" either away.
##
## WHAT THIS BUFF ACTUALLY BUYS. A Buff.TO.STATBLOCK buff lands in `Unit.state.stat_bonus`
## (unit_battle_state.gd:229-234, which sums `buff.get_values().object` when that is a Statblock).
## That is read by `unit.gd:309` (Unit.get_armor) and `fetcher_unit_stat.gd:29`, and by NOTHING on
## the damage path - the pipeline's only armor read is `unit.core.current.armor`
## (damage_modifications.gd:97), which no buff can write. So this buff buys the readout, the visible
## status chip (these users are all deliberately not hide_from_player), and every `unit.get_armor()`
## GATE - including this mod's own Ripper Mod, whose bonus-damage clause reads exactly that getter.
##
## THE `on_application` REFRESH. `state.stat_bonus` is rebuilt in `recalculate_state`, which a
## status-less buff application does not itself trigger. Both vanilla STATBLOCK buffs carry this
## identical line - the Hydra's content/frames/horus/mf_hydra/mt_system_link/buff_system_link.gd and
## the Goblin's content/frames/horus/mf_goblin/cp_instinct_rig/buff_symbiosis_statblock.gd - so a
## reader comparing them finds the same shape. On 1.4.3 it is belt-and-braces on every path that
## ships rather than load-bearing.
##
## MEASURED, NOT ASSUMED, FOR THE FITZGERALD'S COPY BEFORE THE FOLD (2026-09-14, mutation run
## originally logged at .superpowers/sdd/sp4-t3-mutation-onapplication.log - that log has since
## rotated off disk, so this is a carried-forward historical record, not independently re-run here):
## deleting the equivalent line and re-running spec/test_reinforcement_blast.gd left that file green
## in full, 12/12 as Task 3 left it (the file has grown since; that count is a record of the run, not
## a figure to reconcile against the suite today).
##
## THE MECHANISM, RE-VERIFIED AGAINST 1.4.3 AT THE FOLD (2026-09-16, and one citation corrected):
## ActionSystemApplyBuff.apply_buffs runs through UnitCondition.apply_buffs (unit_condition.gd:
## 703-715), which passes `update_caches = false` to each per-buff apply_buff_alt call (:710) and
## calls post_apply_buff_cache_update once at the end (:715); that function's actual cache-refresh
## call is `unit.update_cached_values_and_token(...)` at unit_condition.gd:775 - NOT :772, a bare
## local-variable line just above it, which is what the original record of this measurement cited.
## The singular apply_buff/apply_buff_alt default `update_caches` to true (unit_condition.gd:718)
## and reach the same :775 call, and every caller of apply_buff_alt outside unit_condition.gd itself
## takes that default. So no shipping path applies a buff without refreshing the cache, and the
## vanilla comment both sibling files carry is stale for 1.4.3.
##
## IT STAYS ANYWAY, for three reasons: it is what both vanilla STATBLOCK buffs do, so a reader
## comparing them finds the same shape; it costs one idempotent call; and it is the only defence if
## some future path ever applies this buff with `update_caches = false` and no post-update, which is
## a one-word change away in engine code we do not control. Do not delete it on the strength of the
## mutation - just do not believe a green suite is evidence it runs. CLEARING NEEDS NO EQUIVALENT -
## `UnitCondition.clear_buff` runs `post_clear_buff_cache_update` itself, so the armor drops off on
## expiry with no hook from us.
##
## THE AURA CASE, WHICH THE FITZGERALD NEVER HAD. When this buff is applied by a PassiveAura,
## UnitCondition.apply_buffs (unit_condition.gd:713-714) additionally sets
## update_tracking_and_statuses, so the refresh below is reached through a re-entrant aura pass. That
## pass terminates - PassiveAura.already_has_all_buffs (passive_aura.gd:95-96) is true the second
## time round - and the probe (spec/test_spike_status_aura.gd) measured it as exactly one application
## per occupant before any of this frame's content was written. The probe was deleted at SP2 Task 5
## (d6f1ab3); the same fact is now pinned against the real Kit by test_fungal_network.gd's
## test_the_cloud_applies_its_chip_exactly_once_per_hostile.
extends Buff

## The armor this grant is worth. Lives on the .tres so one script serves every amount - the same
## split buff_armor_reduction.tres uses for `reduction_amount`.
@export var armor_amount:int = 1

func get_values(core:BuffCore, context:Context) -> Context:
	var statblock := Statblock.new()
	statblock.armor = armor_amount
	return Context.create({ object = statblock })

# we don't naturally update the state cache on status-less buff applications
func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	unit.update_cached_values_and_token()
