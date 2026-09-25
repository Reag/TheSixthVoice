# PATIENCE IN ALL THINGS' reduction (design rulings 16-17).
#
#   "1/round, when a hostile character in Line of Sight has rolled an attack roll, you may spend any
#    number of charges to reduce the number rolled by that much."
#
# THE BUFF SITS ON THE HOSTILE, OWNED BY THE PIER. BuffModifyAttackRoll is consulted only on the
# attacker and the defender (event_unit_attack.gd:356-357), so a buff on the Pier could never see a
# hostile's attack on an ally. passive_patience_aura hangs this on every hostile character while the
# Pier holds buff_patience_in_all_things; it applies with applies_when_holder_is = attacker, so it is
# asked only about attacks its holder makes.
#
# turn_hit_to_miss IS THE ONLY STEP THAT CAN MATTER. Reducing a miss changes nothing, and the step is
# asked in prospective_hit (:200) and again in prospective_crit (:225) - so a crit that came through
# Markerlight's hit-to-crit is asked twice, and the &'reag_patience' mark on roll_modifications is
# what stops a second spend on one roll.
#
# confirm_modification IS THE WHOLE MECHANIC. The base returns TRUE for a non-player owner
# (buff_modify_attack_roll.gd:64), which would turn every hostile hit on an AI Pier's side into a
# miss; an AI Pier never spends (mod convention, ruling 19), so the owner check comes first.
#
# WHAT "THE NUMBER ROLLED" IS. Lancer's number rolled is the total; lowering base_roll with it keeps
# the battle log's (base, acc, flat) breakdown honest (log_roll, :400-414) and keeps the roll off the
# auto-hit/auto-miss branch, which is base_roll <= 0 (:400, :418) - hence the clamp to 1.
#
# THE MENU OFFERS ONLY THE SPENDS THAT CHANGE SOMETHING, at their smallest cost (build refinement of
# ruling 17): a crit can be lowered to a plain hit (below 20) or to a miss (below the defence), a hit
# only to a miss. Spending more than the least that reaches an outcome buys nothing - there is no
# threshold between them - and under Patience the leftover charges persist, so a longer list would
# only offer strictly worse picks. No prompt at all when no outcome is affordable.
#
# THE RESULT. Return true and the engine's prospective_miss clears hit and crit (:186-193). Lowering a
# crit to a hit returns FALSE after clearing roll.crit, and prospective_crit's own `if not roll.crit:
# confirmed_hit` (:230) takes it from there. A true return also queues the buff for consumption
# (:379-383), which clears only is_onetime buffs (unit_condition.gd:938) - this one is not.
extends BuffModifyAttackRoll

const Core := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ipsn/mf_grutte_pier/cp_inevitability_core/inevitability_core.gd')

const MARK := &'reag_patience'

func confirm_modification(core:BuffCore, roll:AttackRoll, activation:EventCore) -> bool:
	var context := activation.context
	var pier:Unit = core.get_owner_unit(context.map)
	var attacker:Unit = context.unit
	if not Unit.is_valid(pier) or not Unit.is_valid(attacker): return false
	if not pier.is_player_controlled(): return false
	if roll.base_roll <= 0: return false # an auto-hit never rolled a number
	if roll.roll_modifications.has(MARK): return false
	if not UnitRelation.can_see(pier, attacker): return false

	var gear := Core.core_gear(pier)
	if not GearCore.is_valid(gear): return false
	if gear.get_uses_this_round_alt(Core.PATIENCE_REDUCE_USAGE) > 0: return false

	var options := spend_options(roll, Core.charges(gear))
	if options.is_empty(): return false

	var labels:Array = []
	for option:Dictionary in options:
		labels.append(X.tr('gear.cp_inevitability_core.patience.spend').format({
			n = option.spend,
			total = roll.total_roll - option.spend,
			result = X.tr('event.unit_attack.%s' % option.result),
		}))
	labels.append(X.tr('gear.cp_inevitability_core.patience.decline'))

	var chosen:int = await choice_bus.choose_from_multiple_choice_for({
		brochure = BrochureCore.create({
			title = core.name_text(),
			description = X.tr('gear.cp_inevitability_core.patience.prompt').format({
				unit = attacker.core.get_mech_name(),
				total = roll.total_roll,
				target = roll.target_unit.core.get_mech_name(),
			}),
			choices = labels,
		}),
		can_voluntarily_cancel = true,
	})
	if activation.abort_without_units([pier, attacker]): return false
	if chosen < 0 or chosen >= options.size(): return false

	var spend:int = options[chosen].spend
	Core.set_charges(pier, gear, Core.charges(gear) - spend)
	gear.increment_action_usage(Core.PATIENCE_REDUCE_USAGE)
	roll.roll_modifications.append(MARK)
	lower(roll, spend)

	if roll.total_roll < roll.pre.target_defense: return true # prospective_miss clears hit and crit
	roll.crit = false # lowered below 20 but still a hit: prospective_crit confirms a plain hit
	return false

## "reduce the number rolled by that much": the total AND the d20 together, so anything reading
## `total - (base + accuracy + flat)` - House Guard's other_bonus, the talents mod's
## action_shield_of_the_legion_miss.gd:83 - sees the same difference before and after (test_compat
## pins it). The one exception is the clamp: a base driven below 1 stops at 1 (the auto-hit branch is
## base <= 0), which only a flat bonus big enough to hit off a 1 or 2 could reach.
static func lower(roll:AttackRoll, spend:int) -> void:
	roll.total_roll -= spend
	roll.base_roll = maxi(1, roll.base_roll - spend)

## [{spend:int, result:String}], the least spend that reaches each outcome the roll can be lowered
## to, affordable ones only. `result` is the event.unit_attack.<result> row vanilla's own log uses.
static func spend_options(roll:AttackRoll, charges:int) -> Array[Dictionary]:
	var options:Array[Dictionary] = []
	if not roll.hit or charges <= 0: return options
	var to_miss:int = roll.total_roll - roll.pre.target_defense + 1
	if roll.crit:
		var to_hit:int = roll.total_roll - 19
		if to_hit < to_miss and to_hit <= charges:
			options.append({spend = to_hit, result = 'hit'})
	if to_miss <= charges:
		options.append({spend = to_miss, result = 'miss'})
	return options
