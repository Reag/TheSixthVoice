## THE DDMR's 1/round gate. The statuses/buff wiring (the chip itself, buff_ddmr_aegis.tres) is
## declarative on onhit_ddmr.tres; this script exists only to spend the round, and the whole reason it
## can is that ruling 23 routes the chip through PassiveWeaponMod.on_hit_effects
## (event_unit_attack.gd:43-45), collected and fired UNCONDITIONALLY beside the action's own effects -
## there is no per-passive gate upstream of this the way a Buff.TO.ONHIT_EFFECT channel would give one
## (see buff_magnetic_weight_redistribution.gd's check_if_passive_applies for that other shape, which
## this is deliberately NOT). should_abort's own true/false IS the round limit.
##
## THE MODELS: onhit_wormhole_grasp_slow.gd and onhit_magnetic_weight_redistribution.gd, both read
## first. Unlike either of those two - which let their effect through every time and lean on a
## save-avoid or a declarative gate elsewhere for "1/round" to mean anything - this one has no second
## gate, so it explicitly checks get_uses_this_round_alt BEFORE incrementing and aborts (skips the
## chip) if the round is already spent.
##
## WHY THE COUNTER LIVES ON THE MOD'S OWN GEAR, NOT THE WEAPON'S. unit.get_gear(MOD_ID) resolves the
## DDMR's own fitted GearCore because equip_weapon_mod appends it to `systems`
## (loadout_core.gd:356-362), and every full_repair pass rebuilds compcon_id_to_gear from
## get_all_gear() (loadout_core.gd:284-289 regenerate_caches, called from regenerate_derived_gear at
## :275) - the same cache any other equipped system is found through.
## spec/test_ddmr.gd's test_the_units_own_get_gear_resolves_the_fitted_mod is the measurement that
## proves this rather than trusting it: without it, this whole gate is unverified and a null read
## here would fail either permanently OPEN (every hit chips, no matter how many this round) or
## permanently CLOSED (no hit ever chips), depending which way GearCore.is_valid(null) breaks.
##
## WHY THE INCREMENT HAPPENS BEFORE super(stage, activation, attacked_unit). This OnHitEffect carries
## no save_to_avoid, so super's own body (on_hit_effect.gd:54-73) does nothing but the unit-validity
## check this override already redoes explicitly - there is no "spend the round even on a passed
## save" ordering question the way ruling 10's Slowed effect has one. The increment sits before the
## round check's own early return so a round that is already spent is refused WITHOUT touching the
## counter a second time.
##
## increment_action_usage's SECOND ARGUMENT is FALSE, matching onhit_wormhole_grasp_slow.gd and
## onhit_magnetic_weight_redistribution.gd: it gates only the uses_this_turn tally
## (gear_core.gd:171-181); the per-ROUND counter this gate reads (uses_this_round, via
## get_uses_this_round_alt) is written either way, and nothing in this mechanism reads a per-turn
## count under this key. A true here would write a third counter nobody reads.
extends OnHitEffect

const MOD_ID:StringName = &'wm_ddmr'
const USAGE_KEY:StringName = &'ddmr'

func should_abort(stage:STAGE, activation:EventCore, attacked_unit:Unit) -> bool:
	if stage == apply_on:
		var unit:Unit = activation.context.unit
		if not Unit.is_valid(unit): return true
		var mod_gear:GearCore = unit.get_gear(MOD_ID)
		if not GearCore.is_valid(mod_gear): return true
		if mod_gear.get_uses_this_round_alt(USAGE_KEY) > 0: return true
		mod_gear.increment_action_usage(USAGE_KEY, false)
	return await super(stage, activation, attacked_unit)
