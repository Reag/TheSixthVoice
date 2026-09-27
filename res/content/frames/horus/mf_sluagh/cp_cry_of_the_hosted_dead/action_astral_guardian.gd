## ASTRAL GUARDIAN: the Sluagh's dead throw themselves in front of whoever stands beside it.
##
##   "1/round, when an adjacent allied character is hit by an attack made by a hostile character,
##    they gain +1d6 OVERSHIELD. The OVERSHIELD is granted before damage is dealt."
##
## ATTACK / POST IS WHAT MAKES THE LAST SENTENCE TRUE, and it was measured before anything was built
## on it (SP1 Task 0, spec/test_spike_post_before_damage.gd, 3 tests, mutation-verified). Per-target
## attack events queue their POST reactions (event_unit_attack.gd:123); the declared event awaits
## every per-target event (event_unit_attack_declared.gd:67) and only then rolls damage (:74). So a
## grant made here is on the unit before a single point lands, and the engine's own soak
## (event_unit_damage.gd:215-218) spends it.
##
## DAMAGE PRE IS NOT AN ALTERNATIVE and the design says why: execute_preblock recomputes
## final_modified from incoming_amount (event_unit_damage.gd:49, :63), discarding any PRE change to
## context.number. PRE is for resistance-class buffs only.
##
## ActionReactionAttacked, NOT THE PLAIN ActionReaction THE PROBE USED. The probe extended the base
## deliberately, so its mutation could fire on a DAMAGE event at all - the archetype's gate needs an
## attack summary and would simply never have fired there, and "never fired" and "fired late" leave
## the same HP. Here there is no mutation to serve and the archetype does the work:
## require_hit, require_attacker_relation, require_defender_relation and
## require_defender_to_be_character are all declarative on the .tres and are applied by super()
## (action_reaction_attacked.gd:81-107).
##
## THE THREE CLAUSES super() CANNOT EXPRESS, and they are the whole of this script's body:
##  - `defender != unit`. UnitRelation.are_allies is TRUE of a unit and itself
##    (unit_relation.gd:364-365 is a bare Faction.is_ally of the two factions), so the archetype's
##    ALLIES filter happily passes the Sluagh being hit. The card says "an adjacent allied
##    character", meaning somebody else.
##    **REDUNDANT AGAINST VANILLA ADJACENCY, AND KEPT ON PURPOSE - MEASURED, SP1 Task 6.** Removing
##    this line alone reddens nothing (13/13 still green), because `is_adjacent(u, u)` is already
##    false: adjacent_characters routes through get_units_within, whose very first clause is
##    `other_unit != unit` (unit_relation.gd:58), so a unit is never in its own adjacency. Removing
##    BOTH this line and the adjacency line together DOES redden
##    test_a_hit_on_the_sluagh_itself_gets_nothing, which is how the pair was measured. It stays
##    because of the seam below: ruling 6 has this card taking a third party's widening of
##    adjacent_characters, and a widening that included self would make the Sluagh guard itself
##    against its own card. This clause is the only thing that would still refuse that.
##  - `defender.is_actor()`, AND IT IS A REAL NARROWING OF THE ARCHETYPE'S FLAG, not a restatement.
##    `require_defender_to_be_character` on the .tres is `defender.is_character()`
##    (action_reaction_attacked.gd:95), and Unit.is_character() returns TRUE for a drone - its own
##    comment says "active mech/pilot/drone" (unit.gd:116). is_actor() is is_character() and not
##    is_drone (:117), so AN ADJACENT ALLIED DRONE IS NOT GUARDED and this line is the only thing
##    that refuses it. Delete it and `test_a_hit_on_an_adjacent_allied_drone_gets_nothing` reddens.
##    WHY, IN ONE LINE: this is the MOD'S settled reading of "character", not this frame's local
##    taste - ruling 194 (the Vauban's Gravity Well shelters mechs only), rulings 64 and 70 (a
##    drone's shot counts as its owner's) and ruling 269 (the Stealing) all say the same thing, and
##    the canonical paragraph is in
##    mt_the_stealing_of_the_souls_of_the_dead/action_stealing_of_the_souls.gd's header. Design
##    1.5.1's own spec list says an adjacent allied DRONE gets nothing, and agrees.
##    The archetype's flag is kept anyway - it refuses objects and markers a step earlier and costs
##    nothing. (NOTE for a later session: the Myconid's action_halo.gd carries a docstring claiming
##    get_all_characters() excludes drones. It does not - UnitRelation.filter_for_characters is
##    `unit.is_character()` (unit_relation.gd:71) - so HALO really does offer a friendly drone today.
##    Shipped content, out of scope here, recorded.)
##  - `UnitRelation.is_adjacent(unit, defender)`, and NEVER require_defender_within = 1. That export
##    is a radius (distance_between, :92), and ruling 6 has this card TAKING House Guard's widening,
##    which reaches adjacent_characters and nothing that measures a radius (memory
##    third-party-adjacency-widening). is_adjacent(a, b) is adjacent_characters(a).has(b)
##    (unit_relation.gd:7-8), so the ARGUMENT ORDER is also the ruling: it reads the SLUAGH'S buffs,
##    which is why House Guard on the Sluagh widens this and House Guard on the ally does not.
##    spec/test_compat.gd pins both directions.
##
## allow_tech AND allow_basic ARE SET ON THE .tres, and both default false
## (action_reaction_attacked.gd:42-43). The card says "an attack", unqualified; with the defaults a
## hostile invade is refused at :126-127 and a hostile basic attack at :113. Vanilla's
## action_focused_shielding_aegis.tres - the Aegis shielding an ally who was hit, this reaction's
## structural twin - sets allow_basic for the same reason.
##
## THE 1/ROUND IS THE ENGINE'S. get_per_round_hard_limit is overridden because ActionReaction returns
## 99 for a reaction that consumes no point (action_reaction.gd:69); the limit is consulted inside
## ReactionBus.does_reaction_trigger via can_activate_gear, so a second guardian in a round is never
## OFFERED rather than offered and refused. It clears at the SLUAGH'S own turn start
## (reset_per_round_usage in UnitAction.new_turn_refresh) - per turn in truth, accepted for vanilla
## parity, and recorded again here because Draw Fire ruling 3 says the same thing about a different
## card. Halo's override, for the same reason.
##
## NO PROMPT (ruling 8: automatic). Halo asks because it CHOOSES an ally; this one is handed its
## defender by the event, so there is nothing to choose and nothing to ask. "They gain" is the card.
##
## EACH ROLL OF AN AoE IS ITS OWN TRIGGER, and the first one spends the round: one event_unit_attack
## is queued per attacked unit (event_unit_attack_declared.gd:54-65), so a Blast catching two adjacent
## allies offers this twice and the hard limit refuses the second. Ruling 13.
extends ActionReactionAttacked

const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

## Bookkeeping, not a rule the player reads twice: the core system's own effect row IS this card, and
## a reaction never reaches the gear bar anyway (gear_bar.gd:145). show_in_tooltip is a FUNCTION on
## Action (action.gd:341), not an exported property, so this is the only way to set it.
##
## IT IS ALSO WHAT KEEPS THIS ACTION OUT OF ICON_TARGETS: test_content_integrity.gd asserts an action
## is listed there exactly when _action_reaches_a_player_facing_surface is true, and for a reaction
## that is this function's answer. Design section 5's glyph family for it cannot be built; the Kit's
## own glyph is the whole family.
func show_in_tooltip(_kit:Kit) -> bool: return false

## ActionReaction returns 99 for a reaction that consumes no reaction point. The card says 1/round.
func get_per_round_hard_limit(_specific:SpecificAction) -> int:
	return 1

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super(unit, gear, triggering_event): return false
	if not Unit.is_valid(unit): return false
	var defender:Unit = triggering_event.context.target_unit
	if not Unit.is_valid(defender): return false
	# Somebody ELSE. are_allies is true of a unit and itself.
	if defender == unit: return false
	# A mech or a pilot, never a drone - the mod's settled reading of "character" (rulings 194, 64/70
	# and 269). The .tres's require_defender_to_be_character does NOT deliver this; see the header.
	if not defender.is_character(): return false
	# The seam, ruling 6. See the header for why this is is_adjacent and not a radius, and why the
	# Sluagh is the first argument.
	return UnitRelation.is_adjacent(unit, defender)

## THE DEFENDER IS REACHED THROUGH `context.event`, NOT off this context - MEASURED, not assumed
## (SP1 Task 6; the plan's own draft line read `activation.context.target_unit` and asked for this to
## be checked). ReactionBus builds a reaction's activation block as {action, unit, gear, event}
## (reaction_bus.gd:53-60) and event_gear_activate hands `core.context` straight to activate()
## (event_gear_activate.gd:80), so THIS context carries the HOLDER in `unit` and carries no
## target_unit at all; the triggering per-target attack event is in `event`, and its own context is
## where the defender lives. action_draw_fire.gd:165 reads its triggering context the same way.
func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var defender:Unit = context.event.context.target_unit
	# Re-derived LIVE rather than carried over from the gate: the gate ran when the reaction was
	# queued, and another reaction to the same roll may have displaced or destroyed either of them.
	if not Unit.is_valid(unit): return
	if activation.abort_without_unit(defender): return
	spend_actions(activation)
	# ONE d6, popped from the same global FIFO the attack roll uses (dice.gd:33-35) - which is why
	# every spec of this card queues [d20, this d6, the damage d6] in that order.
	await Overshield.grant(activation, defender, Dice.roll_d6())
