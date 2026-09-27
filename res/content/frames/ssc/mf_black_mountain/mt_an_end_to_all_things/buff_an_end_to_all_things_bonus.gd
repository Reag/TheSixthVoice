## THE +3, scoped to one defender of one attack (Black Mountain SP1, ruling 7) - Eyes of Night's
## buff_eyes_of_night_bonus.gd with this trait's gear as owner and its own state key.
##
## A BuffDamage on Buff.TO.BONUS_DAMAGE_SPECIFIC: "applied to specific units; not halved like normal
## bonus damage" (buff.gd:31). Read per attack roll by roll_specific_bonus_damage
## (event_unit_attack_declared.gd:268-296) with `target_unit = attack_roll.target_unit` in the context,
## and consumed there (:296), because is_onetime.
##
## WHY IT IS SCOPED: a Blast lands one per-target attack event per unit hit, and An End to All Things
## fires on the first of them (and, 2/round, may fire on the second). Without this clause a buff meant
## for one defender would be rolled into the other's damage too. The stamped id is the defender of the
## roll the reaction answered; with two offers on one Blast each buff carries its own defender.
##
## NO `until`, AND FINISH_DAMAGE IS THE ONE VALUE THAT MUST NOT BE SET - Eyes of Night's MEASURED reason:
## event_unit_damage.gd:76-77 clears every FINISH_DAMAGE buff on the DAMAGED unit whenever a damage
## instance consumes resist buffs, and this reaction's own 1 heat to the Black Mountain is queued at
## POST, so it lands before the attack's damage roll. Here the payer (the Black Mountain) is NEVER the
## attacker (ruling 3), so the sweep would miss this buff today - but the lifetime is kept as
## is_onetime alone anyway, so the two cards stay one mechanism. Nothing leaks: a level exit ends
## combat, and the Black Mountain dying of its own heat strips the buff off the ally through
## clear_outgoing_buffs_from_unit (is_cleared_on_owner_death is the default true).
##
## IT IS HIDDEN AND IT IS STILL NAMED IN THE BATTLE LOG (Eyes of Night, close review slice 6 I-1):
## attack_util.gd:308 stamps bonus_source_name = name_text(), and event_unit_attack_declared.gd:305-313
## writes "{unit} is dealing +{amount} bonus damage ... from {sources}". gear.buff_an_end_to_all_things_bonus.name
## is that name; hide_from_player stays.
##
## can_apply_to_tech_attacks IS SET: "a successful attack roll", unqualified; an invade's +3 inherits
## the attack's type (HEAT).
extends BuffDamage

const DEFENDER_KEY := 'an_end_defender'

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not super.check_if_passive_applies(core, context): return false
	if not Unit.is_valid(context.target_unit): return false
	return context.target_unit.core.persistent_id == core.get_state(DEFENDER_KEY, '')
