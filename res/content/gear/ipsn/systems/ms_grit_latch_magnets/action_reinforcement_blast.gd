## REINFORCEMENT BLAST (Grit Latch Magnets, Fitzgerald rank III): "Spend a charge and choose a Blast 1
## area within Sensors. All characters within the area gain 1 armor until the end of your next turn."
##
## Vanilla ActionSystemApplyBuff does the whole card, configured in the .tres (the armour PAIR, Sensors,
## the Blast 1 target_requirements_override, can_apply_to_self). This script exists for ONE reason:
## a drone IS a character (close-out Pass A), and the author ruled it takes the blast (Pass F T14).
## Vanilla's can_target_unit refuses every non-actor (action_system_apply_buff.gd:64, "cannot apply
## buffs to drones / objects"), and activate re-filters the blast's units through
## specific.action.can_target_unit (:117) - so this override is what lets a drone inside the area
## in. Only a drone takes the shared CharacterTarget helper; objects still get vanilla's refusal.
##
## LIFETIME ON A DRONE (measured, Pass F Task 11): both buffs are until = 7, END_OF_OWNERS_NEXT_TURN,
## skipped while the buff's turn_count <= 0 (unit_condition.gd:62). turn_count rises only when the
## HOLDER starts a turn (event_turn_start.handle_starting_unit -> new_turn_for_statuses), and a drone
## starts its turn only with its owner. So a drone the Fitzgerald OWNS loses the pair on the same
## clock as anyone else, and an UNOWNED drone never loses it - its copies never age, and it keeps the
## armour for the scene. A recorded engine limit, not changed here (the T14 ruling stands); both cases
## are pinned in spec/test_reinforcement_blast.gd.
extends ActionSystemApplyBuff

const CharacterTarget := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/character_target/character_target.gd')

func can_target_unit(potential_target:Unit, specific:SpecificAction) -> bool:
	if not potential_target.is_drone(): return super(potential_target, specific)
	return CharacterTarget.can_target_drone(self, potential_target, specific)
