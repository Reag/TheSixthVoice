## The Subutai's integrated DIVERSION RAIL.
##
##   "Main Rifle, AP, 1d6 Kinetic, Range 15. On attack: You become immobilized until the start of
##    your next turn. On hit: The target takes +2 difficulty on all attacks that do not target the
##    Subutai until the end of their next turn."
##
## Only the ON ATTACK half is code. The on-hit half is onhit_diversion_rail.tres carrying
## buff_diversion_rail, both scriptless-to-this-file, because OnHitEffect already does exactly that.
##
## WHY activate() AND NOT AN OnHitEffect WITH apply_on = ON_ATTACK. Either would fire on a miss, but
## the status lands on the FIRER and OnHitEffect's statuses go to the attacked unit
## (apply_buffs_to_self covers buffs only). The Bizarre Cannon's idiom is therefore the shape:
## await super.activate, then bail if the activation aborted.
##
## THE ABORT GUARD IS LOAD-BEARING. ActionAttack.activate bails before spend_actions when the
## targeting is cancelled, so an aborted shot costs no action - and must cost no mobility either.
## Vanilla guards its own follow-up attacks the same way (action_attack_weapon.gd:61).
##
## START_OF_TURN, NOT END_OF_THIS_TURN. unit_condition.gd:21 clears a START_OF_TURN status at the
## unit's OWN next turn start, which is "the start of your next turn" for both the ways this weapon
## fires: on the Subutai's turn, and as a Draw Fire follow-up during an enemy's. It must survive the
## Subutai's own turn END, because that is precisely when JUGGERNAUT DRIVE looks for it - the two
## abilities are designed to interlock and a shorter lifetime would break the frame's whole loop.
extends ActionAttackWeapon

func activate(context:Context, activation:EventCore) -> void:
	await super.activate(context, activation) # make the attack
	if activation.aborted: return
	if not Unit.is_valid(context.unit) or not GearCore.is_valid(context.gear): return
	UnitCondition.apply_status(
		activation,
		context.unit,
		Lancer.STATUS.IMMOBILIZED,
		Lancer.UNTIL.START_OF_TURN,
		context.gear.persistent_id,
	)
