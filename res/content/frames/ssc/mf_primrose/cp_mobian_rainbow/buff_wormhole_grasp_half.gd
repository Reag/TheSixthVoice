## WORMHOLE GRASP, the half damage: "Attacks made this way deal half damage, Heat, and Burn."
##
## STAMPS THE ENGINE'S OWN FLAG rather than reducing anything itself (ruling 9).
## event_unit_attack_declared.execute reads context.flags.has(Action.FLAG.HALF_DAMAGE) when it builds
## each damage event (:158-163) and passes it into get_damage_flags (:230-265) as
## EventService.DAMAGE_FLAG.HALVED; DamageModifications.create then applies Util.half
## (damage_modifications.gd:46-53), which is ceili (util.gd:14-15). The flag is TYPE-AGNOSTIC: the
## loop at :150-163 runs once per damage type, so Kinetic, Energy, Explosive, Heat and Burn are all
## halved by that one line - which is exactly what the card's "damage, Heat, and Burn" asks for.
## action_attack_weapon.gd:74 copies the flag onto a followup aux attack, so followups inherit it.
##
## WHY NOT Buff.TO.DEAL_HALF_DAMAGE: that channel is read from context.target_unit - the DEALER - in
## DamageModifications.create (damage_modifications.gd:46-50), with no activation flags in scope, so
## it could not tell an overwatch from a normal attack. The declared event can, because the flags are
## still on it.
##
## ATTACK_DECLARED / PRE is the only timing that works. execute_preblock fires the PRE reactions
## (:21-23) and execute reads the flag; a POST buff would run after every damage event was already
## built, and an ATTACK-level buff would run once per target rather than once for the declaration.
##
## activation.context.event IS THE TRIGGERING DECLARED EVENT: the reaction bus builds an
## event_buff_activate carrying {buff, unit, event} (reaction_bus.gd:61-67). The mod's own
## wm_ripper_mod/buff_ripper_mod_strip_ap.gd mutates a triggering event through exactly this path.
##
## DOES NOT CALL super IN activate. Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one lasts the scene.
extends Buff

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit, Context.PROP.flags]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if not Unit.is_valid(context.unit): return false
	# THE ATTACKER GATE IS LOAD-BEARING FOR EVERY ATTACK IN THE SCENE, not a rare-case guard. This
	# buff is polled for EVERY unit's declared attack: ReactionBus.trigger_occurred walks
	# map.get_all_units() and every buff each one carries against every ATTACK_DECLARED event
	# (reaction_bus.gd:61-67), and the only other gates here are Unit.is_valid and IS_OVERWATCH -
	# which a HOSTILE'S overwatch satisfies just as well as ours. Only the marker holder's OWN
	# overwatch qualifies; delete this line and the Primrose's marker halves the damage coming AT it.
	# test_a_hostiles_overwatch_is_not_halved_by_our_marker is what measures that.
	#
	# get_attacker rather than context.unit so the holder's DEPLOYABLES still count as the holder: a
	# marker or drone blames get_owner_unit_or_self unless it carries Buff.TO.SET_ATTACK_ROOT, the
	# engineer-turret channel unit.gd:281 branches on.
	if context.unit.get_attacker(context) != unit: return false
	if not context.flags.has(Action.FLAG.IS_OVERWATCH): return false
	# Idempotent, and mildly live rather than dead: HALF_DAMAGE can already be on a declaration this
	# buff never stamped, because action_attack_weapon.gd:74 copies it into a followup aux attack's
	# freshly built followup_flags. So this line can only ever suppress a stamp that is ALREADY
	# present - it can never change a damage number, and `has` is what execute reads, not a count.
	# (Those followup_flags carry no IS_OVERWATCH, so in that particular case the gate above has
	# already refused; what is left is the bus polling this buff twice for one declaration.)
	return not context.flags.has(Action.FLAG.HALF_DAMAGE)

func activate(core:BuffCore, activation:EventCore) -> void:
	activation.context.event.context.flags.append(Action.FLAG.HALF_DAMAGE)
