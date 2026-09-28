## FELL THE MIGHTY (Black Mountain SP2, Blackstone Bell's active, design ruling 12):
##
##   "Choose a hostile character within sensors and line of sight, they are DOOMED for the rest of the
##    scene. [...] This ability is Efficient and will refund 1 Core Point at the end of any scene in which
##    this ability was used."
##
## VANILLA'S ActionSystemApplyBuff does the whole card (Salvation Upon the Wicked's archetype, aimed at a
## hostile instead of the Naga): on the .tres, action_type 4 (PROTOCOL), consumes_cp, apply_to_sensors
## (get_target_range -> Sensors, Ensorcel's reach), apply_only_to_enemies, and buffs = [buff_doomed]. The
## archetype's can_target_unit refuses an object (is_actor) and anyone the Black Mountain cannot see
## (is_hidden_from); line of sight is the engine's targeting (requires_line_of_sight). The confirm, the
## spend, the FX and the application are the archetype's.
##
## A HOSTILE DRONE IS A VALID TARGET (close-out Pass F T14: a drone IS a character, Pass A). Vanilla's
## is_actor() line refuses drones too (action_system_apply_buff.gd:64), so can_target_unit below sends a
## drone through the shared CharacterTarget helper - that function minus that one line. "Hostile" still
## binds it (apply_only_to_enemies).
##
## can_reapply is TRUE, a deviation from ruling 12's text in service of ruling 13: the archetype's
## can_reapply = false refuses a target holding the buff FROM ANYONE (already_has_our_buff with no source),
## so a second Black Mountain could never DOOM a target the first had - and ruling 13 says two stack. One
## Black Mountain cannot press it twice in a scene anyway: the core power is spent.
##
## THE OTHER THING THIS SCRIPT ADDS is the Efficient stamp, right after the archetype's spend_actions - so
## the stamp and the spend can never disagree (the frozen helper, roadmap section 4; the Lovers Knot's
## Form of the Myriad does the same inline). The refund itself is the core Kit's action_efficient_refund
## plus the shared passive_efficient_used, both on cp_blackstone_bell.
##
## AI (ruling 14): no ai_behavior_override, so Action.get_ai_behavior returns null and an AI Black
## Mountain never presses it - no behaviour, no hang.
extends ActionSystemApplyBuff

const Efficient := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/efficient/efficient.gd')
const CharacterTarget := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/character_target/character_target.gd')

func spend_actions(activation:EventCore) -> void:
	super(activation)
	Efficient.mark_used(activation.context.gear)

## A drone IS a character (close-out Pass A) and takes this action (author T14): only a drone skips
## vanilla's is_actor() refusal, through the shared helper; everything else is still vanilla's gate.
func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not potential_target.is_drone(): return super(potential_target, specific)
	return CharacterTarget.can_target_drone(self, potential_target, specific)
