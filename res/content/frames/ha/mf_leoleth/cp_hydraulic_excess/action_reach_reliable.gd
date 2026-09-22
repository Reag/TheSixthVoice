# REACH's Reliable half, AS BUILT (author's ruling, design §1.5.5; rulings.md last row).
#
#   "3 Reach: Your melee weapons gain +1 Threat and Reliable 2."
#
# WHY THIS IS A REACTION AND NOT A BUFF, MEASURED AT SP1 TASK 9. The obvious shape - a
# BuffWeaponTypeTag adding &'reliable' - reaches get_weapon_tags and NOTHING ELSE. The damage floor is
# read ONCE, from the action's own export, at
# content/events/event_unit_attack/event_unit_attack_declared.gd:82
# (`base_damage.reliable = unit.get_tiered_int(action.reliable_damage)`), and a miss pays out exactly
# that int and nothing else (attack_util.gd:120-126, `get_miss()` returns { primary_type: reliable }).
# Nothing writes DamageRollSummary.reliable again - :108 copies it, :177 zeroes it for bonus damage -
# and Buff.TO has no channel for it. Measured: with the tag buff up, get_weapon_tags read
# { &"reliable": 2 } while a miss with a Reliable-0 melee weapon still landed 0, and mutating the
# BUFF's arithmetic to a flat 2 reddened NOTHING at all. No vanilla buff or weapon mod grants
# RELIABLE anywhere, which is why the dead path was never noticed.
#
# SO THE TAG BUFF STAYS FOR THE CARD and this reaction pays the difference. buff_rage_reach_reliable
# makes the weapon's tooltip read "Reliable 2"; this makes a miss actually land it.
#
# ActionReactionAttacked, NOT ActionReactionSelf, because the archetype's own gate is four of our five
# clauses and every one of them is declarative in the .tres: require_unit_to_be = ATTACKER (the
# Leoleth swung), require_miss (the resolved AttackRoll in the triggering context's `object`, checked
# at action_reaction_attacked.gd:105-112 and only reachable at POST), weapon_types = [MELEE] - which
# IS UnitAction.is_melee_weapon, letter for letter (unit_action.gd:549-553 is
# `action is ActionAttackWeapon and action.is_weapon_type(MELEE, gear)`) - and allow_basic false.
# Only the chip and the printed-Reliable clauses need script.
#
# THE SHORTFALL, NOT THE TARGET VALUE: 2 - printed, and the gate refuses the reaction outright when
# printed is already 2 or more. A chain axe (printed 2) and a nanocarbon sword (printed 3) therefore
# see nothing at all - the higher stands, which is Lancer's rule and the design's own spec list.
#
# CommonActionUtil.queue_damage_events RATHER THAN A BARE event_unit_damage, and that is the whole
# point of the choice: handed a SpecificAction it copies `gear` and `action` onto the damage event
# (common_action_util.gd:97-99), so armor, resistance and every BuffResistDamage that keys on
# context.action read this exactly as they read the weapon's own printed Reliable payout. A bare
# event_unit_damage (the Aegis defense net's shape, action_defense_net_aegis_miss.gd:38-45) carries
# neither, and would make the shortfall a different kind of damage from the thing it is topping up.
#
# ORDERING, READ OFF THE ENGINE. event_unit_attack queues ATTACK POST at :123, inside the per-target
# event; event_unit_attack_declared rolls and applies damage only after ALL the per-target events
# have returned (:67, then its "ROLL DAMAGE" block). So this shortfall lands BEFORE the attack's own
# printed-Reliable payout. That payout is 0 whenever this reaction fires - the gate says printed < 2 -
# so the two never compound, and nothing here depends on their order.
#
# HIDDEN. show_in_tooltip is false, so the action never reaches a player-facing surface, takes no
# icon of its own and gets NO ICON_TARGETS row - the same treatment action_all_systems_red and
# action_rage_roll get, asserted in reverse by test_content_integrity's
# _action_reaches_a_player_facing_surface. The battle log still names it, so it carries a `.name` row
# and no `.effect` row: the chip beside it already carries the card line.
extends ActionReactionAttacked

## The value the card promises. The reaction pays the difference between this and the weapon's print.
const RELIABLE_TARGET := 2

const REACH_CHIP := &'buff_rage_reach'

func show_in_tooltip(_kit:Kit) -> bool: return false

func triggers_on_event(unit:Unit, gear:GearCore, triggering_event:EventCore) -> bool:
	if not super.triggers_on_event(unit, gear, triggering_event): return false
	# "Your melee weapons gain ...": only while this turn's face is a 3.
	if not UnitCondition.has_buff(unit, REACH_CHIP): return false
	return shortfall_for(unit, triggering_event.context.action) > 0

## 2 minus what the weapon already prints, floored at zero.
##
## READ THE EXPORT, exactly as event_unit_attack_declared.gd:82 reads it. get_weapon_tags would
## recurse into the very buff this reaction stands beside, and would also fold in weapon mods, which
## are not on the weapon's card.
func shortfall_for(unit:Unit, action:Action) -> int:
	if not (action is ActionAttackWeapon): return 0
	return maxi(0, RELIABLE_TARGET - unit.get_tiered_int(action.reliable_damage))

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	var triggering_context:Context = context.event.context
	var target:Unit = triggering_context.target_unit
	if not Unit.is_valid(unit) or not Unit.is_valid(target): return

	var weapon:Action = triggering_context.action
	var shortfall:int = shortfall_for(unit, weapon)
	if shortfall <= 0: return

	# AP travels with it, for the same reason gear and action do: a Reliable payout from an AP weapon
	# is AP (event_unit_attack_declared.gd:80-82 sets both off the same action).
	var flags:Array = []
	if weapon.has_tag(Lancer.WEAPON_TAG.AP, triggering_context):
		flags.append(EventService.DAMAGE_FLAG.AP)

	await CommonActionUtil.queue_damage_events(
		activation,
		SpecificAction.create(unit, triggering_context.gear, weapon),
		[target] as Array[Unit],
		shortfall,
		weapon.get_damage_type(triggering_context.gear),
		flags,
	)
