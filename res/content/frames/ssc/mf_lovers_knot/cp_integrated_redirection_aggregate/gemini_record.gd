## GEMINI CHARGE's shared bookkeeping (design 2, rulings 7-16): what the four Gemini buffs agree on.
##
## THE RECORD LIVES ON THE DECLARED ATTACK. buff_gemini_charge writes it onto the DeclaredAttackSummary
## at ATTACK_DECLARED PRE, the moment a redirect is committed, and the three permanent hidden buffs read
## it from there - so none of them needs a runtime lifetime of its own, and none can outlive the attack
## that made the record (the summary is dropped with it):
##   RECORD  {contact = Unit, legs = {persistent_id: Array[Vector3i]}} - who the shot reached first, and
##           for every redirected target the voxels its leg was drawn FROM (cover, ruling 10). The
##           voxels are frozen at the pick, so a start that moves or dies before its target is rolled
##           cannot move the cover.
##   ASKED   set on the first look, whether or not anything was appended, so nothing re-asks the same
##           declared attack.
##   DEFERRED_BUFFS  the Knot's one-time roll buffs every target read, consumed once after the whole
##           attack by onhit_gemini_one_attack (task 11c: "this counts as one attack").
## LEG_TILES sits on a throwaway duplicate of the weapon action instead - the leg the picker is asked
## about - so buff_gemini_leg_tiles narrows that picker and nothing else.
##
## RefCounted, no class_name (the mod's shared-helper rule): preload it.
extends RefCounted

const USAGE_KEY:StringName = &'gemini_charge'
const RECORD:StringName = &'reag_gemini_charge'
const ASKED:StringName = &'reag_gemini_asked'
const LEG_TILES:StringName = &'reag_gemini_leg_tiles'
## The Knot's one-time roll buffs set aside by onhit_gemini_one_attack, consumed once after the attack
## (task 11c). Also on the summary, so it dies with the attack.
const DEFERRED_BUFFS:StringName = &'reag_gemini_deferred_buffs'
## buff_gemini_ignore_cover.tres: the leg's cover skips it when asking whether the Knot ignores cover.
const GEMINI_IGNORE_COVER:StringName = &'buff_gemini_ignore_cover'
## Form of the Myriad's chip (SP3, buff_form_of_the_myriad.gd). While it is held, one Gemini use chains
## up to 4 legs, each at the weapon's full reach (rulings 18-19).
const MYRIAD_CHIP:StringName = &'buff_form_of_the_myriad'
const MYRIAD_LEGS := 4

static func record_of(summary) -> Dictionary:
	if not DeclaredAttackSummary.is_valid(summary) or not summary.has_meta(RECORD): return {}
	return summary.get_meta(RECORD)

static func is_redirected(summary, unit) -> bool:
	if not Unit.is_valid(unit): return false
	var legs:Dictionary = record_of(summary).get('legs', {})
	return legs.has(unit.core.persistent_id)

static func leg_start_voxels(summary, unit:Unit) -> Array[Vector3i]:
	var voxels:Array[Vector3i] = []
	var legs:Dictionary = record_of(summary).get('legs', {})
	voxels.assign(legs.get(unit.core.persistent_id, []))
	return voxels

## The contact's final d20 face, rerolls included - or 0 when it rolled none (an auto-hit, an
## invisibility miss), in which case every redirected target rolls its own (ruling 9).
static func face_of(summary) -> int:
	var contact = record_of(summary).get('contact')
	if not Unit.is_valid(contact): return 0
	for roll in summary.attack_rolls:
		if AttackRoll.is_valid(roll) and roll.target_unit == contact: return maxi(0, roll.base_roll)
	return 0

## "When attacking with a Ranged or Line weapon" (ruling 8): the Knot's own non-melee weapon attack
## whose pattern is single-target or a Line. Blast, Burst and Cone have no single contact; thrown
## weapons are melee-typed.
static func is_eligible_weapon(unit:Unit, gear:GearCore, action:Action) -> bool:
	if not (action is ActionAttackWeapon): return false
	if not UnitAction.is_ranged_weapon(action, gear): return false
	var pattern := action.get_range_pattern_for_targets(SpecificAction.create(unit, gear, action))
	return pattern == null or pattern.pattern == Lancer.AOE_TYPE.LINE

static func is_line(specific:SpecificAction) -> bool:
	var pattern := specific.action.get_range_pattern_for_targets(specific)
	return pattern != null and pattern.pattern == Lancer.AOE_TYPE.LINE

## A "character" is Unit.is_character() (ruling 2026-09-27): a drone is one.
static func is_new_character(unit:Unit, knot:Unit, excluded:Array[Unit]) -> bool:
	return Unit.is_valid(unit) and unit.is_character() and unit != knot and not excluded.has(unit)

## Whether the KNOT may not aim `action` at `unit`: Sanctuary, False Idol, Cast Doubt, Grey Birds. A
## leg's own SpecificAction belongs to a buffless proxy, and ActionAttackWeapon.can_target_unit reads
## ACTION_BANNED_UNITS off specific.unit (action_attack_weapon.gd:237), so the redirect must ask the
## Knot itself - the same test the engine applies to AoE units too (action_attack.gd:172).
static func is_banned(knot:Unit, gear:GearCore, action:Action, unit:Unit) -> bool:
	return UnitCondition.has_buff_to(knot, Buff.TO.ACTION_BANNED_UNITS,
		SpecificAction.create(knot, gear, action).to_context({target_unit = unit}))

## The contact: the first character the shot reaches. A single-target weapon's target, or the first
## character along a Line, which the engine lists closest-first (aoe_calculator.gd:143-154). Objects,
## deployables and terrain before it are passed through (ruling 12).
static func find_contact(knot:Unit, summary:DeclaredAttackSummary) -> Unit:
	for unit:Unit in summary.all_attacked_units:
		if is_new_character(unit, knot, []): return unit
	return null
