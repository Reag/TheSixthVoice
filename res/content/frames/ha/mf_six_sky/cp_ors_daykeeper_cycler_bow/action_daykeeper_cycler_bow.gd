## DAYKEEPER CYCLER BOW (the Six Sky's integrated weapon; design 2.1, rulings 12-14, 17, 18):
##
##   Main Launcher, HEAT SELF 1, OVERKILL, 1d6+3 Energy, Range 10.
##   "This weapon gains +1 Accuracy against targets within Range 5."
##   On crit: "Choose yourself or the target to be immediately teleported to a free space within Range 2
##   of their space."
##
## THE ACCURACY (ruling 13) is the weapon's own modify_pre_attack_data, the last word on the roll
## (attack_roll.gd:192), as a NAMED line in the breakdown - Shatterhead's shape. It has to live here and
## not in get_attack_accuracy, which is handed only the gear and cannot see the target
## (action_attack.gd:31). Measured from the ATTACKER's space at roll time, so a Ritual shot measures from
## where the Ritual teleport put the Six Sky.
##
## NO HEAT IN A RITUAL (ruling 18). The Ritual fires this bow with Action.FLAG.NO_SELF_HEAT, which the
## engine honours for Heat Self at spend (unit_action.gd:226-227) and NOWHERE else - so this script reads
## the same flag as "no heat at all" and answers is_overkill false, which is the only gate on the
## Overkill heat event (event_unit_attack_declared.gd:173-178). apply_overkill is OVERRIDDEN to test the
## TAG instead, because vanilla's gates the rerolls on is_overkill too (action_attack_weapon.gd:259-260):
## without the override a Ritual shot would stop rerolling 1s, which the card never says. Any other
## mod's freebie that passes NO_SELF_HEAT to this bow gets the same reading.
##
## THE CRIT (ruling 14) resolves at once, in on_crit - UNLESS a Ritual is running (ruling 17, the
## author's): then the crit is only RECORDED on the Ritual's scope buff, and the Ritual resolves every
## record after its last attack, through the same resolve_crit_teleport. "Inside a Ritual" is the scope
## buff held AND this shot carrying NO_SELF_HEAT (buff_ritual_of_the_first_god.gd's live_scope), so an
## Overwatch fired mid-sequence resolves its own crit at once, like any other shot.
##
## YOURSELF is the PREVENTABLE route (the helper's pathfinder + move_along): Immobilized and a
## MOVEMENT_RESTRICTION ban both stop it, since the self-teleport is the Six Sky's own voluntary choice.
## THE TARGET is Teleport.shove - involuntary, so Immobilized does not stop it and a ban does
## (teleport.gd's four-way table). Both carry the calling activation's SpecificAction, so the forcer is
## the Six Sky and Heavenly Weaver and Starsickness see the teleport as its own.
##
## AN AI-CONTROLLED SIX SKY SKIPS THE MENU: no teleport at all. The choice is a player's, and an AI
## choosing a space would need a scoring pass this card does not justify.
extends ActionAttackWeapon

const Teleport := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/teleport/teleport.gd')
const RitualScope := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ha/mf_six_sky/cp_ors_daykeeper_cycler_bow/buff_ritual_of_the_first_god.gd')

const BOW_ID := &'mw_daykeeper_cycler_bow'
const CLOSE_RANGE := 5
const CRIT_TELEPORT_RANGE := 2
const CHOICE_SELF := 0
const CHOICE_TARGET := 1

func modify_pre_attack_data(context:Context, pre_attack_data:AttackRoll.PreAttack) -> void:
	super.modify_pre_attack_data(context, pre_attack_data)
	var attacker:Unit = context.unit.get_attacker(context)
	if not Unit.all_valid([attacker, context.target_unit]): return
	if UnitRelation.distance_between(attacker, context.target_unit) > CLOSE_RANGE: return
	pre_attack_data.add_mod(name(SpecificAction.create(attacker, context.gear, self)), 1, get_icon())

func is_overkill(context:Context) -> bool:
	if context != null and context.flags.has(Action.FLAG.NO_SELF_HEAT): return false
	return super.is_overkill(context)

## Vanilla's body with the gate on the TAG rather than on is_overkill - see the header.
func apply_overkill(damage_roll:AttackUtil.DamageRoll, activation:EventCore) -> void:
	if not has_tag(Lancer.WEAPON_TAG.OVERKILL, activation.context): return
	damage_roll.overkill_heat_on_hit = AttackUtil.DamageRoll.modify_rolls_for_overkill(damage_roll.hit_rolls, damage_roll.dietype)
	damage_roll.overkill_heat_on_crit = (
		damage_roll.overkill_heat_on_hit +
		AttackUtil.DamageRoll.modify_rolls_for_overkill(damage_roll.crit_rolls, damage_roll.dietype)
	)

func on_crit(activation:EventCore, attacked_unit:Unit) -> void:
	await super.on_crit(activation, attacked_unit)
	var context := activation.context
	var six_sky:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(six_sky): return
	var scope:BuffCore = RitualScope.live_scope(six_sky, context)
	if scope != null:
		RitualScope.record_crit(scope, attacked_unit) # resolved by the Ritual, after its last attack
		return
	await resolve_crit_teleport(activation, six_sky, attacked_unit)

## The Six Sky's bow, as a SpecificAction, or null.
static func bow_of(six_sky:Unit) -> SpecificAction:
	if not Unit.is_valid(six_sky): return null
	var gear:GearCore = six_sky.get_gear(BOW_ID)
	if not GearCore.is_valid(gear) or gear.kit.actions.is_empty(): return null
	return SpecificAction.create(six_sky, gear, gear.kit.actions.front())

## Rule 14's menu, then the pick, then the teleport. Shared by the immediate crit and the Ritual's
## deferred ones. `target` may be dead by now (a deferred crit): then only "yourself" is offered.
static func resolve_crit_teleport(activation:EventCore, six_sky:Unit, target:Unit) -> void:
	if not Unit.is_valid(six_sky): return
	if not six_sky.is_player_controlled(): return
	var bow := bow_of(six_sky)
	if not SpecificAction.is_valid(bow): return

	var options:Array = [Translate.gear(BOW_ID, 'crit_self')]
	if Unit.is_valid(target): options.append(Translate.gear(BOW_ID, 'crit_target'))
	var chosen:int = await choice_bus.choose_from_multiple_choice(bow, options, true)
	if chosen < 0 or not Unit.is_valid(six_sky): return

	if chosen == CHOICE_SELF: await teleport_self(activation, bow, six_sky)
	elif chosen == CHOICE_TARGET and Unit.is_valid(target): await teleport_target(activation, bow, target)

## Yourself: the preventable route, over every free space within 2.
static func teleport_self(activation:EventCore, bow:SpecificAction, six_sky:Unit) -> void:
	var tiles := Teleport.candidate_tiles(six_sky, CRIT_TELEPORT_RANGE, false)
	if tiles.is_empty(): return
	var pathfinder:Pathfinder = await Teleport.pathfinder(six_sky, tiles)
	if not Unit.is_valid(six_sky): return
	if pathfinder == null or pathfinder.valid_destinations.is_empty(): return # Immobilized, or banned
	var plan:CompconPlan = await TargetActionUtil.ask_for_movement(bow.to_context(), pathfinder)
	if plan == null or plan.aborted or plan.move_path.is_empty(): return # cancelled
	if not Unit.is_valid(six_sky): return
	await Teleport.move_along(activation, six_sky, pathfinder, plan)

## The target: the helper's reticle over every free space within 2 of ITS space, then the shove.
static func teleport_target(activation:EventCore, bow:SpecificAction, target:Unit) -> void:
	var tiles := Teleport.candidate_tiles(target, CRIT_TELEPORT_RANGE, false)
	if tiles.is_empty(): return
	var tile:Vector2i = await Teleport.pick_tile(bow.to_context(), activation, tiles)
	if tile == Tile.INVALID: return # cancelled
	if not Unit.is_valid(target): return
	await Teleport.shove(activation, target, tile)
