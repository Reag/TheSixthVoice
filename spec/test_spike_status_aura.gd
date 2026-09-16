# MYCONID SP2, THE STATUS-ZONE PROBE (design §2.0): can a PassiveAura buff carry STATUSES onto the
# units standing in it, so that the statuses lift when they leave, return when they re-enter, and
# die with the aura's owner?
#
# Fungal Network (sheet 04-myconid.md): "Hostile characters within burst 2 of the Myconid are Slowed
# and Impaired." Ruling 6 makes that a ZONE for the rest of the scene, so the statuses have to be
# HELD by the zone rather than applied once on entry - a unit that walks out must stop being Slowed.
#
# THIS IS A PROBE, NOT CONTENT. Every resource it uses is built in code, in this file, on a vanilla
# Everest; the Myconid's core system does not exist yet. Everything asserted here is a
# characterisation of the 1.4.3 engine and stays true whatever the core Kit eventually looks like.
# Deleted in SP2 Task 5, once test_fungal_network.gd covers the same ground against the real content
# - as test_spike_symbiosis.gd was deleted when test_symbiosis.gd landed.
#
# ============================== WHAT THIS PROBE CORRECTS ==============================
#
# Design ruling 7 and design §4 say the statuses must ride on the buff's `on_application` /
# `on_clear` lifecycle hooks, because "Slowed and Impaired are read ONLY as statuses; no buff
# channel emulates them". The second half of that is WRONG, and this probe is what settles it.
#
# `Buff.applies_statuses:Array[StringName]` (buff.gd:134) is a native, declarative channel:
#
#   - UnitCondition.get_current_statuses (:372-385) walks `unit_state.buffs` and folds every held
#     buff's `applies_statuses` into the unit's non-duplicate status list, checking
#     has_gained_immunity_to_status against the buff's `from_gear` as it goes.
#   - That list is what unit.update_cached_values_and_token() writes into state.cached_statuses, and
#     Unit.has_status (unit.gd:210-211) reads the cache. So the status is live exactly as long as
#     the buff is held and gone the instant it is cleared - with no on_clear to write and no source
#     bookkeeping to get wrong.
#   - UnitCondition.has_status(unit, status, source) (:386-393) also consults
#     get_buffs_that_apply_status (:809-817), so a SOURCE-QUALIFIED query sees it too.
#   - apply_buff_alt (:760-761) runs on_status_application for each of them, which is the
#     logging/popcorn/cache pass. NOT MEASURED HERE: the probe asserts nothing about the battle log
#     or the status icons, so do not read it as evidence about either.
#
# WHERE IT IS *NOT* THE SAME AS A DIRECTLY-APPLIED STATUS, AND WHY THAT MATTERS TO THIS CARD.
# apply_buff_alt never calls apply_status, so nothing is ever appended to unit.state.statuses. The
# status therefore exists ONLY through the fold. Three consequences, and the third is a gameplay
# fact, not a detail:
#   - UnitCondition.get_status (:365-369) iterates unit.state.statuses alone and returns null for it.
#     test_the_status_is_attributed_to_the_aura_gear passes through the SECOND disjunct of has_status
#     (:392, get_buffs_that_apply_status), never the first.
#   - It carries no duration of its own: `until` is hardcoded MANUAL at :761. The aura is the clock.
#   - **UnitCondition.clear_status CANNOT STRIP IT.** :310-324 rebuilds unit.state.statuses and
#     touches nothing else, so a cleanse, a save or any engine effect that clears Slowed leaves a
#     hostile standing in the zone still Slowed. This is the engine's stated intent, not a hole -
#     buff.gd:133 documents the export as "Locks these statuses on the unit for as long as this buff
#     is applied". For Fungal Network it is also the RIGHT reading of the card: "Hostile characters
#     within burst 2 of the Myconid are Slowed and Impaired" describes a condition of being inside,
#     not an effect applied on the way in. Pinned by test_the_locked_status_cannot_be_cleared, and
#     recorded as a rulings row (2026-09-16) because it is player-visible.
#
# And the CHANNEL has a vanilla PassiveAura precedent, which is why this is a correction rather than
# a discovery: content/gear/ssc/systems/ms_lb_oc_cloaking_field/passive_lb_oc_cloaking_field_aura.tres
# is a PassiveAura, aura_range 2, whose one buff (buff_lb_oc_cloaking_field_invisible.tres) is a
# plain Buff carrying `applies_statuses = Array[StringName]([&"invisible"])` and an icon. The Scout
# NPC's cloaking field (npcc_scout/cloaking_field/) is the same. NOTE that the precedent is for the
# CHANNEL and not for the configuration: that aura is applies_to_enemies = false,
# applies_only_when_entirely_within = true and gated behind requires_buff - a cloak over its own
# side - where Fungal Network is hostile-facing and, once woken, always on.
#
# The CARD is unchanged by this: the statuses, the timing, the chip and the zone semantics are
# identical either way. What changes is that buff_fungal_network_spores is a script-less .tres.
#
# ============================== WHAT A GREEN RUN HERE MEANS ==============================
#
# Design §2.0 says STOP and report if the statuses cannot be carried this way, because the fallback
# (the Gorgon's ActionReactionOnComingWithin shape, statuses applied on entry and at turn start
# rather than held) CHANGES THE CARD'S SEMANTICS and is the author's call. This probe green means
# SP2 proceeds and the fallback is never reached.
#
# ============================== HOW THE AURA GETS ONTO A UNIT ==============================
#
# test_draw_fire.gd's install_recorder() is the idiom: build a Kit in code, append it to
# loadout.equipped_kits, full_repair(), then update the map's tracking. full_repair() is what
# rebuilds LoadoutCore.auras (loadout_core.gd:298-301, from regenerate_caches), which is the list
# PassiveAura.update_unit iterates (:31) - without it the aura exists on the Kit and is invisible to
# the engine.
#
# MOVEMENT IS UnitTile.move_to, AND WHAT THAT DOES AND DOES NOT PROVE. move_to's `update_statuses`
# defaults to true and it calls UnitTile.update_tracking_and_statuses itself (unit_tile.gd:10-13),
# which is the same function that runs PassiveAura.update_unit for every unit on the map (:20-24) -
# so these tests are not hand-driving the aura, they move a unit and let the tracking pass notice.
# But move_to is the low-level teleport primitive: real in-game movement goes through the movement
# action and its event pipeline, with reactions, overwatch and per-tile triggers that none of this
# exercises. A green run here is evidence about the TRACKING PASS, which is what the zone hangs off,
# and not about movement.
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const AURA_KIT_ID := &'spike_status_aura_kit'
const AURA_BUFF_ID := &'buff_spike_status_aura'

var game:Gamemaster
var owner_unit:Unit


# =============================== THE PROBE'S THROWAWAY CONTENT ===============================

## SHAPE A - the declarative one, and the one this probe exists to prove. A plain Buff whose only
## content is applies_statuses. No script, no lifecycle hook, nothing to clear by hand.
##
## It is built here as a Buff instance rather than a .tres for the reason the whole file is code:
## a .tres under res:// would be indexed by ContentLibrary and would have to be deleted from the
## mod's content tree as well as from spec/. Nothing under spec/ is ever scanned.
func _make_spore_buff(statuses:Array[StringName]) -> Buff:
	var buff := Buff.new()
	# REQUIRED. PassiveAura.apply_aura_buffs_to_unit asserts compcon_id != Buff.GENERIC_ID (:79),
	# and the lazy getter (buff.gd:106-112) defaults anything not named buff_* to GENERIC_ID.
	buff.compcon_id = AURA_BUFF_ID
	buff.applies_statuses = statuses
	buff.hide_from_player = true
	return buff

## The zone: Fungal Network's hostile half, exactly - burst 2, hostile characters only, never the
## owner, never an ally. starts_active is left TRUE here because the protocol that wakes it is Task
## 3's; this probe is about what an ACTIVE aura can carry, not about waking one.
func _install_aura(unit:Unit, buff:Buff, range_tiles:int = 2) -> void:
	var aura := PassiveAura.new()
	aura.buffs = [buff] as Array[Buff]
	aura.aura_range = range_tiles
	aura.applies_to_self = false
	aura.applies_to_allies = false
	aura.applies_to_enemies = true
	aura.applies_only_to_characters = true

	var kit := Kit.new()
	kit.compcon_id = AURA_KIT_ID
	kit.is_trait = true
	kit.passives = [aura] as Array[Passive]

	unit.core.loadout.equipped_kits.append(kit)
	unit.core.full_repair() # rebuilds LoadoutCore.auras; without this the aura is invisible
	UnitTile.update_tracking_and_statuses(game.map)

func _aura_gear() -> GearCore:
	return owner_unit.get_gear(AURA_KIT_ID)


# =============================== FIXTURE ===============================

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	owner_unit = SpecFactory.create_unit(game.map, Vector2i(4, 4))
	SpecFactory.apply_passive_buffs(owner_unit)

## A hostile CHARACTER, the thing the zone is aimed at.
func _hostile(tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.AI_ENEMY)

## An allied character, to prove applies_to_allies = false really excludes one.
func _ally(tile:Vector2i) -> Unit:
	return FitzgeraldFixture.create_dummy(game, tile, 10, Faction.PLAYER)

func _has_spore_buff(unit:Unit) -> bool:
	return UnitCondition.has_buff(unit, AURA_BUFF_ID)


# ===================== A. THE BUFF AND THE STATUS ARRIVE TOGETHER =====================

func test_a_hostile_inside_the_aura_holds_the_buff_and_the_status() -> void:
	var hostile := _hostile(Vector2i(6, 4)) # distance 2
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))

	assert_true(_has_spore_buff(hostile), 'the aura applied its buff to a hostile in range')
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED),
		'and unit.has_status - the CACHE - reports the status the buff declares')
	# NOT `current_statuses().has(...)` - that reads the same array unit.has_status just read
	# (unit.gd:213-214 hands back state.cached_statuses; unit_battle_state.gd:254 is what has_status
	# asks), so it would be a tautology dressed as a second observation. Ask the FOLD itself instead:
	# get_current_statuses is the only producer of that cache (unit_battle_state.gd:187-190 is its
	# only writer), so agreeing with it is what pins unit_condition.gd:379-382.
	assert_true(UnitCondition.get_current_statuses(hostile.state, game.map).has(Lancer.STATUS.SLOWED),
		'the fold itself reports it, not just the cache the fold wrote')

func test_a_hostile_outside_the_aura_has_neither() -> void:
	var hostile := _hostile(Vector2i(7, 4)) # distance 3, one past the burst
	var inside := _hostile(Vector2i(6, 4)) # distance 2, the control
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))

	assert_true(inside.has_status(Lancer.STATUS.SLOWED), 'control: one tile closer IS caught')
	assert_false(_has_spore_buff(hostile), 'out of range, no buff')
	assert_false(hostile.has_status(Lancer.STATUS.SLOWED), 'and therefore no status')

func test_both_statuses_ride_on_one_buff() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed', &'impaired'] as Array[StringName]))

	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'Slowed, from the one buff')
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'and Impaired, from the same one')
	assert_eq(UnitCondition.get_buffs(hostile, AURA_BUFF_ID).size(), 1,
		'carried by a SINGLE buff - the card is one effect, so it wears one chip')


# ===================== B. THE ZONE IS HELD, NOT APPLIED ONCE =====================

func test_stepping_out_of_the_aura_lifts_both() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed', &'impaired'] as Array[StringName]))
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'precondition: inside the zone')

	UnitTile.move_to(hostile, Vector2i(7, 4)) # out to distance 3

	assert_false(_has_spore_buff(hostile), 'PassiveAura.update_unit cleared the buff on the way out')
	assert_false(hostile.has_status(Lancer.STATUS.SLOWED), 'and the status went with it')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'both of them')

func test_stepping_back_in_restores_both() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed', &'impaired'] as Array[StringName]))
	UnitTile.move_to(hostile, Vector2i(7, 4))
	assert_false(hostile.has_status(Lancer.STATUS.SLOWED), 'precondition: outside the zone')

	UnitTile.move_to(hostile, Vector2i(6, 4))

	assert_true(_has_spore_buff(hostile), 're-entry re-applies the buff')
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'and the status comes back with it')
	assert_true(hostile.has_status(Lancer.STATUS.IMPAIRED), 'both of them')


# ===================== C. WHO THE ZONE REACHES =====================

## The control here is the hostile at the mirror-image tile: same distance, opposite faction. Without
## it the two assert_falses cannot tell "allies are excluded" from "nothing happened at all". Note
## what the test still cannot separate even with it: applies_to_allies (passive_aura.gd:70) from
## UnitRelation.can_affect failing one line earlier (:68). Both would look like this.
func test_an_ally_in_range_gets_nothing() -> void:
	var ally := _ally(Vector2i(6, 4))
	var hostile := _hostile(Vector2i(2, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))

	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'control: a hostile at the same range IS caught')
	assert_false(_has_spore_buff(ally), 'applies_to_allies = false (passive_aura.gd:70)')
	assert_false(ally.has_status(Lancer.STATUS.SLOWED), 'so no status either')

## THE POSITIVE CONTROL IS LOAD-BEARING. Two assert_falses alone stay green if applies_statuses is
## deleted, if the aura never fires, if full_repair() stopped rebuilding loadout.auras, or if the Kit
## never reached the loadout - it is the shape that measures nothing. The hostile standing the same
## distance away turns the test into a CONTRAST: the zone is demonstrably live, and the owner is
## still out of it.
##
## WHICH FLAG ACTUALLY EXCLUDES THE OWNER - MEASURED, AND IT IS NOT THE OBVIOUS ONE. Setting
## applies_to_self = true reddens NOTHING here. `UnitRelation.are_allies(unit, unit)` is
## `Faction.is_ally(f, f)`, and faction.gd:30 returns true for a faction against itself - so a unit
## is its own ally, and applies_to_allies = false refuses the owner at passive_aura.gd:70, one line
## AFTER the applies_to_self test at :69 has fallen through. On any hostile-facing aura
## applies_to_self is therefore REDUNDANT. Only opening both flags reddens this test (mutation 5).
##
## Both are still set on the real passive, and should be: the redundancy is an engine detail that
## could change, the card cannot, and a reader of the .tres should not have to know faction.gd:30 to
## see that the Myconid is out of its own cloud. But do not write a Task 3 test that claims to pin
## applies_to_self - it cannot.
func test_the_aura_owner_is_not_caught_by_its_own_zone() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))

	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'control: the zone IS live at this range')
	assert_false(_has_spore_buff(owner_unit), 'applies_to_self = false (passive_aura.gd:69)')
	assert_false(owner_unit.has_status(Lancer.STATUS.SLOWED), 'the Myconid does not Slow itself')

func test_the_status_is_attributed_to_the_aura_gear() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))
	var gear := _aura_gear()

	assert_true(GearCore.is_valid(gear), 'precondition: the aura gear is on the loadout')
	assert_true(UnitCondition.has_status(hostile, Lancer.STATUS.SLOWED, gear.persistent_id),
		'a SOURCE-QUALIFIED query finds it, via get_buffs_that_apply_status (unit_condition.gd:809-817)')


# ===================== C2. THE STATUS IS LOCKED, NOT MERELY APPLIED =====================

## `Buff.applies_statuses` is documented as a LOCK - buff.gd:133, "Locks these statuses on the unit
## for as long as this buff is applied" - and the lock is not a figure of speech.
## `UnitCondition.clear_status` (:310-324) walks `unit.state.statuses`, keeps the non-matching ones
## and writes the array back. A buff-supplied status was never in that array, so the clear cannot
## reach it and `cleared` stays false: not even the battle-log line fires.
##
## FOR FUNGAL NETWORK THIS IS THE CARD, NOT A SIDE EFFECT. "Hostile characters within burst 2 of the
## Myconid are Slowed and Impaired" describes a condition of standing inside, not an effect applied
## on the way in - so a cleanse, a save or any engine effect that strips Slowed should NOT free a
## hostile who is still in the cloud. It lifts by leaving, and only by leaving
## (test_stepping_out_of_the_aura_lifts_both). Recorded as a rulings row because it is
## player-visible, and because every later frame using this channel inherits it.
##
## The same fact is a WARNING for any future use: this channel cannot express "Slowed until they
## save against it". That needs a real status, applied the ordinary way.
func test_the_locked_status_cannot_be_cleared() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed', &'impaired'] as Array[StringName]))
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'precondition: Slowed by the zone')

	UnitCondition.clear_status(SpecFactory.dummy_event(), hostile, Lancer.STATUS.SLOWED)

	assert_true(hostile.has_status(Lancer.STATUS.SLOWED),
		'clear_status touches only state.statuses, so the locked status survives it')
	assert_true(UnitCondition.is_slowed(hostile), 'and the engine predicate still agrees')

## The other half of the same fact, and the reason the lock is safe: the ordinary clear path is not
## broken, it simply has nothing of ours to find. A status the zone did NOT supply clears normally
## off the same unit, so the lock is specific to what the buff carries rather than a blanket
## immunity to clearing.
func test_an_ordinary_status_on_the_same_unit_still_clears() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))
	UnitCondition.apply_status(SpecFactory.dummy_event(), hostile, Lancer.STATUS.SHREDDED, Lancer.UNTIL.MANUAL)
	assert_true(hostile.has_status(Lancer.STATUS.SHREDDED), 'precondition: really Shredded')

	UnitCondition.clear_status(SpecFactory.dummy_event(), hostile, Lancer.STATUS.SHREDDED)

	assert_false(hostile.has_status(Lancer.STATUS.SHREDDED), 'an ordinary status clears as normal')
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'and the locked one is untouched by that')


# ===================== D. THE STATUS IS REAL TO THE ENGINE =====================

## THE TEST THAT MATTERS MOST. A status that lives only in a cache nothing consults would make every
## other test here green and the mechanic dead. UnitAction.is_boost_prohibited (unit_action.gd:497-510, the is_slowed test at :499)
## is an engine gate that asks UnitCondition.is_slowed (:407-411), which asks has_status - the same
## path the pathfinder and ActionSystemMovement use (action_system_movement.gd:25).
func test_slowed_from_the_aura_really_prohibits_a_boost() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	assert_false(UnitAction.is_boost_prohibited(hostile), 'precondition: it could boost before')

	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))

	assert_true(UnitCondition.is_slowed(hostile), 'the engine predicate agrees')
	assert_true(UnitAction.is_boost_prohibited(hostile), 'and an engine GATE acts on it')

func test_stepping_out_of_the_aura_restores_the_boost() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed'] as Array[StringName]))
	assert_true(UnitAction.is_boost_prohibited(hostile), 'precondition: Slowed inside')

	UnitTile.move_to(hostile, Vector2i(7, 4))

	assert_false(UnitAction.is_boost_prohibited(hostile),
		'the gate follows the zone, which is what "while inside" has to mean')


# ===================== E. THE ZONE DIES WITH ITS OWNER =====================

## Aura buffs carry the aura gear as from_gear (passive_aura.gd:82, via UnitCondition.apply_buffs),
## and the engine clears from_gear buffs when the owner dies.
##
## THE TEST CANNOT TELL THREE PATHS APART, and all three would produce this result, so do not read
## it as isolating the from_gear one. EventService.remove_unit_from_game :66-68 sets
## is_aura_active = false on every one of the dead unit's gear (which makes the strip branch at
## passive_aura.gd:55-59 fire on the next pass); :71 clears the outgoing buffs by from_gear; :92 runs
## a final update_tracking_and_statuses; and the owner leaves map.get_all_units() entirely. What the
## test pins is the OUTCOME the card needs - the zone dies with the Myconid - which is what matters.
##
## The shared gamemaster is what makes
## this test safe to write at all: the re-use branch of SpecFactory.setup_gamemaster builds a
## CampaignCore and hangs it on the map, which EventService.remove_unit_from_game dereferences with
## no guard (event_service.gd:80). See myconid_fixture.gd's header.
func test_the_aura_owners_death_strips_both() -> void:
	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, _make_spore_buff([&'slowed', &'impaired'] as Array[StringName]))
	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'precondition: the zone is up')

	await game.execute_event(&'event_unit_damage', {
		unit = owner_unit,
		number = 9999,
		category = Lancer.DAMAGE_TYPE.KINETIC,
	})

	assert_false(Unit.is_valid(owner_unit), 'precondition: the owner is dead')
	assert_true(Unit.is_valid(hostile), 'precondition: and the hostile is NOT - four assert_falses on a corpse measure nothing')
	assert_false(_has_spore_buff(hostile), 'the buff went with its owner')
	assert_false(hostile.has_status(Lancer.STATUS.SLOWED), 'and so did the status')
	assert_false(hostile.has_status(Lancer.STATUS.IMPAIRED), 'both of them')


# ===================== F. THE UPDATE TERMINATES =====================

## Scaffolding ONLY: a Buff subclass identical to shape A except that it counts its own
## applications. The mechanism under test is still applies_statuses; the counter exists because
## PassiveAura.update_unit is a static function with no other observable.
##
## WHY THIS TEST EXISTS. UnitCondition.apply_buffs (:713-714) sets update_tracking_and_statuses =
## true whenever the applying gear has a PassiveAura, so post_apply_buff_cache_update (:770-773)
## passes the real event into unit.update_cached_values_and_token(event), which at unit.gd:158-160
## calls UnitTile.move_to(self, state.tile, true, event) - a WHOLE FRESH aura pass per application.
## The re-entry is real, not theoretical.
##
## It is IDEMPOTENT because unit.state.buffs.append happens at unit_condition.gd:757, BEFORE
## on_application at :758 and long before the re-entrant pass - so by the time re-entry reaches
## apply_aura_buffs_to_unit, both the has_buff skip at passive_aura.gd:80 and already_has_all_buffs
## (:95-96) already see the buff, and apply_buffs bails at :704 on the empty array without calling
## on_application again.
##
## WHAT THIS TEST PROVES AND WHAT IT DOES NOT. It proves IDEMPOTENCE: one on_application per
## occupant, however many times the pass re-enters. It does NOT prove termination - a
## non-terminating update would hang or overflow the stack, so termination is proved by the test
## RETURNING, not by the number. And the counter cannot say how many times the pass ran, only how
## often the guard let an application through.
class CountingSporeBuff extends Buff:
	static var apply_count:int = 0
	func on_application(event:EventCore, core:BuffCore, unit:Unit) -> void:
		CountingSporeBuff.apply_count += 1
		super(event, core, unit)

func test_the_aura_update_does_not_recurse() -> void:
	CountingSporeBuff.apply_count = 0
	var buff := CountingSporeBuff.new()
	buff.compcon_id = AURA_BUFF_ID
	buff.applies_statuses = [&'slowed', &'impaired'] as Array[StringName]
	buff.hide_from_player = true

	var hostile := _hostile(Vector2i(6, 4))
	_install_aura(owner_unit, buff)

	assert_true(hostile.has_status(Lancer.STATUS.SLOWED), 'precondition: the zone applied')
	assert_eq(CountingSporeBuff.apply_count, 1,
		'ONE application for one hostile entering one aura - the re-entrant update is idempotent')

## NOT A STATEMENT ABOUT COST. The number of on_application calls is linear in occupants; the WORK
## is not, and nothing here measures it. update_tracking_and_statuses loops every unit on the map
## (unit_tile.gd:20) and update_unit loops them all again inside that (passive_aura.gd:28), so one
## pass is already O(n^2) - and per the section header each application triggers another whole pass.
## Anyone optimising a wide aura should start from that, not from this counter.
func test_a_second_hostile_is_one_more_application_not_a_multiple() -> void:
	CountingSporeBuff.apply_count = 0
	var buff := CountingSporeBuff.new()
	buff.compcon_id = AURA_BUFF_ID
	buff.applies_statuses = [&'slowed'] as Array[StringName]
	buff.hide_from_player = true

	var first := _hostile(Vector2i(6, 4))
	var second := _hostile(Vector2i(4, 6))
	_install_aura(owner_unit, buff)

	assert_true(first.has_status(Lancer.STATUS.SLOWED), 'precondition: both are inside')
	assert_true(second.has_status(Lancer.STATUS.SLOWED), 'precondition: both are inside')
	assert_eq(CountingSporeBuff.apply_count, 2,
		'two hostiles, two applications - one each, not one per re-entrant pass')
