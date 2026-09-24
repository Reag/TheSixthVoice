## RPA PULLBACK, the variant (design ruling 11, the author's): "For the rest of the scene, your
## non-Superheavy weapons may be fired as if they had a line 5 pattern".
##
## A Buff.TO.VARIANT_ACTIONS buff, Siege Ram's buff_siege_ram.gd shape widened from one action to
## every weapon attack: Action.get_alternate_actions (action.gd:187-198) asks every VARIANT_ACTIONS
## buff on the unit for a menu group, with the action about to be activated in the context, so the
## gate below decides per weapon. Blankable ("may"): the player can always fire the weapon as
## printed.
##
## EVERY NON-SUPERHEAVY WEAPON, MELEE INCLUDED (the author, RAW): weapon_size AUX, MAIN or HEAVY.
## Size NONE - the Ram, the Improvised Attack - is not a weapon on the card and is excluded, and so
## is anything SUPERHEAVY.
##
## THE VARIANT SETS THE RANGE PATTERN AND NOTHING ELSE. get_target_range (action_attack_weapon.gd:
## 210-216): a RANGED weapon under a LINE pattern targets at the pattern's value, so picker and line
## agree at 5 with no aim_range edit; a MELEE weapon keeps its threat for the pick and the line is
## drawn 5 long from the attacker toward the picked tile (range_pattern.gd:55-60, AoeCalculator.line),
## ignoring cover as the engine's melee does - recorded, not fought. get_target_requirements
## (:230-236) makes a patterned attack target empty tiles. The composed action carries
## &'rpa_pullback' in modified_by_variants, which the pull buff and the collision reaction key on
## (Throughbolt's buff_throughbolt_line_direction.gd:17). create_duplicate_for_variant (action.gd:
## 94-98) does NOT deep-copy sub-resources, which is why the pull is supplied by a sibling buff
## (buff_rpa_pullback_pull) rather than appended to the duplicate's on_hit_effects here.
##
## AN AI GLOIRE NEVER TAKES IT: event_gear_activate.gd:82-91 composes a non-player's action from the
## groups' first entries, and a blankable group's first entry is "no modification" (ruling 15).
extends Buff

const VARIANT_KEY := &'rpa_pullback'
const KIT_ID := &'cp_retaliation_protocol_amplification'
const LINE_LENGTH := 5
const SIZES:Array[Lancer.WEAPON_SIZE] = [Lancer.WEAPON_SIZE.AUX, Lancer.WEAPON_SIZE.MAIN, Lancer.WEAPON_SIZE.HEAVY]

func is_buff_context_valid_for_passive(core:BuffCore, context:Context) -> bool:
	return Unit.is_valid(context.unit) and Action.is_valid(context.action)

func check_if_passive_applies(core:BuffCore, context:Context) -> bool:
	if not context.action is ActionAttackWeapon: return false
	return SIZES.has(context.action.weapon_size)

func get_values(core:BuffCore, context:Context) -> Context:
	var icon:Texture2D = core.base.icon if core.base.icon != null else Action.DEFAULT_ICON
	var group := VariantActionGroup.create(
		KIT_ID,
		tr('gear.%s.action_rpa_pullback.name' % KIT_ID),
		tr('gear.%s.action_rpa_pullback.effect' % KIT_ID),
		icon,
		true, # blankable: "may be fired as if"
	)
	group.append(VariantAction.create(
		VARIANT_KEY,
		tr('gear.%s.action_rpa_pullback.name' % KIT_ID),
		tr('gear.%s.action_rpa_pullback.effect' % KIT_ID),
		icon,
		func(modified_action:ActionAttackWeapon) -> void:
			modified_action.range_pattern = RangePattern.create(Lancer.AOE_TYPE.LINE, LINE_LENGTH)
	))
	return Context.create({ object = group })
