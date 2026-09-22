## GREENLIGHT PROJECTION's 1/round burn (Leoleth rank III, design ruling 18):
##
##   "Choose one MELEE weapon: 1/round, after you hit a character with this weapon, you take 1 Burn
##    and the target takes 3 Burn."
##
## THE MODEL IS onhit_ddmr.gd, and everything about the GATE is that file's reasoning verbatim: the
## chip-free half of this card is the only difference. Read its header for why the counter can live
## here at all - ruling 23 routes a weapon mod's effect through PassiveWeaponMod.on_hit_effects
## (event_unit_attack.gd:43-45), collected and fired UNCONDITIONALLY beside the action's own
## effects, so there is no per-passive gate upstream of this and should_abort's own true/false IS
## the round limit.
##
## WHY THE COUNTER LIVES ON THE MOD'S OWN GEAR, NOT THE WEAPON'S. unit.get_gear(MOD_ID) resolves
## this mod's own fitted GearCore because equip_weapon_mod appends it to `systems`
## (loadout_core.gd:356-362), and every full_repair rebuilds compcon_id_to_gear from get_all_gear().
## spec/test_greenlight_projection.gd's test_the_units_own_get_gear_resolves_the_fitted_mod is the
## measurement that proves this rather than trusting it: a null read here would fail either
## permanently OPEN (every hit burns) or permanently CLOSED (no hit ever burns).
##
## WHY THE INCREMENT HAPPENS BEFORE super(...). This OnHitEffect carries no save_to_avoid and no
## buffs, so super's body does nothing but the unit-validity check this override has already redone
## - there is no "spend the round even on a passed save" ordering question. The increment sits after
## the round check's early return so a round already spent is refused WITHOUT touching the counter a
## second time.
##
## increment_action_usage's SECOND ARGUMENT IS FALSE, matching onhit_ddmr.gd: it gates only the
## uses_this_turn tally (gear_core.gd:171-181), and the per-ROUND counter this gate reads is written
## either way. A true here would write a third counter nobody reads.
##
## THE BURN IS DEALT IN on_hit, NOT IN should_abort, because should_abort's contract is to decide
## and this card's effect is damage rather than the declarative statuses/buffs the archetype applies
## for itself. TWO SEPARATE queue_damage_events calls rather than one with both units: the numbers
## differ, and generate_damage_events takes a single amount for the whole array
## (common_action_util.gd:70).
##
## THE SELF BURN NEEDS NO EXPLICIT SELF_INFLICTED FLAG. generate_damage_events appends it itself
## whenever a target IS the specific's own unit (common_action_util.gd:89), and passing the bare
## Unit as `specific_or_origin_unit` makes the Leoleth that unit. Asserted in the spec rather than
## restated here.
##
## BURN IGNORES ARMOR, which is the only reason "you take 1 Burn" is visible at all on an armor-1
## frame: damage_modifications.gd:89-90 exempts HEAT and BURN from the armor subtraction outright.
extends OnHitEffect

const MOD_ID:StringName = &'wm_greenlight_projection'
const USAGE_KEY:StringName = &'greenlight'
const TARGET_BURN := 3
const SELF_BURN := 1

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		var unit:Unit = activation.context.unit
		if not Unit.is_valid(unit): return true
		var mod_gear:GearCore = unit.get_gear(MOD_ID)
		if not GearCore.is_valid(mod_gear): return true
		if mod_gear.get_uses_this_round_alt(USAGE_KEY) > 0: return true
		mod_gear.increment_action_usage(USAGE_KEY, false)
	return await super(stage, activation, attacked_unit)

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit) or not Unit.is_valid(attacked_unit): return
	CommonActionUtil.queue_damage_events(
		activation, unit, [attacked_unit] as Array[Unit], TARGET_BURN, Lancer.DAMAGE_TYPE.BURN
	)
	CommonActionUtil.queue_damage_events(
		activation, unit, [unit] as Array[Unit], SELF_BURN, Lancer.DAMAGE_TYPE.BURN
	)
