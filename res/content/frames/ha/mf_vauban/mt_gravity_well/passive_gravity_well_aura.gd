## GRAVITY WELL's aura: the Vauban, and every ADJACENT ALLIED MECH.
##
## THE ONLY REASON THIS SCRIPT EXISTS is that the engine's "character" includes drones.
## PassiveAura.applies_only_to_characters filters on Unit.is_character() (passive_aura.gd:73), and
## Frame.is_character() is true for a drone (frame.gd:100); only is_mech() excludes it
## (unit.gd:118 -> frame.gd:101). The card says "adjacent allied MECHS", so a Hydra's Orochi drone
## parked next to the Vauban is not sheltered, and nor is a deployable of any kind.
##
## THE VAUBAN ITSELF IS EXEMPT FROM THAT CLAUSE, and the exemption is the card's own structure rather
## than a convenience: the first sentence is about the Vauban and says nothing about what it is, and
## the mechs clause belongs to the second sentence. A Vauban is a mech anyway, so today the two
## readings agree - the early return is here so that a future Vauban-shaped thing that is not a mech
## (a drone copy, a deployable simulacrum) still shelters itself, which is what the first sentence
## promises.
##
## EVERYTHING ELSE IS THE BASE CLASS'S DEFAULTS, set on the .tres beside this file: range 1, self and
## allies but not enemies, characters only, active from the first tracking pass. The card has no
## switch, so unlike the Myconid's Fungal Network auras this one does not set starts_active = false.
##
## This is an ordinary subclass of a class_name script used by our own resource, NOT a .gd_ext.gd
## engine extension, so Godot bug #83542 does not apply.
extends PassiveAura

func can_apply_buff_to_unit(moving_unit:Unit, aura_unit:Unit, aura_gear:GearCore) -> bool:
	if not super(moving_unit, aura_unit, aura_gear): return false
	if moving_unit == aura_unit: return true
	return moving_unit.is_mech()
