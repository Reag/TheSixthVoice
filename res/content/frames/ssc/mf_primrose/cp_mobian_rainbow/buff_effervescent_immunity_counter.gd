## EFFERVESCENT IMMUNITY, the observer: counts hostile misses and writes the chip's state.
##
## A BUFF RATHER THAN AN ActionReaction, for the Ripper Mod's reason: a reaction pays the per-kit
## reaction allowance and the per-round bookkeeping, and needs a Kit action the player can see in the
## reaction list. A triggered buff has neither, and the card is not a reaction.
##
## ATTACK / POST is the only timing that carries the outcome. event_unit_attack assigns the AttackRoll
## to context.object at :56 and queues the POST reactions at :123, so at this gate context.object is a
## valid AttackRoll and context.object.hit is final - including auto-misses, which
## execute_attack_roll_sequence writes the same way. At PRE the roll does not exist yet.
##
## RULING 6, CLAUSE BY CLAUSE:
##  - "an attack AGAINST YOU": context.target_unit is the holder. ONE event_unit_attack is queued per
##    attacked unit (event_unit_attack_declared.gd:54-64), so an AoE that catches the Primrose counts
##    exactly once however many units it hit.
##  - "a HOSTILE CHARACTER": UnitRelation.are_enemies plus is_character, asked of
##    context.unit.get_attacker(context) and NOT of context.unit - a relayed attack (the Ghast's
##    nexus, Buff.TO.SET_ATTACK_RELAY) puts the relay in context.unit and get_attacker resolves it
##    (unit.gd:276-282). PreAttack.create resolves the same way at attack_roll.gd:122-123.
##  - "FAILS": not context.object.hit.
##  - "weapon or TECH" needs no clause: both go through this one event.
##
## `attacker == unit` IS DEFENSIVE, NOT LOAD-BEARING, and that is measured rather than assumed
## (Task 4 mutation 6, 2026-09-19: neutralising it left the file 12/12 green). are_enemies is
## Faction.is_enemy(unit1.get_faction(), unit2.get_faction()) (unit_relation.gd:361-362) and no
## faction is its own enemy, so the self-attack case - a Blast the Primrose centres on itself and
## misses itself with - is already refused one line below. Kept because it states the intent at the
## point a reader looks for it and costs one reference compare; do not read it as a clause with a
## test behind it.
##
## THE HOLDER IS activation.context.unit, NOT the attacker. ReactionBus builds the activation block
## as {buff, unit = <the buff's holder>, event = <the triggering event>} (reaction_bus.gd:62-67), so
## the attacker that triggers_on_event reads out of the TRIGGERING event's context never appears in
## activate's own.
##
## DOES NOT CALL super IN activate. Buff.activate's default body clears the buff off the unit
## (buff.gd:254-255), and this one has to survive every miss for the whole scene.
## test_the_counter_buff_survives_its_own_activation is the guard. The Ripper Mod's
## buff_ripper_mod_strip_ap.gd carries the same note.
##
## THE OVERFLOW IS RULING 7 and only ever fires under Shimmering Shield: at the base cap of 3 a fourth
## miss does nothing at all, and at the raised cap of 5 a sixth grants 1d3 Overshield through the
## shared helper. Overshield.grant is max-semantics (event_unit_overshield.gd:15 sets
## state.overshield = max(0, max(old, amount)) and NEVER adds), which is exactly what "you instead
## gain 1d3 OVERSHIELD" means - a roll below the current Overshield changes nothing.
extends Buff

const Immunity := preload('res://unpacked/Reag-TheSixthVoice/res/content/frames/ssc/mf_primrose/cp_mobian_rainbow/buff_effervescent_immunity.gd')
const Overshield := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/overshield/overshield.gd')

const CHIP := &'buff_effervescent_immunity'

func get_required_triggering_context() -> Array[Context.PROP]:
	return [
		Context.PROP.unit,         # the attacker, or a relay
		Context.PROP.target_units, # the attacked unit
		Context.PROP.object,       # the AttackRoll
	]

func triggers_on_event(core:BuffCore, unit:Unit, triggering_event:EventCore) -> bool:
	var context:Context = triggering_event.context
	if context.target_unit != unit: return false
	if not Unit.is_valid(context.unit): return false
	var attacker:Unit = context.unit.get_attacker(context)
	if not Unit.is_valid(attacker): return false
	if attacker == unit: return false
	if not attacker.is_character(): return false
	if not UnitRelation.are_enemies(unit, attacker): return false
	if not AttackRoll.is_valid(context.object): return false
	return not context.object.hit

func activate(core:BuffCore, activation:EventCore) -> void:
	var unit:Unit = activation.context.unit
	if not Unit.is_valid(unit): return
	var chip:BuffCore = UnitCondition.get_buff(unit, CHIP)
	if not BuffCore.is_valid(chip): return

	var cap:int = Immunity.cap_for(unit)
	var held:int = chip.get_state(Immunity.STACKS, 0)
	if held < cap:
		chip.set_state(Immunity.STACKS, held + 1)
		# stat_bonus is rebuilt only by update_cached_values (unit_battle_state.gd:229-234); without
		# this the number on the chip would move and the unit's evasion would not.
		unit.update_cached_values_and_token()
		return

	# At the cap. Under Shimmering Shield the overflow becomes Overshield (ruling 7); at the base cap
	# of 3 the card says nothing happens, and nothing does. Gated on "the cap was RAISED", not on
	# the raised value itself (Task 4 review): a later effect that lifts the cap to 4 or 6 would
	# otherwise silently stop the overflow firing, and the chip's cap_for already owns the predicate
	# that decides what raised it.
	if cap > Immunity.BASE_CAP:
		await Overshield.grant(activation, unit, Dice.roll_d3())
