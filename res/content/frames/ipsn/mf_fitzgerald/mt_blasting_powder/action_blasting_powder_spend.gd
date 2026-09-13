## Spends Blasting Powder's 1/round, once, after a Line attack that hit at least one character.
##
## A HIDDEN REACTION RATHER THAN AN INCREMENT INSIDE THE BUFF. buff_blasting_powder's get_values
## runs once PER TARGET, so counting the round there would spend it on the first target and deny the
## second and third their bonus - the naive shape, whose damage numbers still look roughly right.
## ATTACK_DECLARED POST runs at the very end of event_unit_attack_declared.execute()
## (event_unit_attack_declared.gd:221), long after the per-roll bonus loop at :127-145, so by then
## every per-target bonus has already been computed. That ordering is also what makes ruling 5's
## "a Line attack that misses everyone does not consume it" expressible at all: the question is
## asked once, about the whole resolved attack, instead of once per target before anything is known.
##
## consumes_rxn = false on the .tres is essential - this is bookkeeping, and it must not eat the
## Fitzgerald's actual reaction for the round. It also keeps the action off the gear bar's radar
## entirely (gear_bar.gd:145 drops every ActionReaction), and show_in_tooltip below keeps it out of
## the Kit tooltip, so the player never sees a button or a line of text for it.
extends ActionReactionSelf

## The other half of the trait, and the OWNER of the vocabulary the two halves share: USAGE_KEY (the
## 1/round counter this file writes and the buff reads) and fired_as_a_line() (the Line gate both
## must answer identically). Declared once there and referenced here, rather than restated - two
## copies of the same predicate on the paying half and the charging half of one 1/round can drift
## silently, and the failure is a double payout or a phantom charge rather than an error. Same
## precedent as Hole Puncher's three buffs sharing statics off buff_hole_puncher_arcing.gd.
const BlastingPowder := preload('./buff_blasting_powder.gd')

## Bookkeeping, not a rule the player reads: the trait's own effect row says everything there is to
## say. show_in_tooltip is a FUNCTION on Action (action.gd:341), not an exported property, so this is
## the only way to set it - action_system_clear_buff.gd:21 does the same.
func show_in_tooltip(kit:Kit) -> bool: return false

## super() (ActionReactionSelf) pins that the attacker was us.
##
## The "at least one CHARACTER" test is ruling 5's own wording, and it matches the buff's character
## gate: a Line that only broke some scenery has not used the trait up, because no character could
## have been paid a bonus by it.
##
## WHY THIS WALKS attack_rolls RATHER THAN CALLING get_all_hit_units(). Every "is this still a unit"
## helper in the engine is ALIVE-GATED, and by the time this POST reaction runs the damage has
## already been applied (event_unit_attack_declared.gd:192 executes the damage events, :221 runs us):
## get_all_hit_units filters on Unit.is_valid (declared_attack_summary.gd:51), Unit.is_valid demands
## unit.is_alive (unit.gd:86), and Unit.is_character() demands is_active() on top of that
## (unit.gd:116). So a Line that KILLED everything it hit would come back with an empty list, leave
## the round unspent, and pay the trait out a second time on the next Line shot of the round -
## against ruling 5's "consumed by the first Line attack that hits at least one character", and not
## at all exotic on an Artillery frame firing through grunts. Reading the FRAME instead
## (Frame.is_character(), frame.gd:100) answers "was that a character?" for a corpse as readily as
## for a survivor, because the AttackRoll keeps its target_unit reference and remove_from_game()
## nulls only the token and map (unit.gd:132-137), never core.frame.
##
## The one place this reads WIDER than the buff's own Unit.is_character() gate is a target that is
## SHUTDOWN or EXILED: the frame still says character, so such a hit spends the round even though
## the buff would have paid it no bonus. Deliberate - "hit a character" is a rules question about
## what was shot, not about what state it was in - and it cannot be told apart from the dead case
## anyway once the unit is off the map.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not GearCore.is_valid(gear): return false
	if gear.get_uses_this_round_alt(BlastingPowder.USAGE_KEY) > 0: return false # already spent this round
	var context:Context = triggering_event.context
	if not BlastingPowder.fired_as_a_line(context): return false
	if not DeclaredAttackSummary.is_valid(context.resource): return false
	return context.resource.attack_rolls.any(func(roll:AttackRoll) -> bool:
		return roll.hit and hit_a_character(roll))

## Was this roll's target a character - alive or dead? See triggers_on_event above for why the
## question has to be asked of the frame.
static func hit_a_character(roll:AttackRoll) -> bool:
	if not is_instance_valid(roll) or not is_instance_valid(roll.target_unit): return false
	var target_core:UnitCore = roll.target_unit.core
	if not is_instance_valid(target_core) or not is_instance_valid(target_core.frame): return false
	return target_core.frame.is_character()

## context.gear is the gear this reaction was collected from - reaction_bus.gd:54-59 builds the
## event_gear_activate with `gear = gear` - i.e. this trait's own GearCore, which is the same gear
## buff_blasting_powder reads through core.get_owner_gear(). Both halves therefore count on one
## GearCore; spec/test_blasting_powder.gd asserts the counter back after a firing to keep that
## honest, because two halves writing and reading different gear would make the 1/round either never
## bite or bite forever.
##
## increment_per_turn_counter = false is passed EXPLICITLY, and THIS PARAGRAPH IS THE FRAME'S
## CANONICAL STATEMENT OF WHY - mt_knock_em_down/onhit_knock_em_down.gd, the Fitzgerald's other
## 1/round trait, points here rather than restating it, and the nineteen frames that copy this one
## should settle on the same answer. The rule: a trait whose limit is the per-ROUND counter passes
## false, because the per-turn tally it would otherwise write is a counter nothing reads.
##
## That flag gates ONLY the uses_this_turn
## tally (gear_core.gd:173-177; uses_this_round and uses_this_scene are written either way), and
## nothing reads a per-TURN count under this key: the trait's own limit is the per-ROUND counter,
## the per-turn soft limit at unit_action.gd:168 asks per-ACTION and this reaction's usage_group is
## &'blasting_powder_spend', and the charge fetcher at fetcher_kit_uses.gd:25-26 is not wired to this
## gear. Inert either way - but saying false says what is meant instead of leaving a third counter
## ticking under a key nothing consults.
func activate(context:Context, activation:EventCore) -> void:
	if not GearCore.is_valid(context.gear): return
	context.gear.increment_action_usage(BlastingPowder.USAGE_KEY, false)
