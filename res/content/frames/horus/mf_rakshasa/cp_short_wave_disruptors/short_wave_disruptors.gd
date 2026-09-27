## SHORT WAVE DISRUPTORS: what the Mask of Many Faces menu and its modes share (design section 2).
##
## The five modes IN CARD ORDER. The menu's button index is the mode, the AI's rotation walks this
## order (ruling 14), and each mode is one visible chip on the Rakshasa, until = START_OF_TURN (ruling
## 15). A mode is "held" exactly while its chip is, so every mode's reaction gates on its chip and
## nothing else has to be torn down at the next turn start.
##
## The core gear's state carries the two things a chip cannot: the last mode chosen (ruling 13: "two
## turns in a row" is the Rakshasa's own turns, and repair clears state, so a scene starts free) and
## the Soulbind partner's persistent id (ruling 18, Symbiosis' own fused_unit shape).
##
## Static functions, no state. Preloaded by every action on the core Kit.
extends RefCounted

const CORE_ID := &'cp_short_wave_disruptors'

enum MODE { DRAIN, ENTRAP, STABILIZER_OVERRIDE, SOULBIND, ENSORCEL }
const CHIPS:Array[StringName] = [
	&'buff_mask_drain',
	&'buff_mask_entrap',
	&'buff_mask_stabilizer_override',
	&'buff_mask_soulbind',
	&'buff_mask_ensorcel',
]
const NO_MODE := -1

const LAST_MODE_KEY := 'mask_last_mode'
const PARTNER_KEY := 'soulbind_partner'

static func holds(unit:Unit, mode:int) -> bool:
	return Unit.is_valid(unit) and UnitCondition.has_buff(unit, CHIPS[mode])

static func last_mode(gear:GearCore) -> int:
	return int(gear.get_state(LAST_MODE_KEY, NO_MODE))

## "Choose a character within Sensors": every other ACTOR (a drone is not a character, rulings row
## 301) whose distance is within the Rakshasa's live Sensors. No line of sight - the card asks none.
static func soulbind_candidates(unit:Unit) -> Array[Unit]:
	var candidates:Array[Unit] = []
	if not Unit.is_valid(unit): return candidates
	var sensors:int = unit.get_sensor_range()
	for other:Unit in unit.map.get_all_characters():
		if other == unit or not Unit.is_valid(other) or not other.is_character(): continue
		if UnitRelation.distance_between(unit, other) > sensors: continue
		candidates.append(other)
	return candidates

## The bound partner, or null when there is none or it is dead or off the map (ruling 18: the bond
## ends early if either dies). Unit.is_valid is alive-gated.
static func partner(unit:Unit, gear:GearCore) -> Unit:
	if not Unit.is_valid(unit) or not GearCore.is_valid(gear): return null
	var bound:Unit = unit.map.get_unit_by_id(gear.get_state(PARTNER_KEY, &''))
	return bound if Unit.is_valid(bound) else null
