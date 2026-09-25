## ENTRAP (Reaction, 1/round): "The Koremasa hits a hostile character with a melee attack that it has
## already successfully hit with tech attack that round. That character takes 1 Heat." Design 1.4,
## rulings 14, 16 and 18.
##
## FRAME-SCOPED ID (action_entrap_koremasa): the Rakshasa carries an Entrap of its own
## (17-rakshasa.md:48), so the bare name is left free.
##
## A REAL REACTION: consumes_rxn at its export default of true, so the point is the price and the
## 1/round comes free from ActionReaction.get_per_round_hard_limit (action_reaction.gd:69) - which is
## why this file does NOT override it (the Jormungandr's ruling). It resets at the Koremasa's own turn
## start (ruling 18).
##
## "A MELEE ATTACK" IS A MELEE WEAPON AT THREAT (ruling 14's "attack" half). The .tres filters
## weapon_types = [MELEE] and allow_basic = false (no Ram, Grapple or Improvised Attack); this file
## adds `threat > 0`, because a THROWN attack is the same weapon with threat 0
## (action_attack_weapon.gd:199-211, the thrown variant sets it) and Lancer makes it a ranged attack.
##
## "ALREADY SUCCESSFULLY HIT WITH TECH ATTACK THAT ROUND" is the mark: THIS Koremasa's buff_entrap_mark
## (matched by our own gear's persistent id, so a second Koremasa's mark never arms this one), and its
## stamp must be this round (buff_entrap_mark.gd's is_live).
extends ActionReactionAttacked

const EntrapMark := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_koremasa/mt_entrap/buff_entrap_mark.gd')

const MARK_ID := &'buff_entrap_mark'
const HEAT := 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	var context := triggering_event.context
	var defender:Unit = context.target_unit
	if not Unit.is_valid(defender) or not defender.is_actor(): return false
	var weapon := context.action as ActionAttackWeapon
	if weapon == null or weapon.threat <= 0: return false
	return has_live_mark(defender, gear, context.map)

## Does `defender` carry THIS gear's mark, stamped this round?
static func has_live_mark(defender:Unit, gear:GearCore, map:MapState) -> bool:
	for core:BuffCore in UnitCondition.get_buffs(defender, MARK_ID, gear.persistent_id):
		if EntrapMark.is_live(core, map): return true
	return false

func activate(context:Context, activation:EventCore) -> void:
	var defender:Unit = context.event.context.target_unit
	if activation.abort_without_unit(defender): return
	spend_actions(activation)
	# THE UNIT, NOT A SPECIFIC (action_combust.gd's reasoning).
	CommonActionUtil.queue_damage_events(
		activation, context.unit, [defender] as Array[Unit], HEAT, Lancer.DAMAGE_TYPE.HEAT)
