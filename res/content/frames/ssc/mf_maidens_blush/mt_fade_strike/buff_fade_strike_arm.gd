## FADE STRIKE, the arming half: "if the Maiden's Blush begins its turn Invisible".
##
## RULING 7, AND IT IS ONE LINE OF TIMING. event_turn_start.execute_preblock fires NEW_TURN / PRE
## (:14); execute then runs handle_starting_unit, whose UnitCondition.new_turn_for_statuses clears
## START_OF_TURN statuses (unit_condition.gd:21); NEW_TURN / POST is queued after all of that. So a
## fade that lasts "until the beginning of its next turn" - which is exactly what Uncertainty Field
## applies - is visible at PRE and gone at POST. The author took the reading in which the frame's own
## kit chains: teleport, fade through the enemy turn, reroll the first melee strike.
##
## "INVISIBLE" IS THE STATUS ONLY (ruling 7). unit.has_status, not UnitCondition.is_invisible: a
## TREAT_AS_INVISIBLE buff the mech holds - the Banshee's tear, or the chip SP2's Step hangs on a
## fooled character - is not "being Invisible", and is_invisible would count it.
##
## THE CHIP IS AN @export RATHER THAN A CONTENTLIBRARY LOOKUP BY ID, the Strike and Fade shape
## (action_strike_and_fade_operator.gd:4-5): the reference is then declared in the .tres, where a
## missing file fails loudly at load instead of silently at the first turn start.
##
## A BUFF RATHER THAN A REACTION (design §0.2): Action.show_in_tooltip returns true for any trait
## reaction whose Kit carries a trigger row, and this trait's card already says everything. A buff
## subscribes to the same bus (reaction_bus.gd:61-67) and advertises nothing - which is why
## mt_fade_strike carries no action at all.
##
## activate() DOES NOT CALL super(): Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to arm every turn for the whole scene.
extends Buff

## The chip this hangs. Set on the .tres.
@export var chip:Buff

## NEW_TURN carries the unit whose turn is starting, and that is all this reads.
func get_required_triggering_context() -> Array[Context.PROP]:
	return [Context.PROP.unit]

func triggers_on_event(_core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	if not Unit.is_valid(unit) or chip == null: return false
	# OUR turn, not everybody's. The bus polls every unit's buffs on every trigger with the same
	# event, and NEW_TURN fires for every turn on the map.
	if triggering_event.context.unit != unit: return false
	# Already holding an UNSPENT chip: leave that one alone. This is NOT a stacking guard - the engine
	# precludes a second copy by itself, because multiple_copies_can_stack is false (buff.gd:131, unset
	# on the .tres) and apply_buff_alt clears any same-id, same-source, same-`to`, same-`until` copy
	# before appending the new one (unit_condition.gd:741-747). What this line decides is that a turn
	# start which finds the chip still in hand keeps THAT BuffCore rather than swapping in a fresh one
	# and flickering the visible token. A chip the turn has already SPENT is gone from unit.state.buffs,
	# so this reads false and the trait re-arms exactly as it should.
	if UnitCondition.has_buff(unit, chip.compcon_id): return false
	return unit.has_status(Lancer.STATUS.INVISIBLE)

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit) or chip == null: return
	UnitCondition.apply_buff(activation, unit, chip, core.get_owner_gear(activation.context.map))
