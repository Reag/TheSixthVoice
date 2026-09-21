# ALL SYSTEMS RED (ruling 6), the passive half of HYDRAULIC EXCESS:
#
#   "When you would structure, you do not take any overflow damage and gain the benefits of hard
#    cover until the end of the current turn."
#
# A HIDDEN, POINT-FREE ActionReactionSelf on `structured` at PRE. Two lines of body, and the PRE is
# the whole ability.
#
# OVERFLOW IS THE NEGATIVE HP, and there is no other number to suppress. event_unit_structure.execute
# decrements the structure bar (:41) and then folds (:44):
#   health = mini(health + get_health_max(), get_health_max())
# so a unit sitting at -4 comes out of that at 4. Zeroing the -4 first makes it come out at full.
# STRUCTURED PRE is awaited in execute_preblock (:33-34), which is the only window before the fold -
# and which the resident gavstarb-talents_1st_party extension does NOT override (it replaces `execute`
# wholesale for its reroll buffs). Task 0's probe measured all of that, under the resident, and
# spec/test_compat.gd re-states it against THIS reaction in Task 13.
#
# AND THERE IS THEN NO CHAIN. event_unit_structure re-queues itself only while current.health <= 0
# (:89-90), which the zeroing has already made false. Ruling 6 says the reaction fires on every
# structure event including a chained one; with the overflow gone there is nothing to chain.
#
# THE GUARD IS `< 0`, NOT `<= 0`. A unit brought to exactly zero took no overflow and needs no
# zeroing; writing 0 over 0 is harmless but says something untrue about what the card does.
#
# HARD COVER IS A FLOOR. Cover is resolved max-then-zero by CoverCalculator (cover_calculator.gd:56-62
# collects every Buff.TO.COVER buff on defender and attacker), so this chip can only ever RAISE what a
# roll sees. An attacker with IGNORE_COVER still ignores it - PreAttack.create skips the whole cover
# block when any ignore-cover buff is present (attack_roll.gd:153-157) - which is the engine's rule
# and not this card's business.
#
# HIDDEN, because the core Kit's own `effect` row IS this card and a second line under it would say
# the same thing twice. Note that Action.show_in_tooltip would return false here anyway, for want of
# an `effect` row of its own (action.gd:350-353); the override is explicit so a later CSV row cannot
# quietly put this reaction on the card.
extends ActionReactionSelf

const COVER_CHIP := &'buff_all_systems_red_cover'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func show_in_tooltip(_kit:Kit) -> bool: return false

func activate(context:Context, activation:EventCore) -> void:
	var unit:Unit = context.unit
	if not Unit.is_valid(unit): return
	# "you do not take any overflow damage"
	if unit.core.current.health < 0: unit.core.current.health = 0
	# "and gain the benefits of hard cover until the end of the current turn"
	apply_buff_id(activation, unit, COVER_CHIP)
