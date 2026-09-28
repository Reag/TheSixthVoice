## HEAVENLY WEAVER's chip (design 1.3, rulings 8-10): the charge, visible on the Six Sky until its next
## successful attack spends it.
##
## THE BLESSED BOLT SHAPE (buff_blessed_bolt.tres), with a different lifetime and its own hit gate. to =
## plain bonus_damage, read ONCE for the whole declared attack by its general bonus-damage roll
## (event_unit_attack_declared.gd:95, context.resource the DeclaredAttackSummary, every per-target roll
## already on it), halved when more than one character is attacked (declared_attack_summary.gd:44-45,
## attack_util.gd:309-312) and added to every victim's damage, then consumed at :124. until is MANUAL,
## never FINISH_DAMAGE: FINISH_DAMAGE buffs are cleared after every attack, and "the next successful
## attack" may be rounds away (ruling 8).
##
## ON A MULTI-TARGET ATTACK EVERY VICTIM TAKES HALF THE 1d6, as Lancer does (rulings.md Pass E,
## reversing ruling 10, which gave the first target hit the full 1d6 and the others nothing while the
## chip sat on bonus_damage_specific). A single-target attack deals exactly what it did.
##
## ITS OWN HIT GATE. The general read consumes whatever it fetched on a hit OR a miss (:124), and
## require_hit cannot help - it hides the buff from that read entirely, which carries no AttackRoll
## (buff_damage.gd:20). So the chip applies only when the summary holds a hit: a miss never fetches it,
## and the charge waits for a successful attack.
##
## ONLY THE SIX SKY'S OWN WEAPON ATTACKS (ruling 9). An owned drone attacks with its OWNER's buffs -
## roll_specific_bonus_damage reads get_buffs_to(context.unit.get_attacker(context)), and get_attacker
## is get_owner_unit_or_self (unit.gd:276-282) - so without the holder check below a drone's hit would
## spend the Six Sky's charge. Tech attacks are refused by BuffDamage's own can_apply_to_tech_attacks.
##
## GONE AT SCENE END WITH NO CLEAR OF OURS (measured 2026-09-26): buffs live on UnitBattleState
## (unit_battle_state.gd:21), and the next level builds every unit with a fresh one from its core
## (Unit.create, unit.gd:76). spec/test_heavenly_weaver.gd pins it.
##
## NEVER THE ATTACK THAT ARMED IT (the author's ruling, SP2 build, 2026-09-26). A Daykeeper crit
## teleports someone from INSIDE its attack (on_crit runs in the per-target attack event, before the
## declared attack rolls damage), so the chip lands in time for that same attack's damage roll.
## "The next successful attack" is a LATER one: the watch marks the attack it armed inside
## (ARMED_DURING_META, on that attack's DeclaredAttackSummary), and this refuses a marked attack. The
## mark lives and dies with the attack, so nothing here needs clearing.
extends BuffDamage

## Set on a DeclaredAttackSummary by buff_heavenly_weaver_watch when the chip was armed inside it.
const ARMED_DURING_META := &'reag_heavenly_weaver_armed_during'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	var holder:Unit = core.get_holder_unit(context.map)
	if not Unit.is_valid(holder) or context.unit != holder: return false
	# "The next SUCCESSFUL attack": the general read carries the summary, every roll resolved.
	if not DeclaredAttackSummary.is_valid(context.resource): return false
	var summary:DeclaredAttackSummary = context.resource
	if not summary.attack_rolls.any(func(roll:AttackRoll) -> bool: return AttackRoll.is_valid(roll) and roll.hit): return false
	return not summary.has_meta(ARMED_DURING_META)
