## ENSORCEL, the mode chip (a Mask of Many Faces mode, design 3.2, ruling 20). Still the visible chip
## every mode has (short_wave_disruptors.gd), and ALSO a VARIANT_ACTIONS buff: while it is held,
## vanilla Scan offers one blankable variant that swaps Scan for ensorcel_action - Throughbolt Rounds'
## shape (buff_throughbolt_rounds.gd: returning an action from the variant's callable REPLACES the
## action, variant_action_group.gd:119-121). Blankable is the card's "may": the player can always
## Scan as printed.
##
## GATED ON SCAN ITSELF: the vanilla basic Kit ms_scan. Every other action the Rakshasa takes asks
## this buff too (action.gd:187-198) and gets nothing.
##
## THE AI NEVER TAKES IT: a non-player unit composes each group's FIRST entry, the blank one
## (event_gear_activate.gd:83-91). ONCE EVERY ENEMY IS FULLY SCANNED the engine refuses Scan itself
## (action_scan.gd:10-11), and Ensorcel with it - recorded, not fought.
##
## The talents mod's action_scan.gd_ext.gd (a resident) never sees the replacement: it extends
## action_scan.gd, and action_ensorcel is not that script. That fits the card - Ensorcel learns
## nothing. spec/test_compat.gd pins it.
extends Buff

const SCAN_KIT := &'ms_scan'
const VARIANT_KEY := &'ensorcel'

@export var ensorcel_action:Action

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.unit) and GearCore.is_valid(context.gear) and Action.is_valid(context.action)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	return context.gear.kit.compcon_id == SCAN_KIT and context.action == context.gear.get_solo_action()

func get_values(core:BuffCore, context:Context) -> Context:
	var icon:Texture2D = core.base.icon if core.base.icon != null else Action.DEFAULT_ICON
	var title := tr('gear.%s.name' % core.base.compcon_id)
	var text := tr('gear.%s.effect' % core.base.compcon_id)
	var group := VariantActionGroup.create(VARIANT_KEY, title, text, icon,
		true, # blankable: "you MAY take 2 heat"
		true, # logged
	)
	group.append(VariantAction.create(VARIANT_KEY, title, text, icon,
		func(_scan:Action) -> Action: return ensorcel_action.create_duplicate_for_variant()
	))
	return Context.create({ object = group })
