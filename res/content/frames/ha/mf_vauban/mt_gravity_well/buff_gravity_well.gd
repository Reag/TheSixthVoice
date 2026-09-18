## GRAVITY WELL's chip: +1 difficulty on ranged and melee attacks against its holder, while the
## VAUBAN stands in difficult terrain.
##
##   "While the Vauban is in at least one space of difficult terrain, all ranged and melee attacks
##    made against it have +1 difficulty. Any adjacent allied mechs also benefit from this ability."
##
## THE VALUE IS CONSTANT AND THE GATE DOES ALL THE WORK, and that split is forced by the engine rather
## than chosen. AttackRoll.PreAttack.create gathers TO.ATTACK_ROLL_INCOMING buffs from the ATTACKED
## unit with the per-target roll's context (attack_roll.gd:135) but calls buff_core.get_values() BARE,
## with no context at all (:184) - so get_values cannot see which roll it is modifying, or with what.
## Only check_if_passive_applies is handed the context. So: bonus_value = -1 on the .tres, and both
## questions here. The Diversion Rail's chip and the M/K2's Hybridized Shot record the same reasoning.
##
## "RANGED AND MELEE ATTACKS" ARE WEAPON ATTACKS (ruling 7), which is one class test:
## ActionAttackWeapon covers Skirmish, Barrage, Overwatch, a Ram, a Grapple and any weapon-based
## reaction, and excludes every tech attack - which is what the card means by naming only two of the
## three. Naming the two types explicitly would be wrong as well as longer: the card's list is the
## Lancer taxonomy of WEAPON attacks, not two of the six Lancer.WEAPON_TYPE values.
##
## THE CONDITION IS THE VAUBAN'S OWN TILES, ALWAYS (ruling 7). The buff is held by the Vauban and by
## every adjacent allied mech, and every copy asks the same question about the same unit - the
## sheltered ally's own ground is never consulted. core.get_owner_unit(map) resolves through
## BuffCore.from_gear (buff_core.gd:102-105), which PassiveAura.apply_aura_buffs_to_unit set to the
## AURA GEAR (passive_aura.gd:82) - i.e. the Kit on the Vauban - for every copy it hangs.
##
## Prone and standing underwater do NOT count, and that falls out of asking Terrain rather than the
## pathfinder: both are pathfinder synthetics (pathfinder.gd:96-97), never the tile property
## (ruling 4's reason).
##
## A LOST OWNER REFUSES rather than guessing. The aura clears its buffs on the owner's death
## (passive_aura.gd:55-59) and EventService.remove_unit_from_game clears outgoing buffs besides
## (event_service.gd:71), so this should be unreachable - but a gate that runs on every incoming
## attack roll on the map must answer rather than throw.
##
## *** TWO ADJACENT VAUBANS SHARE ONE CHIP, AND THE SHARED CHIP ANSWERS FOR BOTH OF THEM. ACCEPTED
## BEHAVIOUR (ruling R3), NOT AN OVERSIGHT. *** PassiveAura.apply_aura_buffs_to_unit skips a buff the
## unit already holds FROM ANY SOURCE - `if UnitCondition.has_buff(to_unit, buff.compcon_id): continue`
## (passive_aura.gd:80, and its own comment says "from any source") - and
## applies_to_other_copies_of_this_frame defaults true (:12), so nothing stops one Vauban's aura
## hanging its chip on another. Whichever Vauban's aura pass ran first owns BOTH chips, and every copy
## asks about ITS owner (the `core.get_owner_unit` read below), so:
##
##   - a Vauban standing in its OWN field gets NO shelter if the other Vauban's aura ran first and
##     that other Vauban is on clean ground, and
##   - a Vauban on clean ground IS sheltered while the owning Vauban stands in a field.
##
## One chip, one answer, for the pair. That is the same reading ruling R3 gives Sap's shared reprieve:
## keyed on the ABILITY, not on the gear. Which of the two owns the pair is an iteration-order detail
## of PassiveAura.update_unit (:28) and is deliberately not depended on.
## test_two_adjacent_vaubans_share_one_chip_and_therefore_one_answer pins the sharing without pinning
## the order, so a later session cannot quietly make the chip per-Vauban.
extends BuffBonus

const Terrain := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/terrain/terrain.gd')

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if context.action is not ActionAttackWeapon: return false
	var vauban:Unit = core.get_owner_unit(context.map)
	if not Unit.is_valid(vauban): return false
	return Terrain.is_unit_in_difficult(vauban)
