# Script extension on the UnitRelation autoload - the mod's FIRST extension of an autoload.
#
# A .gd_ext.gd's PATH is its declaration, so every rule this mod ever needs inside unit_relation.gd
# has to live in this one file, each under its own banner. Keep them fenced; anything added later
# gets its own banner too. Thy Hubris' file of the same name is the precedent (three rules, three
# banners), and gavstarb-talents_1st_party's is a third extender of the same vanilla file. All three
# call super, so they compose in any install order; spec/test_compat.gd asserts that both ways.
#
# The install log is NOT evidence that any override here runs: ModLoader logs the install for a
# dead seam exactly as for a live one, and unit_action.gd is known-dead (memory
# lancer-tactics-extension-seams). spec/test_unit_relation_extension.gd is the evidence, and it
# measures each override at every depth the engine reaches it from. mod_main.gd's EXTENDED_AUTOLOADS
# entry is load-bearing too: without the deferred reload, the live autoload node keeps its
# pre-extension script (upstream bug 5, unfixed as of 1.4.3).
#
# HOW DEEP AN OVERRIDE REACHES - measured 2026-09-19 by the probe spec, and the reason this file
# overrides THREE functions where the design named one. A call through the autoload node
# (`UnitRelation.foo(...)`) dispatches to the most-derived override of foo, and so does an
# UNQUALIFIED static call made from inside that function's body - ONE level down. But a function
# reached that way was itself invoked statically, with no instance, so the unqualified calls in
# ITS body bind to the script that compiled it: vanilla. Two levels down, every override is
# invisible. So an override is reached only from an instance call, or from one unqualified call
# below one. Overriding just is_weapon_available_as_a_rxn measured green when called directly
# (Integrated Weapon's shape) and RED from get_weapons_that_can_react_against and everything above
# it - which is where Overwatch asks. The shape below puts an override at every depth the chain
# crosses, each one calling super and then re-running the vanilla gates below it with the waiver
# in place, so each is reached from the one above whichever way the call arrived.
#
# ============================================================================================
# WORMHOLE GRASP (Primrose, cp_mobian_rainbow). A Superheavy weapon may OVERWATCH while the
# marker buff is held.
#
#   "Your weapons gain +1 threat and you may Overwatch with Superheavy weapons."
#
# Vanilla refuses SUPERHEAVY inside is_weapon_available_as_a_rxn (unit_relation.gd:293-299), and
# every overwatch-shaped weapon list is built through that one static: get_weapons_that_can_overwatch
# -> get_weapons_that_can_react_against -> can_weapon_hit_target_as_rxn -> here (:220-308). The
# waiver itself lives in exactly one place, is_weapon_available_as_a_rxn; the two overrides above
# it exist only so the chain reaches it (see HOW DEEP, above). Vanilla Overwatch then simply OFFERS
# the Superheavy weapon, and so does every other reaction built on the same list - Monitor Module,
# Scylla, the NPC reactions - and every direct caller (Integrated Weapon, the Ghast).
#
# The +1 threat, the half damage and the Slowed on-hit are ordinary buffs on the marker's owner;
# only the size waiver needs the engine's own gate opened, which is why this is the one line of the
# card that lives here. Design: specs/2026-09-19-primrose-design.md §1.6, ruling 2.
# ============================================================================================
extends "res://engine/character/unit/service/unit_relation.gd"

## The marker cp_mobian_rainbow's protocol applies for the rest of the scene. Read by id so this
## engine-level file stays ignorant of the content that applies it.
const WORMHOLE_GRASP := &'buff_wormhole_grasp'

## THE WAIVER. super first, then re-run vanilla's OTHER gates for the one case it refused, so this
## never widens anything but the size test: a destroyed, chargeless, NONE-typed Superheavy weapon is
## still refused, and the Ordnance filter in get_weapons_that_can_overwatch still applies on top.
## Reached directly by Integrated Weapon, the Ghast, Predatory Logic and Disdainful Blade, and from
## can_weapon_hit_target_as_rxn below.
static func is_weapon_available_as_a_rxn(specific:SpecificAction) -> bool:
	if super.is_weapon_available_as_a_rxn(specific): return true
	if not (specific.action is ActionAttackWeapon): return false
	if specific.action.weapon_size != Lancer.WEAPON_SIZE.SUPERHEAVY: return false
	if not UnitCondition.has_buff(specific.unit, WORMHOLE_GRASP): return false
	return (
		UnitAction.is_gear_available(specific, true) and
		specific.action.get_action_type(specific) != Lancer.ACTION.NONE
	)

## Vanilla's four gates (unit_relation.gd:302-308), re-run after super so that the third of them
## resolves to the override above. Only a weapon vanilla refused gets here, and the range test in
## front of the waiver keeps the re-run cheap for the common case (out of threat).
static func can_weapon_hit_target_as_rxn(specific:SpecificAction, target_unit:Unit, attack_range:int, closest_pair:Dictionary) -> bool:
	if super.can_weapon_hit_target_as_rxn(specific, target_unit, attack_range, closest_pair): return true
	return (
		attack_range >= closest_pair.distance and
		UnitTile.can_units_touch_elevationwise(specific.unit, target_unit, attack_range) and
		is_weapon_available_as_a_rxn(specific) and
		UnitTargeting.get_tiles_in_range(specific).has(closest_pair.to)
	)

## super builds the vanilla list; then, for a marked unit only, vanilla's own loop
## (unit_relation.gd:232-249) is run once more for the SUPERHEAVY weapons it skipped, gate for gate,
## with can_weapon_hit_target_as_rxn resolving to the override above. Vanilla never lists a
## Superheavy weapon, so nothing appended here can already be in the list. The Ordnance filter, the
## Earthstep suppression and the AI's threat model all sit above this function and see the appended
## weapons exactly as they see vanilla's.
static func get_weapons_that_can_react_against(
	from_unit:Unit,
	target_unit:Unit,
	use_normal_range_instead_of_threat:bool = false,
	required_compcon_id:StringName = &'',
) -> Array[SpecificAction]:
	var reaction_weapons:Array[SpecificAction] = super.get_weapons_that_can_react_against(
		from_unit, target_unit, use_normal_range_instead_of_threat, required_compcon_id)
	if not UnitCondition.has_buff(from_unit, WORMHOLE_GRASP): return reaction_weapons

	var closest_pair_base:Dictionary = closest_tiles_between(from_unit, target_unit)
	for gear:GearCore in from_unit.core.loadout.get_all_weapons():
		if required_compcon_id != &'' and gear.kit.compcon_id != required_compcon_id: continue
		for action:ActionAttackWeapon in gear.kit.get_weapon_actions():
			if action.weapon_size != Lancer.WEAPON_SIZE.SUPERHEAVY: continue
			var specific := SpecificAction.create(from_unit, gear, action)
			if not action.can_target_unit(target_unit, specific): continue
			var attack_range:int = action.threat_distance(specific)
			if use_normal_range_instead_of_threat: attack_range = maxi(attack_range, action.ranged_distance(specific))

			var closest_pair := closest_pair_base
			var attack_source:Unit = action.get_attacker_relay(from_unit.get_owner_unit_or_self(), gear)
			if attack_source != from_unit:
				closest_pair = closest_tiles_between(attack_source, target_unit)
				specific = SpecificAction.create(attack_source, gear, action)

			if not can_weapon_hit_target_as_rxn(specific, target_unit, attack_range, closest_pair): continue
			if specific.action.requires_line_of_sight(specific) and not UnitRelation.can_see(from_unit, target_unit): continue
			reaction_weapons.append(specific)
	return reaction_weapons


# ============================================================================================
# IN TRIUMVIRATE (Sluagh, ms_the_morrigan_class_nhp). A named partner counts as adjacent.
#
#   "Until the end of your next turn, your chosen ally is always treated as being adjacent to you
#    while within your Sensors, regardless of actual distance between you."
#
# Design specs/2026-09-20-sluagh-design.md ruling 23; spike
# specs/2026-09-20-adjacency-override-feasibility.md section 6, verbatim with fork 2 answered as the
# OWNER's live Sensors. super FIRST, so talents' House Guard (which also overrides this function,
# reading &'adjacency_range') and Thy Hubris' compose in either install order - spec/test_compat.gd
# pins both. Unit.is_valid on everything; append-if-absent (the Kraken's shape).
#
# REACHED FROM: a node call (UnitRelation.adjacent_characters - 37 content readers, Stabilize the
# measured witness) and from is_adjacent, an unqualified static call ONE level down
# (unit_relation.gd:7-8) - the depth an override is still dispatched at (this file's header).
# get_engaging_units is also one level down but filters the widened list through
# is_close_enough_to_engage, a radius, so engagement never widens (spike section 1).
# spec/test_unit_relation_extension.gd pins both depths.
# ============================================================================================

## The channel buff_in_triumvirate_pair sits on, and the override below is its only reader.
## Deliberately NOT talents' &'adjacency_range': a buff of ours on that key would make THEIR
## override widen the Sluagh to every ally within the number, and only while talents is installed.
const ADJACENT_TO := &'reag_adjacent_to'
const PARTNER_KEY := 'partner'   # BuffCore.state: the partner's persistent id

## super builds the vanilla list (and whatever a mod below us added); then each pair buff on THIS
## unit names one partner, which is appended while the OWNER's Sensors still reach it.
##
## THE OWNER IS THE SLUAGH ON EITHER END, because both cores are from_gear the NHP
## (buff_core.gd:102). So the Sensors test is the card's "while within YOUR Sensors" whichever end
## is queried, and it is read LIVE - Inexorable Formation moves the Sluagh's Sensors with its
## Overshield, so a pair that went quiet at 11 comes back when the range grows.
## THE WIDENING IS DISTANCE ONLY, so vanilla's OTHER two gates are re-run here - the doctrine the
## Wormhole Grasp banner above states in so many words ("super first, then re-run vanilla's OTHER
## gates for the one case it refused"). adjacent_characters is get_characters_within(unit, 1, false),
## which filters on other_unit.is_character() (unit_relation.gd:42) and, inside get_units_within, on
## UnitRelation.can_affect(whos_asking, other_unit) (:60). can_affect (:393-404) refuses an EXILED
## unit on either side, a tangibility MISMATCH, an INVULNERABLE target, and a pair that shares
## neither a global nor an effect shard. Without these two lines an exiled or intangible partner
## would stay "adjacent" to all 37 content readers - a widening of the distance rule into a waiver
## of the engine's own reachability rules, which the card never says.
static func adjacent_characters(unit:Unit) -> Array[Unit]:
	# In front of super rather than behind it: super already dereferences unit.map, so this guards
	# OUR body only, and the file's other banners put their early-outs first for the same reason.
	if not Unit.is_valid(unit) or unit.map == null: return super.adjacent_characters(unit)
	var adjacent_units := super.adjacent_characters(unit)
	for buff:BuffCore in UnitCondition.get_buffs_to(unit, ADJACENT_TO):
		var partner:Unit = buff.get_linked_unit(PARTNER_KEY, unit.map)
		if not Unit.is_valid(partner) or partner == unit: continue
		if not partner.is_character(): continue
		if not UnitRelation.can_affect(unit, partner): continue
		var owner:Unit = buff.get_owner_unit(unit.map)   # the Sluagh, on either end
		if not Unit.is_valid(owner): continue
		# "while within your Sensors": the OWNER's live Sensors, measured to whichever end is not the owner.
		var far_end:Unit = partner if unit == owner else unit
		if UnitRelation.distance_between(owner, far_end) > owner.get_sensor_range(): continue
		if not adjacent_units.has(partner): adjacent_units.append(partner)
	return adjacent_units
