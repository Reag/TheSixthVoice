## SHIMMERING SHIELD, the difficulty: "While you are in cover, melee attacks against you receive
## +1 Difficulty."
##
## THE VALUE IS CONSTANT AND THE GATE DOES ALL THE WORK, and that split is forced by the engine rather
## than chosen: get_values is not handed the attack context in any useful form - only
## check_if_passive_applies is. So bonus_value = -1 sits on the .tres and every question lives here.
## The Vauban's buff_gravity_well.gd has the same shape for the same reason.
##
## ============================ WHY THIS COMPUTES COVER ITSELF ============================
##
## TWO REASONS, and either alone would be enough.
##
## 1. THE QUERY RUNS BEFORE THE ROLL COMPUTES COVER. PreAttack.create gathers ATTACK_ROLL_INCOMING
##    buffs at attack_roll.gd:135 and only reaches CoverCalculator.determine_cover at :158, so at this
##    gate the roll's own answer does not exist yet (design 7).
##
## 2. THE ROLL NEVER COMPUTES COVER FOR THIS KIND OF ATTACK AT ALL.
##    ActionAttackWeapon.ignores_cover returns TRUE for a melee weapon whose threat > 0
##    (action_attack_weapon.gd:206-212), and attack_roll.gd:153-158 skips the entire cover block when
##    it does. So a melee attack at threat has never taken cover in this engine - which is exactly why
##    the card is worth printing, and which CORRECTS design 1.5's expected -2 on a covered melee roll
##    to -1. Measured on the 1.4.3 source, 2026-09-19;
##    test_the_engine_itself_gives_a_melee_attack_at_threat_no_cover_line is the measurement.
##
## So the gate asks CoverCalculator directly, with the same three arguments the roll would have used
## at :158: the defender, the relay, and the declared attack's source voxels. With no
## DeclaredAttackSummary in the context - which a preview has and a real roll does not lack - the
## voxel list is empty and CoverCalculator falls back to the attacker's own occupied voxels
## (cover_calculator.gd:47-49), which is the same answer.
##
## "MELEE ATTACK" IS A MELEE WEAPON AT THREAT (ruling 8). A thrown variant is the same action with
## threat set to 0 (action_attack_weapon.gd:349-372), and the card is about somebody swinging at you.
## The same line that makes it a throw is what makes ignores_cover false, so a throw is the one melee
## attack that DOES take vanilla cover - and the one this refuses.
##
## THE IGNORE_COVER CLAUSE IS RULING 8'S SECOND HALF AND IS THE AUTHOR'S RULING, NOT AN ENGINE MIRROR.
## Design 1.5 justifies it by attack_roll.gd:161-163, which zeroes cover for a defender that cannot
## benefit from it - true for a RANGED attack, and unreachable for a melee one, since the block never
## runs. The clause stays because the author ruled that a Markerlighted Primrose gets neither, and
## because it keeps this card agreeing with the rest of the engine about who benefits from cover. The
## context is cloned with the cover level in `category` because that is what the defender-side gates
## read: buff_markerlight_no_cover.gd:13 refuses anything that is not SOFT.
##
## THE ATTACKER'S OWN IGNORE_COVER (Hole Puncher, Seeking) IS DELIBERATELY NOT CONSULTED. The roll
## zeroes cover for it too (attack_roll.gd:156), so a stricter reading would refuse the shield there
## as well - but no ruling covers it, this plan does not invent one, and it is listed in "Handed
## forward" for the close.
extends BuffBonus

## Only an attack context can answer any of this; an incomplete one is not a refusal, it is a
## question this buff was not asked.
func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return (
		Unit.is_valid(context.target_unit) and
		Unit.is_valid(context.unit) and
		GearCore.is_valid(context.gear) and
		Action.is_valid(context.action)
	)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if context.action is not ActionAttackWeapon: return false
	if not UnitAction.is_melee_weapon(context.action, context.gear): return false
	if context.action.threat <= 0: return false # a throw (ruling 8)

	var defender:Unit = context.target_unit
	var relay:Unit = context.unit # the roll calls this `relay`; the Ghast's nexus is why it differs
	if not Unit.is_valid(defender) or not Unit.is_valid(relay): return false

	# The same three inputs PreAttack.create hands determine_cover at attack_roll.gd:158.
	var source_voxels:Array[Vector3i] = []
	if DeclaredAttackSummary.is_valid(context.resource): source_voxels.assign(context.resource.source_voxels)
	var cover:CoverCalculator.CoverResult = CoverCalculator.determine_cover(defender, relay, source_voxels)
	if cover.total == Lancer.COVER.NONE: return false

	# Can the defender actually benefit from it? attack_roll.gd:161-163 asks the same question of the
	# same channel, with the cover level in `category`, which is what buff_markerlight_no_cover.gd:13
	# reads.
	return UnitCondition.get_buffs_to(
		defender, Buff.TO.IGNORE_COVER, Context.clone(context, {category = cover.total})
	).is_empty()
