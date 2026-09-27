## ENTRAP (a Mask of Many Faces mode, design 3.1, rulings 23-25): "As a free action, choose a character
## within sensors and line of sight. They must make a systems save or only be able to draw line of sight
## to adjacent spaces. Targets affected this way always consider you within range, threat, and line of
## sight."
##
## Vanilla ActionSystemApplyBuff, configured in the .tres - Sensors, line of sight, one target, a
## Systems save to avoid, the two buffs on a failure - and FREE, which the engine already limits to
## 1/round (action.gd:156-157). The Leoleth's Combust is the free-action precedent.
##
## THE ONE LINE OF CODE: the action exists only while the Entrap chip is held. Combust's shape - this
## override plus hide_if_disabled in the .tres, which together remove the hotbar button
## (gear_bar.gd:146); either alone leaves it drawn, greyed.
##
## "ANY CHARACTER" is the archetype's own can_target_unit: the Rakshasa's allies too, never a unit
## Hidden from it. STILL never a drone, but not for the "character" word any more (a drone IS one,
## ruling 2026-09-27): the vanilla archetype's own gate refuses any non-actor outright
## (action_system_apply_buff.gd:64, "cannot apply buffs to drones / objects"), unconditionally, before
## this file's own logic is ever reached - orthogonal to what "character" means on this card. A BLINDED
## Rakshasa reaches only an adjacent one, through the Blinded range cap in UnitTile.get_tiles_within
## (unit_tile.gd:579).
##
## The save is forced with the full trifecta (this unit, the core gear, this action), so Worm Code sees
## a failure (ruling 6). NOT TECH, so the core Kit stays non-tech (design 2.1).
extends ActionSystemApplyBuff

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/horus/mf_rakshasa/cp_short_wave_disruptors/short_wave_disruptors.gd')

func is_available_to_activate(unit:Unit, gear:GearCore) -> bool:
	return Core.holds(unit, Core.MODE.ENTRAP) and super.is_available_to_activate(unit, gear)
