## REINFORCEMENT BLAST's armor, MITIGATING HALF: "All characters within the area gain 1 armor until
## the end of your next turn."
##
## THIS BUFF IS HALF THE MECHANIC, AND IT IS THE HALF NOBODY CAN SEE. Its sibling
## buff_reinforcement_blast (Buff.TO.STATBLOCK, armor = 1, player-visible) is what the unit readout
## shows and what every unit.get_armor() gate reads - this mod's own Ripper Mod included - and it
## reduces no incoming damage at all. This one reduces the damage and shows nothing. The action
## applies both; neither alone is the mechanic. Read buff_reinforcement_blast.gd's header first: it
## carries the display half's side of the same story.
##
## WHY THERE ARE TWO FILES AT ALL. Buff.to holds a SINGLE StringName, so one resource cannot be both
## a STATBLOCK buff and a RESIST_DAMAGE buff. Task 3 confirmed that directly. The author ruled the
## pair on 2026-09-14 (rulings.md row 37, design/2026-09-13-fitzgerald-design.md §5.2's RESOLVED
## block) after three separate derivations reached the same wall, so this is settled and not to be
## re-litigated in a later session.
##
## WHY A STATBLOCK BUFF ALONE DOES NOTHING. Incoming damage reads `unit.core.current.armor`
## (damage_modifications.gd:97) - the damage pipeline's ONLY armor read. That value is assigned in
## exactly two places repo-wide (unit_printer.gd:35 and :73), both `= core.get_armor()` =
## `frame.stat.armor + core.bonus.armor`, and `core.bonus` is rebuilt only by
## UnitPrinter.recalculate_bonuses (unit_printer.gd:96-140) from pilot HASE, `stat_override`, NPC
## tier blocks and the PassiveStatIncrease passives of EQUIPPED GEAR, only at print time and on gear
## destroy/repair. A Buff.TO.STATBLOCK buff instead lands in `Unit.state.stat_bonus`
## (unit_battle_state.gd:229-234), which is read by `unit.gd:309` and `fetcher_unit_stat.gd:29` and
## by nothing on the damage path. There is no engine channel that grants a target unit temporary REAL
## armor, so "give them armor" is not available and this is the nearest working substitute.
## spec/test_ripper_mod.gd's test_temporary_armor_counts is the executable proof of all of it.
##
## WHY THE AP GUARD BELOW. damage_modifications.gd:103 guards only the ARMOR branch with the AP flag
##
##     if available_armor > 0 and (not reduction_flags.has(EventService.DAMAGE_FLAG.AP)):
##
## while `other_reduction` - where a REDUCE buff's value lands - is subtracted unconditionally at
## :110. So a plain BuffResistDamage would blunt an AP hit that real armor cannot touch, which is the
## opposite of what the card grants. The override is enough because the context the gate receives IS
## the context whose flags that line reads: damage_modifications.gd binds `reduction_flags :=
## context.flags` at :31 and calls `UnitCondition.get_buffs_to(unit, Buff.TO.RESIST_DAMAGE, context)`
## at :62 with the same object. It therefore covers AP from ANY source, including a Ripper-modded
## weapon whose AP this mod's own buff_ripper_mod_strip_ap.gd has already erased from that context -
## which is the correct interaction, and the reason the two files should be read together: that one
## takes the flag OFF between the pipeline's two reads (event_unit_damage.gd:52 / :59 / :63), and
## this one asks about the flag on the second read. A stripped hit is a non-AP hit here, exactly as
## it is to armor.
##
## IT MUST CALL super(). BuffResistDamage.check_if_passive_applies is not a stub - it holds the
## self-inflicted guard, the basic-weapon guard and the weapon_sizes / weapon_types / damage_types
## decision (buff_resist_damage.gd:42-65). Replacing it rather than extending it would silently make
## damage_types below dead configuration.
##
## WHY is_onetime IS NOT SET. damage_modifications.gd:113 assigns EVERY RESIST_DAMAGE buff it
## consulted into `buffs_to_consume`, so this buff is handed to the consumer on every hit it blunts.
## It survives because UnitCondition.consume_buffs (unit_condition.gd:937-938) filters that list down
## to `buff.base.is_onetime` before clearing anything, and the export defaults false. Real armor is
## not spent by being used; setting is_onetime would make this a one-shot shield.
##
## WHY damage_types IS SPELLED OUT INSTEAD OF resist_everything. `resist_everything` excludes HEAT and
## NOT BURN (buff_resist_damage.gd:60 tests only `context.category_int != HEAT`), while armor ignores
## both - and burn really does reach the reduction branch (damage_modifications.gd:93-94 subtracts
## other_reduction for it). So the convenient flag would quietly blunt burn. The .tres therefore
## names KINETIC, ENERGY and EXPLOSIVE and leaves HEAT and BURN off the list.
##
## THREE DIVERGENCES FROM TRUE ARMOR REMAIN. All three are narrow, all three favour the defender, and
## all three were accepted by the same ruling rather than worked around. They are pinned here rather
## than by a spec, deliberately - each would need a contrived fixture to exercise and none is worth a
## test that would then have to be maintained as a description of a known imperfection:
##
##   1. ORDER AGAINST RESISTANCE. True armor is subtracted BEFORE resistance halves the damage
##      (damage_modifications.gd:104, then :107-108); `other_reduction` is subtracted AFTER
##      (:109-110). On a target that also has resistance to the damage type, this reduction is worth
##      slightly more than the armor it stands in for.
##   2. ONCE PER ATTACK ROLL vs ONCE PER DAMAGE EVENT. Armor is tracked across an attack roll through
##      `AttackRoll.damage_reduction_from_armor` (read at damage_modifications.gd:100-101, written
##      back at event_unit_damage.gd:68-69), so a single attack dealing two damage types spends its
##      armor once. This buff is consulted per damage event and so reduces each of them.
##   3. NO ARMOR MULTIPLIER. `ActionAttack.get_armor_multiplier()` (damage_modifications.gd:98) scales
##      real armor; its only user in the game is the Specter's monowire sword. It does not scale
##      this.
##
## SHREDDED IS NOT A DIVERGENCE, and that is worth knowing because it looks like one. The Shredded
## early return (damage_modifications.gd:73-77) happens after `other_reduction` has been accumulated
## at :66 but before the branch that ever subtracts it (:94 / :110), so a Shredded target loses this
## reduction exactly as it loses its armor.
extends BuffResistDamage

## The AP guard. Everything else about when this applies is BuffResistDamage's own decision - see the
## header on why this extends rather than replaces it.
func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if context.flags.has(EventService.DAMAGE_FLAG.AP): return false
	return super(core, context)
