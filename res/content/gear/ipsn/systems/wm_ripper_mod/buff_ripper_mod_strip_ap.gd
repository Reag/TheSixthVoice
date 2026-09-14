## RIPPER MOD, second clause: "Attacks made with this weapon lose AP and cannot gain AP by any means."
##
## WHY THIS IS A BUFF AND NOT A TAG. Weapon tags are ADD-ONLY - add_tag_to_collection
## (action_attack_weapon.gd:129-137) never deletes a key - and both readers of the AP tag sit in a
## class_name script (event_unit_attack_declared.gd:80 and :249), so nothing on the tag side can take
## AP away. But the tag is not what armor reads. The declared attack turns it into
## EventService.DAMAGE_FLAG.AP on each damage event's context, and event_unit_damage.gd's
## execute_preblock then does, in order:
##
##     prelim = DamageModifications.create(unit, amount, context)     # :52, reads context.flags
##     await core.execute_reaction_events(TRIGGER.DAMAGE, TIMING.PRE) # :59, brace, black witch, ...
##     final  = DamageModifications.create(unit, amount, context)     # :63, reads context.flags AGAIN
##
## and damage_modifications.gd:103 only skips armor when the FINAL read still carries the flag. The
## reaction bus fires triggered BUFFS as well as reactions (reaction_bus.gd:61-67), on EVERY unit's
## buffs rather than only the victim's - so this buff, sitting on the ATTACKER, runs between the two
## reads with the damage event in hand. The Bastion's buff_deathcounter_bastion.gd is the vanilla
## precedent for a PRE buff mutating the triggering damage event. Spike 10 probed all of this before
## a line of it shipped: D:\DEV\lancer-tactics-claude\specs\2026-09-13-ap-strip-feasibility.md.
##
## "CANNOT GAIN AP BY ANY MEANS" COSTS NOTHING EXTRA. This runs after every source of AP has already
## written the flag, so an AP granted by another buff is erased by the same line.
##
## A BUFF RATHER THAN A HIDDEN ActionReaction, though both reach the trigger: a reaction pays the
## per-kit reaction allowance and the per-round bookkeeping, and needs a Kit action the player can
## see in the reaction list. A triggered buff has neither.
##
## WHAT THIS DELIBERATELY DOES NOT REACH, both ruled 2026-09-13: the weapon card still shows the AP
## tag (display only - the battle log's damage line at event_unit_damage.gd:162 reads the stripped
## flag and correctly omits it); and damage to TERRAIN keeps its AP, because that goes through
## event_map_damage, a different event with no gear in its context and no DAMAGE trigger. Damage to
## an OBJECT does come through here and loses its AP, which is the reading the author took.
##
## CITATIONS CORRECTED FROM THE TASK BRIEF against the 1.4.3 tree: the brief wrote
## action_attack_weapon.gd:130-138 (the function opens at 129), event_unit_damage.gd:53-70 (the three
## lines that matter are 52/59/63) and reaction_bus.gd:60-68 (the buff loop is 61-67).
extends Buff

const RipperBonus := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/ipsn/systems/wm_ripper_mod/buff_ripper_mod_bonus.gd')

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.gear, Context.PROP.object]

## The damage event's `target_unit` is WHO DEALT the damage, not who is taking it
## (event_unit_damage.gd:35 declares it that way and :83 reads it as `damaging_unit`), so this is the
## check that the holder of this buff fired the shot. `object` is the AttackRoll, which is what
## distinguishes an attack's own damage from burn, heat, a fall, or another system's flat damage -
## the card says "attacks made with this weapon".
func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context := triggering_event.context
	if not context.flags.has(EventService.DAMAGE_FLAG.AP): return false
	if not AttackRoll.is_valid(context.object): return false
	if context.target_unit != unit: return false
	return RipperBonus.is_modded_weapon(context.gear, unit, core.from_gear)

## Does NOT call super. Buff.activate's default clears the buff off the unit (buff.gd:254-255), and
## this one has to outlive every shot for the whole scene - test_the_strip_buff_survives_the_shot is
## the guard.
func activate(core:BuffCore, activation:EventCore) -> void:
	activation.context.event.context.flags.erase(EventService.DAMAGE_FLAG.AP)
