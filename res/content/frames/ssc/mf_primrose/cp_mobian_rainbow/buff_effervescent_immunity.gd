## EFFERVESCENT IMMUNITY, the chip: the Primrose's running evasion bonus, and the number on it.
##
##   "Each time a hostile character fails an attack against you, gain +1 EVASION for the rest of the
##    scene up to a maximum of +3."
##
## THE STATE IS THE WHOLE MECHANISM. A counter in buff state avoids stacking altogether - the
## alternative, one chip per stack, is three chips for one effect and unreadable on the unit
## (ruling 6). buff_effervescent_immunity_counter.gd writes `stacks`; this file only reads it.
##
## THE CAP LIVES HERE AND NOT IN THE COUNTER, because two callers need the same answer: the counter,
## deciding whether to increment or to overflow into Overshield, and get_values, clamping what it
## reports. cap_for() is the single place the Shimmering Shield clause is read.
##
## Buff.TO.STATBLOCK, so the bonus lands in state.stat_bonus and every reader of evasion sees it:
## Unit.get_evasion is core.get_evasion() + state.stat_bonus.evasion (unit.gd:306), and
## AttackUtil.calculate_target_defense reads that accessor. Unlike armor, evasion has no second
## pipeline read to miss (ruling 21). Stunned still caps evasion at 5, which is the engine's rule and
## not ours.
##
## stat_bonus IS REBUILT ONLY BY update_cached_values (unit_battle_state.gd:229-234), so
## on_application refreshes it once here and the counter refreshes it after every increment. The
## Goblin's buff_symbiosis_statblock.gd does exactly this, and its own comment says why: "we don't
## naturally update the state cache on status-less buff applications".
##
## get_values IS CALLED WITH A BARE CONTEXT. unit_battle_state.gd:232 calls buff.get_values() with no
## argument, so BuffCore.get_values builds Context.create({}) and context.map falls back to X.map()
## (context.gd:76-80). get_owner_unit(context.map) therefore resolves through the live map, which is
## the same fallback buff_gravity_well.gd relies on and its spec records.
##
## THE OWNER IS THE HOLDER HERE, deliberately: the chip is applied by the Primrose's OWN core Kit
## through its PassiveBuffApplicator, so BuffCore.from_gear names gear on the Primrose and
## get_owner_unit finds the Primrose. get_holder_unit would give the same answer at a cost of one
## scan over every unit on the map (buff_core.gd:129-133), on every stat refresh.
extends Buff

## The buff-state key the counter writes and get_values reads. A String, because BuffCore.set_state
## and get_state both take key:String (buff_core.gd:138-145).
const STACKS := 'stacks'

## The card's own maximum, and Shimmering Shield's raised one.
const BASE_CAP := 3
const SHIELDED_CAP := 5

## The marker whose presence raises the cap. Read BY ID so this file stays ignorant of the content
## that applies it - Shimmering Shield does not exist until SP1 Task 5, and UnitCondition.has_buff on
## an id nothing has applied simply returns false.
const SHIMMERING_SHIELD := &'buff_shimmering_shield'

## The maximum this unit's bonus can reach right now. PUBLIC: the counter and test_shimmering_shield
## both call it.
static func cap_for(unit:Unit) -> int:
	if Unit.is_valid(unit) and UnitCondition.has_buff(unit, SHIMMERING_SHIELD): return SHIELDED_CAP
	return BASE_CAP

## How many stacks this unit's chip is carrying, or 0 if it has no chip. PUBLIC: every spec in this
## sub-project reads the counter through it rather than reaching into buff state by hand.
static func stacks_on(unit:Unit) -> int:
	if not Unit.is_valid(unit): return 0
	var core:BuffCore = UnitCondition.get_buff(unit, &'buff_effervescent_immunity')
	if not BuffCore.is_valid(core): return 0
	return core.get_state(STACKS, 0)

func get_values(core:BuffCore, context:Context) -> Context:
	var block := Statblock.new()
	block.evasion = mini(core.get_state(STACKS, 0), cap_for(core.get_owner_unit(context.map)))
	return Context.create({ object = block })

## The card text carries the CURRENT bonus, which is what makes one chip with a number legible where
## three stacked chips would not be (ruling 6).
##
## super(core) is Buff.effect_text, which reads gear.buff_effervescent_immunity.effect and then runs
## String.format over it with the owner gear's die counters - an EMPTY dictionary here, since this Kit
## has no PassiveDieCounter - and then Util.process_all_tiers. Neither touches `{bonus}`:
## format with an empty dictionary substitutes nothing, and TIER_REGEX only matches a braced group
## containing two slashes (util.gd:383). So the second format below is what fills it.
func effect_text(core:BuffCore) -> String:
	var held:int = mini(core.get_state(STACKS, 0), cap_for(core.get_owner_unit()))
	return super(core).format({bonus = held})

## stat_bonus is rebuilt only by update_cached_values, and a status-less buff application does not
## trigger one - so without this the chip would report a bonus the unit does not have until something
## else happened to refresh the cache.
func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
	unit.update_cached_values_and_token()
