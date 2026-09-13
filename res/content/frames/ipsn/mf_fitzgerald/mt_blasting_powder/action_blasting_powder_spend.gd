## Spends Blasting Powder's 1/round, once, after a Line attack that hit at least one character.
##
## A HIDDEN REACTION RATHER THAN AN INCREMENT INSIDE THE BUFF. buff_blasting_powder's get_values
## runs once PER TARGET, so counting the round there would spend it on the first target and deny the
## second and third their bonus - the naive shape, whose damage numbers still look roughly right.
## ATTACK_DECLARED POST runs at the very end of event_unit_attack_declared.execute()
## (event_unit_attack_declared.gd:205), long after the per-roll bonus loop at :126-140, so by then
## every per-target bonus has already been computed. That ordering is also what makes ruling 5's
## "a Line attack that misses everyone does not consume it" expressible at all: the question is
## asked once, about the whole resolved attack, instead of once per target before anything is known.
##
## consumes_rxn = false on the .tres is essential - this is bookkeeping, and it must not eat the
## Fitzgerald's actual reaction for the round. It also keeps the action off the gear bar's radar
## entirely (gear_bar.gd:143 drops every ActionReaction), and show_in_tooltip below keeps it out of
## the Kit tooltip, so the player never sees a button or a line of text for it.
extends ActionReactionSelf

const USAGE_KEY:StringName = &'blasting_powder'

## Bookkeeping, not a rule the player reads: the trait's own effect row says everything there is to
## say. show_in_tooltip is a FUNCTION on Action (action.gd:341), not an exported property, so this is
## the only way to set it - action_system_clear_buff.gd:21 does the same.
func show_in_tooltip(kit:Kit) -> bool: return false

## super() (ActionReactionSelf) pins that the attacker was us.
##
## The "at least one CHARACTER" test is ruling 5's own wording, and it matches the buff's character
## gate: a Line that only broke some scenery has not used the trait up, because no character could
## have been paid a bonus by it.
func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	if not GearCore.is_valid(gear): return false
	if gear.get_uses_this_round_alt(USAGE_KEY) > 0: return false # already spent this round
	var context:Context = triggering_event.context
	var weapon:ActionAttackWeapon = context.action as ActionAttackWeapon
	if weapon == null: return false
	if weapon.range_pattern == null or weapon.range_pattern.pattern != Lancer.AOE_TYPE.LINE: return false
	if not DeclaredAttackSummary.is_valid(context.resource): return false
	var hit_units:Array[Unit] = context.resource.get_all_hit_units()
	return hit_units.any(func(hit_unit:Unit) -> bool: return hit_unit.is_character())

## context.gear is the gear this reaction was collected from - reaction_bus.gd:54-59 builds the
## event_gear_activate with `gear = gear` - i.e. this trait's own GearCore, which is the same gear
## buff_blasting_powder reads through core.get_owner_gear(). Both halves therefore count on one
## GearCore; spec/test_blasting_powder.gd asserts the counter back after a firing to keep that
## honest, because two halves writing and reading different gear would make the 1/round either never
## bite or bite forever.
func activate(context:Context, activation:EventCore) -> void:
	if not GearCore.is_valid(context.gear): return
	context.gear.increment_action_usage(USAGE_KEY)
