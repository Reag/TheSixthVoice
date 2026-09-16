## THE MOD'S SHARED ARMOR-GRANT: the DISPLAY half of "gains N armor".
##
## The visible sibling of buff_armor_reduction.gd, in this same folder. Read that file's header
## first - it carries the full account of why an armor grant is TWO buffs, why a STATBLOCK buff
## reduces nothing, and the four accepted divergences from real armor. This file is the half the
## player can see, and it is the half that reduces nothing.
##
## WHY THIS FILE EXISTS ALONGSIDE buff_reinforcement_blast.gd. The Fitzgerald's display half
## (res/content/gear/ipsn/systems/ms_grit_latch_magnets/buff_reinforcement_blast.gd) does the same
## job with `statblock.armor = 1` hardcoded, and was written first. It was NOT folded into this file
## at the Myconid SP2 promotion, deliberately: most of its length is a RECORD of measurements taken
## during Fitzgerald SP3 and SP4 - the get_armor() gate survey, the Ripper Mod interaction, and a
## mutation run establishing that its `on_application` refresh is belt-and-braces on 1.4.3 rather
## than load-bearing. Those records are about that sub-project, and generalising them would either
## lose them or bury this file. Consolidating the two is AUTHOR-FACING work for the frame close, not
## something to do silently; if it happens, the Fitzgerald's .tres re-points here with
## `armor_amount = 1` and its header moves to the design doc.
##
## USERS OF THIS FILE (the Fitzgerald's own is the third pair, on its own script):
##   - Myconid, FUNGAL NETWORK: buff_fungal_network_armor.tres, amount 1, held by the aura (MANUAL).
##   - Myconid, UFFISH GYRE: buff_uffish_gyre_armor.tres, amount 2, until the struck ALLY's own next
##     turn start (START_OF_TURN).
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
## ships rather than load-bearing (measured for the Fitzgerald's copy, 2026-09-14: every shipping
## caller reaches `post_apply_buff_cache_update`, whose first act is this same call). It stays for
## the reason that file gives: it costs one idempotent call, and it is the only defence if some path
## ever applies this buff with `update_caches = false`. CLEARING NEEDS NO EQUIVALENT -
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
