## SHREDDER CANNON'S CHIP (Purple Thorn SP3 Task 1, ruling 11): "Until the end of your next turn,
## the target is Shredded, and all characters gain +1 to all attack rolls against them."
##
## A BuffBonus on attack_roll_incoming, flat +1 (the .tres), gated here on the ATTACKER being a
## character: is_character() (a drone included, ruling 2026-09-27). The
## attacker is resolved through Unit.get_attacker (unit.gd:276-282), so an OWNED drone attacks as its
## owner and an UNOWNED drone attacks as itself - either way a character, so either way it gains the
## +1; a turret or other object still gains nothing.
##
## NO LEAK ONTO THE SHEET: with no target_unit the context is not an attack against the holder.
extends BuffBonus

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return super(core, context) and Unit.is_valid(context.unit)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super(core, context): return false
	var attacker:Unit = context.unit.get_attacker(context)
	return Unit.is_valid(attacker) and attacker.is_character()
