## The Bizarre Cannon's SECOND profile, unlocked for the rest of the scene by the MORE BLACK POWDER
## protocol (design §2.5, ruling 8).
##
## "Heavy Cannon, AP, Reliable 3, Heat 1 (Self). [Line 15] [2d6 kinetic + 1d6 explosive].
##  On attack: you take 3 AP kinetic damage and are knocked back 3 spaces, in any direction.
##  On hit: targets must succeed on a Hull save or become prone."
##
## Ruling 8 is why this is an ADDITIONAL action on cp_broadside rather than a rewrite of the base
## profile: both stay firable once the marker is held, and the 2-versus-3 self-damage choice is the
## point of the ability on a 6 HP frame.
##
## WHAT IS AND IS NOT OVERRIDDEN. Everything the profile says about STATISTICS - the dice, the tags,
## the explosive rider, the Hull save against prone, and the two recoil magnitudes - lives in
## action_more_black_powder.tres, because action_bizarre_cannon.gd exports `recoil_damage_dice` and
## `recoil_knockback` as resource data and its activate() reads them off `self`. So this script
## deliberately does NOT override activate(): calling `super.activate()` would run the attack AND the
## recoil correctly, but any attempt to "adjust" the numbers around it would double the recoil, and
## reaching past the parent to ActionAttackWeapon.activate() would skip the recoil altogether. One
## inherited activate(), two .tres files, no arithmetic in code.
##
## Extended BY PATH because action_bizarre_cannon.gd has no class_name (it is mod content; a
## class_name would collide across mods and cannot be extended reliably - see CLAUDE.md).
extends "res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_fitzgerald/cp_broadside/action_bizarre_cannon.gd"

## The scene-long marker the MORE BLACK POWDER protocol applies. While the Fitzgerald does not carry
## it, this profile does not exist.
const MARKER_ID:StringName = &'buff_more_black_powder'

## "...knocked back 3 spaces, IN ANY DIRECTION."
##
## The base profile measures its shove away from the far end of the line it just fired. This one
## hands the knockback its OWN tiles instead, and that is what opens the pick in every direction:
## event_unit_pick_move.gd:87-93 filters the moving unit's own tiles out of the knockback origins,
## finds nothing left, and falls through to offering every tile within the knockback distance rather
## than a cone angled away from an origin.
##
## Returning [] would reach the same branch by a different road - generate_knockback_events defaults
## an empty origin array to the acting unit's tiles (common_action_util.gd:132) - but
## action_bizarre_cannon.recoil() treats an empty array as "we could not work out which way we fired"
## and skips the shove entirely. Asking for the all-directions cone explicitly is the difference
## between the rule and a silent no-op.
func recoil_origin_tiles(context:Context) -> Array[Vector2i]:
	if not Unit.is_valid(context.unit): return []
	return context.unit.occupied_tiles()

## Hidden until the protocol has been used, rather than greyed out.
##
## This is the SPECIFIC leg of UnitAction.get_gear_unavailable_reason (unit_action.gd:156); paired
## with `hide_if_disabled = true` on the .tres, gear_bar.gd:147 drops the button from the bar
## altogether instead of drawing a dead one. Signature is (unit, gear) - Action.is_available_to_
## activate(unit, gear), action.gd:175 - not the SpecificAction the plan guessed at.
##
## Source-agnostic on purpose: has_buff's third argument would restrict the marker to the gear that
## applied it, and the marker is applied by the protocol on this same Kit, so scoping it would buy
## nothing and would break if the protocol ever moved.
func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	if not UnitCondition.has_buff(unit, MARKER_ID): return false
	return super(unit, gear)
