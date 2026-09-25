## PANOPLY COAT: "The Grutte Pier has Resistance to all damage and heat from attacks that originate
## from beyond Range 10." Design rulings 2-3.
##
## Tormentor Spines' shape (buff_tormentor_spines.gd), with two differences. It checks target_unit
## BEFORE reading it - the Vlad's calls target_unit.get_attacker() unguarded, which crashes on
## sourceless damage. And it measures from target_unit ITSELF, never get_attacker(): an attack relayed
## through Throughbolt's proxy, a Ghast Nexus or a drone originates where the relay stands
## (action_attack.gd:233, :269 make the relay the declared attack's unit), and get_attacker walks to
## the owner, which answers "who", not "from where".
##
## THE ATTACK'S DAMAGE CONTEXT (event_unit_attack_declared.gd:154-169): unit = the Pier, target_unit =
## the attacker, object = the AttackRoll. EventService.DAMAGE_FLAG has no from-attack flag, so
## AttackRoll.is_valid(object) is the only discriminator (buff_dispersal_shield_priest.gd:15-17).
## Damage an attack queues SEPARATELY with no AttackRoll - Arc Projector's chain, Throughbolt's AP
## line, Tachyon backblast - is not "from an attack" and is not resisted: recorded, not fought.
## Reliable damage on a miss still carries the AttackRoll (event_unit_damage.gd:255-263) and IS.
##
## HEAT is a damage_types member - there is no RESIST_HEAT (buff_resist_damage.gd:60, :63) - so the
## .tres lists all five types. Self-heat carries SELF_INFLICTED and is refused by the base
## (resist_self_inflicted = false). End-of-turn burn never reaches resistance at all
## (damage_modifications.gd, the IS_EOT_BURN early return).
##
## Asked twice per damage event (event_unit_damage.gd:52, :63); context.resource differs between
## the two passes, so nothing here reads it.
##
## THE DISTANCE IS THE ONE THE ATTACK WAS MADE AT, not the one at the damage (close review,
## 2026-09-25): the attack's own Knockback has already moved the Pier by then. action_panoply_coat_origin
## records it at ATTACK PRE on the trait's gear; a live measure is the fallback for an attack that
## left no record.
extends BuffResistDamage

const Origin := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/mt_panoply_coat/action_panoply_coat_origin.gd')

const BEYOND_RANGE := 10

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.target_unit) and super(core, context)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not AttackRoll.is_valid(context.object): return false
	var distance := Origin.recorded_distance(core.get_owner_gear(context.map), context.target_unit)
	if distance < 0: distance = UnitRelation.distance_between(context.unit, context.target_unit)
	if distance <= BEYOND_RANGE: return false
	return super(core, context)
