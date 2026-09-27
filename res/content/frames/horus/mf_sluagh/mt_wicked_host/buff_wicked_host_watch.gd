## WICKED HOST, the observer: a hostile character's hit on the Sluagh arms the next attack against it.
##
##   "Whenever the Sluagh is hit by an attack made by a hostile character, the next attack against it
##    has +1 difficulty. This effect lasts until the end of the scene."
##
## A BUFF RATHER THAN AN ActionReaction, for the Ripper Mod's and the Effervescent counter's reason:
## a reaction pays the per-kit reaction allowance and the per-round bookkeeping, and needs a Kit
## action the player can see in the reaction list. A triggered buff has neither, and the card is not
## a reaction.
##
## ATTACK / POST is the only timing that carries the outcome. event_unit_attack assigns the AttackRoll
## to context.object at :56 and queues the POST reactions at :123, so at this gate context.object is a
## valid AttackRoll and context.object.hit is final - including auto-hits, which
## execute_attack_roll_sequence writes the same way. At PRE the roll does not exist yet.
##
## RULING 9, CLAUSE BY CLAUSE:
##  - "the Sluagh is HIT": context.target_unit is the holder, and context.object.hit. ONE
##    event_unit_attack is queued per attacked unit (event_unit_attack_declared.gd:54-65), so an AoE
##    that catches the Sluagh arms exactly one chip however many units it hit.
##  - "an attack made by a HOSTILE CHARACTER": UnitRelation.are_enemies plus **is_actor**, asked of
##    context.unit.get_attacker(context) and NOT of context.unit - a relayed attack (the Ghast's
##    nexus, Buff.TO.SET_ATTACK_RELAY) puts the relay in context.unit and get_attacker resolves it.
##    PreAttack.create resolves the same way at attack_roll.gd:122.
##
##    THE PAIR - get_attacker() THEN is_actor() - IS THE WHOLE OF RULING 70, AND IT IS THIS FRAME'S
##    ONLY ATTACKER-SIDE CLAUSE. The mod's settled reading of "character" is that a DRONE IS NOT ONE
##    IN ITS OWN RIGHT, AND WHERE A DRONE ACTS, IT ACTS AS ITS OWNER (rulings 194, 64 and 70, 269;
##    the canonical paragraph is in
##    mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd's header). Everywhere
##    else on the Sluagh a drone is something a card is asked to shelter, guard, drag, target or
##    count, and there the bare is_actor() refuses it. Here the drone ACTS, and get_attacker ->
##    get_owner_unit_or_self (unit.gd:270-282) hands back the mech that deployed it - so AN OWNED
##    HOSTILE DRONE'S HIT ARMS THE CHIP, as its owner's hit, exactly as Draw Fire's ruling 70 has it.
##    Draw Fire itself is the precedent: ActionReactionAttacked:66 resolves the same way.
##
##    AN UNOWNED DRONE ARMS NOTHING, and that is the half is_actor() delivers on its own:
##    get_owner_unit returns null when deployable_owner_id is empty (unit.gd:264-268), so
##    get_attacker returns the drone itself and is_actor() refuses it. The same is true of a drone
##    carrying Buff.TO.SET_ATTACK_ROOT, which makes get_attacker return `self` outright
##    (unit.gd:281) - an Engineer turret that takes responsibility for its own shots is a drone
##    acting in its own right, and this card does not see one. Both halves are pinned:
##    test_an_owned_hostile_drones_hit_arms_the_chip_as_its_owners and
##    test_an_unowned_hostile_drones_hit_arms_nothing.
##
##    is_character() WOULD BE WRONG AND THE DIFFERENCE IS VISIBLE: it admits the unowned drone in
##    its own right, which is the reading the whole frame was moved off at the close.
##  - "weapon or tech" needs no clause: both go through this one event. That is why this is a Buff
##    and not an ActionReactionAttacked, whose allow_tech and allow_basic both default false.
##
## IT NEVER STACKS, AND THE ENGINE IS WHAT DELIVERS THAT, not this file.
## UnitCondition.consume_buffs(core, roll.pre.applied_buffs) runs at event_unit_attack.gd:114 and the
## ATTACK POST reactions are queued at :123 - and PreAttack.create puts every ATTACK_ROLL_INCOMING
## buff on the defender into applied_buffs (attack_roll.gd:135). So on a hostile HIT the pending chip
## is consumed nine lines before this gate is even asked, and the chip applied below is always the
## only one. test_a_second_hit_consumes_the_pending_chip_and_leaves_exactly_one_fresh_one is the
## guard; apply_buff_alt's same-source/same-to/same-until replacement (unit_condition.gd:741-747) is
## a second net under it, which is why the owner gear is passed rather than left null.
##
## THE HOLDER IS activation.context.unit, NOT the attacker. ReactionBus builds the activation block
## as {buff, unit = <the buff's holder>, event = <the triggering event>} (reaction_bus.gd:61-67), so
## the attacker that triggers_on_event reads out of the TRIGGERING event's context never appears in
## activate's own.
##
## DOES NOT CALL super IN activate. Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this watcher has to survive every hit for the whole scene.
extends Buff

const CHIP := &'buff_wicked_host'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.unit,         # the attacker, or a relay
		Context.PROP.target_units, # the attacked unit
		Context.PROP.object,       # the AttackRoll
	]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.target_unit != unit: return false
	if not Unit.is_valid(context.unit): return false
	var attacker:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(attacker): return false
	if attacker == unit: return false
	# RESOLVED FIRST, THEN is_actor(). An owned drone has already become its owner one line up, so
	# this refuses only a drone acting in its own right. See the header's ruling-70 paragraph.
	if not attacker.is_character(): return false
	if not UnitRelation.are_enemies(unit, attacker): return false
	if not AttackRoll.is_valid(context.object): return false
	return (context.object as AttackRoll).hit

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	# THE OWNER GEAR IS PASSED ON PURPOSE, twice over. It is what makes apply_buff_alt's replacement
	# rule fire on a re-application (same compcon_id, same from_gear, same `to`, same `until` -
	# unit_condition.gd:741-747), and it is what lets the chip read its NAME off the trait: with no
	# rows of its own, Translate.buff falls through to gear.<owner kit>.name (translate.gd:76-77),
	# so the player sees "Wicked Host" and this mod invents no string for it.
	UnitCondition.apply_buff_id(activation, unit, CHIP, core.get_owner_gear(activation.context.map))
