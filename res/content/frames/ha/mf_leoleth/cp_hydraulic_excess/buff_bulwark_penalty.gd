# BULWARK's penalty (ruling 13), hung by the core Kit's PassiveAura on every hostile character in the
# Leoleth's line of sight: +1 Difficulty on their attacks - EXCEPT on the Leoleth itself.
#
# THE CHIP IS ON THE HOSTILE, AND THE ENGINE FORCES THAT. PreAttack.create collects
# Buff.TO.ATTACK_ROLL from the ATTACKER (attack_roll.gd:134) and ATTACK_ROLL_INCOMING from the
# DEFENDER (:135). The card penalises attacks against somebody who is neither the Leoleth nor the
# attacker, so no INCOMING buff could carry it.
#
# "OTHER THAN YOU" IS PER-ROLL, not per-placement: the same hostile is penalised against an ally and
# not against the Leoleth, in the same instant. So the clause is here rather than in the aura's
# can_apply_buff_to_unit.
#
# core.get_owner_unit(map) IS THE LEOLETH, because UnitCondition.apply_buffs stamps BuffCore.from_gear
# with the applying gear - which for an aura is the AURA's gear (passive_aura.gd:82), i.e. the core
# Kit on the Leoleth (buff_core.gd:102-105).
#
# A NULL OWNER FAILS OPEN, deliberately: if the owner cannot be resolved the penalty simply does not
# apply. A gate that runs on every attack roll in the game must answer rather than throw, and
# "no penalty" is the safe answer. THE SAME PRINCIPLE COVERS THE TARGET below: context.target_unit is
# read straight off the attack Context, and an unresolvable one gets the same answer - no penalty,
# not a crash.
#
# BOTH WEAPON AND TECH ATTACKS. This is a BuffBonus on the plain ATTACK_ROLL channel, which
# PreAttack.create folds in for every attack type (:182-189) - the card says "attacks", unqualified.
#
# "CHARACTERS OTHER THAN YOU" IS TWO CLAUSES, NOT ONE (bug fix, Leoleth frame close). The card reads
# "attacks against CHARACTERS other than you", and the bare `!= leoleth` below only ever implemented
# the second half - it said nothing about what counts as a character, so a hostile shooting a wreck,
# a piece of destructible cover, a deployable turret or a friendly drone was ALSO catching the -1.
# RULING 22 (this frame): "character" means Unit.is_actor(), not Unit.is_character() -
# Unit.is_character() is TRUE for a drone (unit.gd:116, "active mech/pilot/drone") and Unit.is_actor()
# is what narrows to "active mech/pilot" (unit.gd:117: is_character() and not core.frame.is_drone).
# passive_bulwark_aura.gd's OWN sibling override does exactly this narrowing for PLACEMENT - "THE ONE
# OVERRIDE IS is_actor()", its header says - so this file now matches it for RESOLUTION, the other
# half of the same card: the aura decides who carries the chip, this buff decides which of the
# chip-holder's shots it taxes.
extends BuffBonus

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var leoleth:Unit = core.get_owner_unit(context.map)
	if not Unit.is_valid(leoleth): return false
	# "against characters other than you" - the CHARACTER half first, fails open on an unresolvable
	# target for the same reason the owner check above does.
	if not Unit.is_valid(context.target_unit): return false
	if not context.target_unit.is_actor(): return false
	# ...and the OTHER THAN YOU half.
	return context.target_unit != leoleth
