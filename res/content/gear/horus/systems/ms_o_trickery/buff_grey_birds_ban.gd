# THE BAN (ruling 4 and ruling 17a): "if your target takes an action that could target you, they
# must target you with that action."
#
# ONE BUFF STEERS EVERY UNIT-TARGETED ACTION, including the AI's choices, because the engine asks
# this channel from inside can_target_unit itself: Action.can_target_unit queries
# has_buff_to(specific.unit, ACTION_BANNED_UNITS, specific.to_context({target_unit = candidate}))
# (action.gd:221). ActionAttackWeapon re-implements the identical query rather than calling super
# (action_attack_weapon.gd:238-239) and ActionAttackTech reaches it through super
# (action_attack_tech.gd:65), so all three shapes end here. A TILE-targeted AoE never asks at all,
# which is why buff_grey_birds_recentre exists.
#
# IT LIVES ON THE INVADED UNIT AND IS OWNED BY THE SLUAGH'S GEAR. `owner` is
# core.get_owner_unit(context.map), resolved from from_gear (buff_core.gd:102-105) - which
# UnitCondition.apply_buffs set because action_grey_birds handed it context.gear.
#
# THE CHANNEL FAILS OPEN, and every clause below is written knowing it. does_buff_apply is one `and`
# chain (unit_condition.gd:845-851): a false from is_buff_context_valid_for_passive (:848) or from
# check_if_passive_applies (:849) drops this buff out of get_buffs_to, has_buff_to answers false, and
# the candidate is ALLOWED. A mistake here unbans; it does not over-ban.
#
# RE-ENTRANCY IS SAFE BY ONE LINE'S ORDERING. check_if_passive_applies calls
# can_target_unit(owner, specific), which asks this same buff again with target_unit = owner - and
# the `context.target_unit == owner` clause answers false BEFORE the recursive call is reached. Get
# that order wrong and the failure is a hung spec, not a red one.
#
# VANILLA'S THREE action_banned_units BUFFS ARE ALL THE `==` OF THIS SHAPE, keyed on a stored id:
# buff_backswing_cut_restrict_targets.gd (the Executioner), buff_sanctuary_priest_prohibited.gd and
# buff_false_idol_decoy.gd. This is the `!=`, which is why the owner has to be resolved rather than
# stored: "everyone except one unit" needs to know which one, live.
extends "res://unpacked/Reag-TheSixthVoice/res/content/gear/horus/systems/ms_o_trickery/buff_grey_birds_lifetime.gd"

## The cheap guard: does this context even carry what the decision needs? Every unrelated caller of
## get_buffs_to bails here - including the bare Context.create({unit = unit}) that get_buffs_to
## builds when it is given none (unit_condition.gd:823), which has no target_unit at all.
func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return (
		Unit.is_valid(context.unit) and
		Unit.is_valid(context.target_unit) and
		Action.is_valid(context.action)
	)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	var owner:Unit = core.get_owner_unit(context.map)
	if not Unit.is_valid(owner): return false
	# THE RE-ENTRANCY GUARD, and it must come before the call below.
	if context.target_unit == owner: return false
	return owner_is_a_legal_target(owner, context)

## "an action that COULD TARGET YOU" - the whole conditional half of the card, and it is two
## questions, not one.
##
## 1. can_target_unit(owner, specific): the action's own legality rules - hidden, self, ordnance
##    while engaged, tech immunity, a non-character for a tech attack. This is the call that
##    re-enters this buff, and the clause above is what stops it.
## 2. the owner's CLOSEST TILE is in UnitTargeting.get_tiles_in_range(specific): the geometry.
##    get_tiles_in_range is purely geometric - range, line of sight, elevation, ACTION_TILES buffs,
##    minimum range, dynamic zones (unit_targeting.gd:16-58) - and does NOT consult can_target_unit,
##    so the two questions really are independent. The shape is vanilla's own, at
##    unit_relation.gd:266 inside get_tech_attacks_that_can_react_against, where closest_pair comes
##    from closest_tiles_between at :255 and `.to` is the tile on the TARGET's side
##    (Tile.get_closest_pair_between returns {from, to, distance}, tile.gd:432-436).
##    (The design cites :262; that line is the sensor-range check FOUR lines above it - :263 is the
##    elevation test, :264 gear availability and :265 the action type.)
func owner_is_a_legal_target(owner:Unit, context:Context) -> bool:
	var specific := SpecificAction.from_context(context)
	if not SpecificAction.is_valid(specific): return false
	if not context.action.can_target_unit(owner, specific): return false
	var closest:Dictionary = UnitRelation.closest_tiles_between(context.unit, owner)
	return UnitTargeting.get_tiles_in_range(specific).has(closest.to)
