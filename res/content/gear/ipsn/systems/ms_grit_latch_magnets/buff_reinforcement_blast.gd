## REINFORCEMENT BLAST's armor, DISPLAY HALF ONLY: "All characters within the area gain 1 armor
## until the end of your next turn."
##
## THIS BUFF IS HALF THE MECHANIC. IT REDUCES NO INCOMING DAMAGE WHATSOEVER.
##
## The engine has no channel that grants real armor, and that is not an oversight of this file - it
## was measured. Incoming damage reads `unit.core.current.armor` (damage_modifications.gd:97), the
## damage pipeline's ONLY armor read. That value is assigned in exactly two places repo-wide
## (unit_printer.gd:35 and :73), both `= core.get_armor()` = `frame.stat.armor + core.bonus.armor`,
## and `core.bonus` is rebuilt only by UnitPrinter.recalculate_bonuses (unit_printer.gd:96-140) from
## pilot HASE, `stat_override`, NPC tier blocks and the PassiveStatIncrease passives of EQUIPPED
## GEAR - only at print time and on gear destroy/repair. No buff channel writes it, and nothing in
## the engine grants an arbitrary target unit temporary real armor.
##
## A Buff.TO.STATBLOCK buff instead lands in `Unit.state.stat_bonus` (unit_battle_state.gd:229-234,
## which sums `buff.get_values().object` when that is a Statblock). That is read by `unit.gd:309`
## (Unit.get_armor) and `fetcher_unit_stat.gd:29` - NEITHER of which is on the damage path. So what
## this buff actually buys is:
##
##   - the unit readout showing 1 armor (unit_stat_readout_small.gd:65, investigator.gd:276), plus
##     the visible status chip, since this is deliberately not hide_from_player;
##   - every `unit.get_armor()` GATE seeing it - including THIS MOD'S OWN Ripper Mod, whose "+1d6
##     bonus damage against targets with at least 1 Armor" clause reads exactly that getter.
##
## THE HALF THAT ACTUALLY MITIGATES IS `buff_reinforcement_blast_reduction`, a BuffResistDamage
## subclass applied by the same action. Neither buff alone is the mechanic; the pair is. The author
## ruled this shape on 2026-09-14 (rulings.md row 37, design §5.2's RESOLVED block) after SP3's
## spec/test_ripper_mod.gd test_temporary_armor_counts proved the STATBLOCK channel display-only.
## Never "simplify" this to one channel: dropping the reduction buff silently un-armours the system
## while every get_armor() assertion stays green, which is precisely how the SP4 blocker was missed.
##
## THE `on_application` REFRESH. `state.stat_bonus` is rebuilt in `recalculate_state`, which a
## status-less buff application does not itself trigger - so without a refresh the armor would exist
## in the buff list and in nothing the game reads until the unit next moved. Both vanilla STATBLOCK
## buffs carry this identical line and this identical comment: the Hydra's
## `content/frames/horus/mf_hydra/mt_system_link/buff_system_link.gd` and the Goblin's
## `content/frames/horus/mf_goblin/cp_instinct_rig/buff_symbiosis_statblock.gd`. CLEARING NEEDS NO
## EQUIVALENT - `UnitCondition.clear_buff` runs `post_clear_buff_cache_update` itself, so the armor
## drops off on expiry with no hook from us.
##
## MEASURED, NOT ASSUMED, AND THE MEASUREMENT CORRECTS THE TASK BRIEF: on 1.4.3 this line is
## BELT-AND-BRACES on every path that ships, not load-bearing. Deleting its body and re-running
## spec/test_reinforcement_blast.gd left it 12/12 (mutation run, 2026-09-14,
## .superpowers/sdd/sp4-t3-mutation-onapplication.log). The reason is that
## `ActionSystemApplyBuff.apply_buffs` goes through `UnitCondition.apply_buffs`
## (unit_condition.gd:703-715), which deliberately suppresses the per-buff cache update and then
## calls `post_apply_buff_cache_update` once at the end - and that function's first act
## (unit_condition.gd:772) is `unit.update_cached_values_and_token()`. The singular
## `apply_buff`/`apply_buff_alt` default to `update_caches = true` and do the same, and every caller
## of `apply_buff_alt` outside unit_condition.gd itself takes that default. So no shipping path
## applies a buff without refreshing the cache, and the vanilla comment above is stale for 1.4.3.
##
## IT STAYS ANYWAY, for three reasons: it is what both vanilla STATBLOCK buffs do, so a reader
## comparing them finds the same shape; it costs one idempotent call; and it is the only defence if
## some future path ever applies this buff with `update_caches = false` and no post-update, which is
## a one-word change away in engine code we do not control. Do not delete it on the strength of the
## mutation - just do not believe a green suite is evidence it runs.
extends Buff

func get_values(core:BuffCore, context:Context) -> Context:
	var statblock := Statblock.new()
	statblock.armor = 1
	return Context.create({ object = statblock })

# we don't naturally update the state cache on status-less buff applications
func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	unit.update_cached_values_and_token()
