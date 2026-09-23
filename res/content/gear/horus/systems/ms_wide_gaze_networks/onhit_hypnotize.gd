## HYPNOTIZE'S SCAN (Naga SP2 Task 2, ruling 12): "You may immediately scan the target."
##
## Scanpedia.scan directly, the Athena's shape - NOT the Scan action, which the resident talents mod
## extends (action_scan.gd_ext.gd, the design's Contested seams line). The "may" is not prompted: a
## scan only reveals, and Hypnotize scanning first is what makes the lower defence knowable at all.
## It pops vanilla Scan's own text (action_scan.gd:32), so the player sees the scan happen.
extends OnHitEffect

static var effect_bus:EffectsControllerBus = load('res://engine/gamemaster/effects_controller/effects_controller_bus.tres')

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	if not Unit.is_valid(attacked_unit): return
	Scanpedia.scan(attacked_unit)
	effect_bus.play_text(tr('gear.ms_scan.action_scan.pop'), attacked_unit.tile())
