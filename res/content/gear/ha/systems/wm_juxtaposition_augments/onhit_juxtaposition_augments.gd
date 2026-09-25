## JUXTAPOSITION AUGMENTS' spend (design ruling 30): the weapon's first attack each turn spends the
## chance, in the Danger Zone or not. The design's "ATTACK POST watcher", met as a weapon-mod ON_ATTACK
## effect: PassiveWeaponMod.on_hit_effects are collected from the ATTACKING weapon's own mods
## (event_unit_attack.gd:44-45) and their on_attack runs after every attack roll with it (:66), so the
## engine already scopes this to the fitted weapon - the DDMR's route (ruling 23 there), no reaction.
##
## In the Danger Zone the roll has already consumed the chip (event_unit_attack.gd:303), so this finds
## nothing. Outside it, the chip never applied and this is what spends it. A multi-target attack spends
## it on the first target's roll, as the engine does.
##
## NO WEAPON TEST HERE, on purpose: this only ever runs for the weapon the mod is fitted to, and the mod
## is UNIQUE, so every chip on the holder is this weapon's. A mutation that dropped such a test stayed
## green (SP5 ledger, J7) - it was dead code, so it is gone.
extends OnHitEffect

const CHIP := &'buff_juxtaposition_augments'

func on_attack(activation:EventCore, attacked_unit:Unit) -> void:
	var context := activation.context
	if not Unit.is_valid(context.unit): return
	var holder:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(holder): return
	UnitCondition.consume_buffs(activation, UnitCondition.get_buffs(holder, CHIP))
