# SWIFT's evasion half (ruling 10): +2 Evasion until the start of the Leoleth's next turn.
#
# A SCRIPT RATHER THAN AN ARCHETYPE, because there is no BuffStatblock in engine/character/buff/archtypes/.
# The Goblin's buff_symbiosis_statblock.gd and this mod's own buff_inexorable_formation.gd are the
# two-line shape: return a Statblock in Context.object and let UnitBattleState fold it in.
#
# UnitBattleState.update_cached_values clears stat_bonus, walks every TO.STATBLOCK buff and calls
# stat_bonus.add_stats_from_block(buff.get_values().object) (:230-234). NOTE THAT IT PASSES NO
# CONTEXT: get_values() there is the zero-argument BuffCore form, so a script on this channel must
# never dereference context.map. This one returns a constant block, so it cannot.
#
# A FRESH Statblock EVERY CALL, deliberately: add_stats_from_block reads the object it is handed, and
# a shared instance would be one mutable resource every Leoleth on the map points at.
#
# on_application IS BELT-AND-BRACES ON THIS PATH, AND THAT IS MEASURED, not assumed. The plan
# expected it to be load-bearing; neutralising it (body -> `pass`) reddened NOTHING in
# spec/test_swift.gd, 9/9 either way. The reason is that the caller reaches the chip through
# UnitCondition.apply_buffs, whose last line is post_apply_buff_cache_update
# (unit_condition.gd:715 -> :770-777) - an unconditional unit.update_cached_values_and_token() that
# runs AFTER Buff.on_application (:758). So on the RAGE roll's path the cache is already refreshed
# for us.
#
# THE LINE STAYS, for the reason it was written: stat_bonus is rebuilt ONLY by update_cached_values,
# so any future application path that does not end in post_apply_buff_cache_update would leave this
# chip reporting nothing, and a spec that created a unit afterwards would never notice (the Sluagh's
# Task 5 measured exactly that hiding). buff_inexorable_formation and buff_effervescent_immunity
# both carry the same line.
extends Buff

const EVASION_BONUS := 2

func get_values(_core:BuffCore, _context:Context) -> Context:
	var block := Statblock.new()
	block.evasion = EVASION_BONUS
	return Context.create({ object = block })

func on_application(_event:EventCore, _core:BuffCore, unit:Unit) -> void:
	unit.update_cached_values_and_token()
