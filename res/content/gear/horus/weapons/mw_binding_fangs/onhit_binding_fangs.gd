## BINDING FANGS' ON-HIT LOCK (Naga SP3 Task 1, design ruling 14).
##
## "On hit: You may expend a charge. If you do, you take 1 Heat, and the target becomes Locked On."
## (specs/sixth-voice/10-naga.md, Rank II)
##
## THERMAL CHARGE'S SHAPE (onhit_thermal_charge.gd): a charge spent by hand from an on_hit behind a
## brochure yes/no, because an OnHitEffect has no action economy of its own. The only differences are
## whose charge it is (the weapon's own, not a mod's) and what it buys.
##
## NOT OFFERED AGAINST A TARGET ALREADY LOCKED ON - ruling 14. The card would let the Naga pay a
## charge and a heat for a lock that changes nothing (Lockon.apply refuses a second one), so the
## prompt would only ever be a trap. A lock CONSUMED by this same swing is gone by the time the hit
## lands (the consume runs at ATTACK_DECLARED PRE), so that target IS offered - the card's loop.
## Hostiles only: locking an ally is never what this is for.
##
## CHARACTERS ONLY (frame close, slice 4 #2): "the target becomes Locked On", and vanilla Lock On only
## ever targets a character (action_lock_on.gd:8, is_character - a drone passes, an object does not).
## A hostile deployable object was offered the charge and took LOCKON.
## NOT OFFERED TO A TARGET IMMUNE TO LOCKON (slice 4 #3, ruling 14's trap rule): an Invulnerable or
## status-immune target would take the charge and the heat and refuse the lock. Asked with the Fangs'
## persistent id as the source - the id Lockon.apply writes - so a source-keyed immunity reads what
## the lock itself would.
##
## THE HEAT is gain_self_heat_alt - the queued SELF_INFLICTED heat every "you take N heat" in this mod
## uses (action_blood_of_the_creature.gd) - and it lands after the attack event, with the lock.
## THE LOCK goes through the frozen Lockon.apply, source = the Fangs' persistent id.
extends OnHitEffect

const Lockon := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/lockon/lockon.gd')

const HEAT_COST:int = 1

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	var context:Context = activation.context
	var unit:Unit = context.unit
	var gear:GearCore = context.gear
	if not Unit.is_valid(unit) or not Unit.is_valid(attacked_unit): return
	if not GearCore.is_valid(gear) or gear.kit.charges_max <= 0: return
	if not gear.has_charges_left(): return
	if not UnitRelation.are_enemies(unit, attacked_unit): return
	if not attacked_unit.is_character(): return
	if attacked_unit.has_status(Lancer.STATUS.LOCKON): return
	if UnitCondition.is_immune_to_status(attacked_unit, Lancer.STATUS.LOCKON, gear.persistent_id): return

	var confirmed:bool = true
	if unit.is_player_controlled():
		var brochure := BrochureCore.create({
			title = gear.kit.name(),
			description = gear.kit.bbcode_description(),
			subtitle = tr('lancer.geartag.limited').format({value = gear.get_charges_count_string(unit.core)}),
			show_continue = false,
		})
		confirmed = await choice_bus.quick_yesno_for({
			tile = attacked_unit.tile(),
			title = tr('battle.confirm.use').format({action = Util.formatted_color(
				gear.kit.name(),
				Colors.get_action_color(Action.FLAVOR.WEAPON)
			)}),
			brochure = brochure,
			whois = attacked_unit,
		})
	if not confirmed: return
	if not Unit.is_valid(unit) or not Unit.is_valid(attacked_unit) or not GearCore.is_valid(gear): return

	gear.spend_charge()
	UnitAction.gain_self_heat_alt(HEAT_COST, SpecificAction.from_context(context), activation)
	Lockon.apply(activation, attacked_unit, gear)
