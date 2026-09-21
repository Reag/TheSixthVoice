## THE MARK'S REACTION: the dome answers a shot that went wide.
##
##   "As a reaction, when an attack misses you or an adjacent allied character, you may deal energy
##    damage to the attacker equal to your OVERSHIELD."
##
## THE ONLY REAL REACTION ON THIS FRAME. The other three - Wicked Host's watcher, the Stealing and
## Astral Guardian - are all point-free. This one spends the point, which is what "as a reaction"
## means in Lancer, and ActionReaction.get_per_round_hard_limit already returns 1 for that shape
## (action_reaction.gd:69), so the card's 1/round needs no override.
##
## TWO LIMITS, TWO CLOCKS, and it is worth knowing which is which. The POINT is restored by
## UnitAction.every_new_turn_refresh, which event_turn_start runs for EVERY unit on the map at ANY
## unit's turn start (event_turn_start.gd:42-44); the 1/ROUND TALLY is cleared by
## reset_per_round_usage inside new_turn_refresh, for the STARTING unit only (:79). So in real play
## the binding limit off-turn is the point, and the tally is what stops a second retort after the
## Sluagh's own turn has come round again. Draw Fire ruling 3 records the same pair.
##
## THE ARCHETYPE DOES MOST OF THE GATE: require_miss, the attacker and defender relations and the
## character test are declarative on the .tres and applied by super() (action_reaction_attacked.gd:64-128).
## Two clauses are added here:
##  - `defender == unit or UnitRelation.is_adjacent(unit, defender)`. The card covers BOTH "misses
##    you" and "misses an adjacent allied character", and are_allies is true of a unit and itself
##    (unit_relation.gd:364-365) so the archetype's ALLIES filter already passes the Sluagh - what it
##    cannot express is "or". NEVER require_defender_within: that is a radius, and ruling 6 has this
##    card TAKING House Guard's widening, which reaches adjacent_characters and nothing that measures
##    a radius. The argument order reads the SLUAGH'S buffs, which is the ruling's "direction".
##  - `defender.is_actor()`, for the reason every other card on this frame carries it:
##    require_defender_to_be_character is is_character(), and that is TRUE of a drone (unit.gd:116).
##    So A MISS ON AN ADJACENT ALLIED DRONE DOES NOT ARM THE RETORT, and this line is the only thing
##    that refuses it - a real narrowing of the archetype's flag, not a restatement, pinned by
##    `test_a_miss_on_an_adjacent_allied_drone_offers_nothing`. It is the MOD'S settled reading of
##    "character" (rulings 194, 64/70 and 269), not this frame's local taste; the canonical paragraph
##    is in mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd's header.
##    It is asked only of the ADJACENT-ALLY branch: the Sluagh itself is an actor by construction,
##    and asking it of the self case would only be a way to get the self case wrong.
##
## allow_tech AND allow_basic ARE SET, and both default false (action_reaction_attacked.gd:42-43).
## Ruling 15 says "any attack roll counts, weapon or tech", and EVERY vanilla ActionReactionAttacked
## with require_miss sets both - action_defense_net_aegis_miss.tres, action_feedback_priest.tres,
## action_metastatic_paralysis.tres, action_scorpion_attacked.tres.
##
## IT PROMPTS, BECAUSE THE CARD SAYS "YOU MAY" (design departure 2, taken against 1.5.3's sketch).
## CommonActionUtil.confirm_use raises a yes/no for a player-controlled unit and answers itself for
## anyone else (common_action_util.gd:304, :329). The return comes BEFORE spend_actions, which is
## what makes declining free - the point and the round both survive it, so a player can hold the
## retort for a better miss. Draw Fire's ordering exactly (action_draw_fire.gd:201-212).
##
## THE DAMAGE EVENT CARRIES unit, number, category AND target_unit, AND NOTHING ELSE.
##  - NO `action`, and that is the Eternity Hammer ruling: buff_resist_damage.gd:47-54 branches on
##    `context.action is ActionAttackWeapon` and then matches weapon_sizes / weapon_types, so passing
##    the attacker's own weapon action would let its "resist melee" buff reduce a retort that is not
##    an attack with that weapon at all.
##  - NO `gear`, because gear without action reaches nothing: buff_damage.gd:19 refuses any context
##    whose SpecificAction.from_context is not fully valid, and event_unit_damage reads context.gear
##    nowhere in its body. It would be an inert line.
##  - `target_unit = unit` IS passed (departure 3), which the Hammer's own call also does with the
##    comment "let the damage event know WHO has done this" (onhit_eternity_hammer.gd:221). It is an
##    optional prop "for reactions to inspect" (event_unit_damage.gd:35) and reaches no reduction
##    branch.
##  - NO FLAGS, which is ruling 15 in the negative: armor and resistance apply, because the card says
##    nothing. Contrast Crown of Restless Dead (SP3), whose card does.
##
## THE AMOUNT IS READ LIVE IN activate, not carried from the gate, and the Sluagh KEEPS its shield:
## the card says "equal to your OVERSHIELD", not "spend your OVERSHIELD". (What the dome loses on a
## miss AGAINST the Sluagh is the attack's own Reliable damage, soaked at event_unit_damage.gd:215-218
## AFTER this reaction has already read the full value - nothing here spends it.)
##
## THE TRIGGERING CONTEXT IS REACHED THROUGH `context.event`, NOT off this context - MEASURED in
## SP1 Task 6, where a throwaway print showed `context.target_unit` null and `context.event.context.
## target_unit` holding the defender. ReactionBus builds a reaction's activation block as
## {action, unit, gear, event} (reaction_bus.gd:53-60) and event_gear_activate hands `core.context`
## straight to activate() (event_gear_activate.gd:80) - so `activation.context` IS this same
## `context`, and the plan's `activation.context.event.context` and the `context.event.context`
## written below are the same object by two routes. The shorter one is what action_astral_guardian.gd
## and vanilla-adjacent action_draw_fire.gd:165 already use, so this file matches them.
extends ActionReactionAttacked

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const MARK_CHIP := &'buff_mark_of_the_dead'

## Draw Fire's pattern (action_draw_fire.gd:79-81): super() first, so the reaction-point and
## jammed/grappled checks still run, then the two clauses that make this reaction exist at all.
##
## THE ZERO-OVERSHIELD CLAUSE IS RULING 15 and is not decoration: without it the player would be
## asked whether to spend their one reaction to deal zero damage, on every miss, for as long as the
## dome is up - the same defect Halo's Grit-0 gate exists to avoid.
func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not super.is_available_to_activate(unit, gear): return false
	if not UnitCondition.has_buff(unit, MARK_CHIP): return false
	return Overshield.has(unit)

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit): return false
	var defender:Unit = triggering_event.context.target_unit
	if not Unit.is_valid(defender): return false
	# "misses YOU or an adjacent allied character" - the one clause the archetype cannot express.
	if defender == unit: return true
	# A mech or a pilot, never a drone - the mod's settled reading of "character" (rulings 194, 64/70
	# and 269). The .tres's require_defender_to_be_character does NOT deliver this, because
	# Unit.is_character() is true of a drone (unit.gd:116-117). See the header.
	if not defender.is_actor(): return false
	# The seam, ruling 6: is_adjacent, never a radius, with the SLUAGH as the first argument so it is
	# the Sluagh's buffs that are read.
	return UnitRelation.is_adjacent(unit, defender)

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	var triggering_context:Context = context.event.context
	var attacker:Unit = triggering_context.unit.get_attacker(triggering_context)
	if activation.abort_without_unit(attacker): return

	# Re-derived LIVE: the gate ran when the reaction was queued, and another reaction to the same
	# roll may have spent or granted Overshield since.
	var amount:int = Overshield.current(unit)
	if activation.abort_when(amount <= 0): return

	# "You MAY." Declining returns before spend_actions, so it costs neither the point nor the round.
	var confirmed:bool = await CommonActionUtil.confirm_use(
		context, [attacker], [], SpecificAction.from_context(triggering_context)
	)
	if activation.abort_when(not confirmed): return
	if activation.abort_without_units([unit, attacker]): return

	# Re-read once more: confirm_use was awaited, and a prompt is a real gap - something can have
	# spent the dome between the question and the answer.
	#
	# NOTHING IS SPENT UNTIL THE RETORT IS KNOWN TO HAVE SOMETHING TO DEAL. spend_actions sits BELOW
	# this abort, which is Draw Fire's order exactly (action_draw_fire.gd:201-212: every guard, then
	# the confirm, then the live rebuild, and only then the spend). Above it - where this line stood
	# until the close - a dome emptied across the prompt cost the player the point and the round for
	# zero damage, which is the one outcome the card's "you may" and ruling 15's "not offered at 0
	# Overshield" both exist to avoid. test_a_dome_emptied_during_the_prompt_spends_no_point is the
	# pin; it is RED against the old order.
	amount = Overshield.current(unit)
	if activation.abort_when(amount <= 0): return
	spend_actions(activation)
	await activation.execute_event(&'event_unit_damage', {
		unit = attacker,
		number = amount,
		category = Lancer.DAMAGE_TYPE.ENERGY,
		target_unit = unit, # let the damage event know WHO has done this
	})
