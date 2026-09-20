# SPIKE 11 PROBE (roadmap §5 row 11): can a buff make a chosen ally count as ADJACENT to the mech
# anywhere within Sensors, regardless of distance? For the Sluagh's In Triumvirate (the Morrígan-
# class NHP's quick tech). Doc: specs/2026-09-20-adjacency-override-feasibility.md.
#
# No production code is added. The question has two halves and this file measures both:
#
#   1. VANILLA ALONE: no Buff.TO channel reaches adjacency. The one that CLAIMS to, COUNTS_AS_SIZE
#      ("minotaur engagement", and a docstring in a third-party mod says it covers adjacency), is
#      read by compare_size and compare_size_alt only (unit_relation.gd:99-124). The first test
#      applies it and shows compare_size sees it while is_adjacent does not.
#
#   2. WITH A WIDENING OF adjacent_characters(): the shape House Guard (talents, resident) already
#      uses and Thy Hubris and this mod already extend the same file for - a buff on a NON-vanilla
#      channel plus an override of adjacent_characters that calls super. House Guard's buff is the
#      proxy here: an ally-only widening to 2, which is In Triumvirate at a smaller radius. What the
#      remaining tests measure is WHICH ENGINE PATHS such a widening reaches (is_adjacent, engagement,
#      every content reader of adjacent_characters - Stabilize is the vanilla ally-side witness) and
#      which it never reaches (Guardian's hard-coded 1, and the whole distance_between family that
#      PassiveAura, get_characters_within(.., 1) and is_close_enough_to_engage sit on), plus that it
#      is ONE-SIDED: is_adjacent(a, b) reads a's buffs only, so "treated as adjacent to you" needs a
#      buff on each end.
#
# The gap between House Guard's shape and In Triumvirate's - pair-specific instead of faction-wide,
# radius = live Sensors instead of a number - is not an engine question (a BuffCore.state id looked
# up with map.get_unit_by_id, and unit.get_sensor_range()), so it is NOT probed. It is the design's.
#
# EVERY talents-dependent test carries its own liveness line, so a missing or dead widening cannot
# leave a "never reaches" test green for the wrong reason. Mutation-verified: swapping the widening
# buff for one that widens nothing reddens every test that depends on it; swapping the size buff
# for the widening one reddens the vanilla test. See the doc's Runs table.
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')

const TALENTS_MOD := 'gavstarb-talents_1st_party'
## The helper the talents mod adds to UnitRelation; its presence is the presence check, as in
## test_compat.gd.
const TALENTS_HELPER := &'get_adjacency_range_alt'
## House Guard rank 1: to = &'adjacency_range', number 2, only_to_allies. THE PROXY WIDENER.
const WIDENING_BUFF := &'buff_front_rank_adjacency_range'
## Synthetic Muscle Netting: to = &'counts_as_size', counts_as_largest_size. The vanilla channel
## whose docstring elsewhere claims adjacency.
const SIZE_BUFF := &'buff_synthetic_muscle_netting'
const GUARDIAN_BUFF := &'buff_guardian'
const STABILIZE_KIT := &'ms_stabilize'

# The mech is SIZE 1 (SpecFactory's knockoff Everest), so adjacency is distance 1 from its one tile.
const MECH_TILE := Vector2i(4, 4)
const ADJACENT_TILE := Vector2i(5, 4)  # 1 out - adjacent in vanilla
const NEAR_TILE := Vector2i(6, 4)      # 2 out - exactly the tile House Guard's widening pulls in
const FAR_TILE := Vector2i(7, 4)       # 3 out - beyond the widening's number, well inside Sensors (10)

var game:Gamemaster
var mech:Unit


func before_each() -> void:
	game = Fixture.create_game(self)
	mech = SpecFactory.create_unit(game.map, MECH_TILE)
	mech.core.full_repair()


# ---------------------------------------------------------------- helpers

func ally(tile:Vector2i) -> Unit:
	return Fixture.create_dummy(game, tile, 10, Faction.PLAYER)

func talents_adjacency_available() -> bool:
	return UnitRelation.has_method(TALENTS_HELPER)

## gut.p AND pass_test, so the skip prints - pass_test alone is silent at the default log level
## (test_compat.gd, measured 2026-09-16).
func skipped_without_talents() -> bool:
	if talents_adjacency_available(): return false
	var message := 'SKIPPED: %s is not resident, so nothing widens adjacent_characters. Restore the residency set with restore-links.ps1.' % TALENTS_MOD
	gut.p(message)
	pass_test(message)
	return true

func widen(unit:Unit) -> void:
	SpecFactory.apply_buff(unit, WIDENING_BUFF)

## The liveness line every talents-dependent test below carries.
func assert_widening_live(unit:Unit, pulled_in:Unit) -> void:
	assert_true(UnitRelation.adjacent_characters(unit).has(pulled_in),
		'LIVENESS: the widening is on %s and pulls in the unit two tiles out.' % unit)

func ram_context(unit:Unit, other:Unit) -> Context:
	return Context.create({
		unit = unit,
		target_unit = other,
		category = UnitRelation.COMPARE_SIZE_SITUATION.RAM,
	})


# ===================== HALF 1: VANILLA ALONE =====================

## COUNTS_AS_SIZE is live (compare_size reads it: a size-1 mech with counts_as_largest_size ranks
## ABOVE a size-1 target in a RAM context) and adjacency does not move. No vanilla channel reaches
## adjacent_characters: the function has no buff read at all (unit_relation.gd:10-11).
func test_counts_as_size_is_read_by_compare_size_and_never_by_adjacency() -> void:
	var near := ally(NEAR_TILE)
	assert_eq(UnitRelation.compare_size(mech, near, ram_context(mech, near)), 0,
		'Control: same size before the buff.')

	SpecFactory.apply_buff(mech, SIZE_BUFF)

	assert_eq(UnitRelation.compare_size(mech, near, ram_context(mech, near)), 1,
		'The size buff is live: compare_size ranks the mech bigger.')
	assert_false(UnitRelation.is_adjacent(mech, near),
		'COUNTS_AS_SIZE never reaches adjacency (whatever its docstring elsewhere says).')
	assert_false(UnitRelation.is_adjacent(near, mech),
		'...in either direction.')
	assert_eq(UnitRelation.distance_between(mech, near), 2,
		'...and distance is untouched.')


# ===================== HALF 2: A WIDENING OF adjacent_characters =====================

## A buff on a non-vanilla channel plus an adjacent_characters override that calls super - House
## Guard's shape, which this mod's own unit_relation.gd_ext.gd could carry as a new banner - makes a
## unit two tiles out ADJACENT to the holder. The radius is the BUFF'S number, not Sensors: three
## out stays outside although Sensors is 10. A Sensors radius is ours to write.
func test_a_widening_of_adjacent_characters_makes_a_far_ally_adjacent_to_the_holder() -> void:
	if skipped_without_talents(): return
	var near := ally(NEAR_TILE)
	var far := ally(FAR_TILE)
	assert_false(UnitRelation.is_adjacent(mech, near), 'Two out is not adjacent in vanilla.')

	widen(mech)

	assert_widening_live(mech, near)
	assert_true(UnitRelation.is_adjacent(mech, near),
		'is_adjacent(holder, other) is adjacent_characters(holder).has(other): reached, one level down.')
	assert_false(UnitRelation.is_adjacent(mech, far),
		'Three out is beyond the buff\'s number: the radius is the buff\'s, not Sensors (%d).' % mech.get_sensor_range())

## is_adjacent(a, b) reads a's buffs ONLY (unit_relation.gd:7-8). "Your chosen ally is always
## treated as being adjacent to you" is symmetric on the card and one-sided in the engine: the ally
## does not count the mech as adjacent until the ally holds a widening too. Two buffs, one per end.
func test_the_widening_is_one_sided_until_both_ends_hold_it() -> void:
	if skipped_without_talents(): return
	var near := ally(NEAR_TILE)
	widen(mech)
	assert_widening_live(mech, near)

	assert_false(UnitRelation.is_adjacent(near, mech),
		'The ally\'s view is unwidened: it does not count the mech as adjacent.')
	assert_false(UnitRelation.adjacent_characters(near).has(mech),
		'...because adjacent_characters(ally) read the ally\'s buffs, and it has none.')

	widen(near)

	assert_true(UnitRelation.is_adjacent(near, mech),
		'With a widening on the ally too, both directions hold.')

## A vanilla ally-side reader that goes through adjacent_characters takes the widening without
## knowing it: Stabilize's "clear a condition on an adjacent ally" offers the ally two tiles out.
## Stabilize is the witness because it is the most player-visible of the 37 content readers
## (action_stabilize.gd:282); the Sluagh's own three "adjacent" readers must sit on this same
## function or In Triumvirate does nothing for them.
func test_the_widening_reaches_a_vanilla_ally_reader() -> void:
	if skipped_without_talents(): return
	var near := ally(NEAR_TILE)
	SpecFactory.apply(near, Lancer.STATUS.IMPAIRED)
	assert_false(UnitCondition.get_ability_clearable_conditions_on(near).is_empty(),
		'Control: the ally carries a condition Stabilize could clear.')
	var stabilize:Action = ContentLibrary.get_kit(STABILIZE_KIT).actions[0]
	assert_true(stabilize.has_method(&'get_adjacent_allies_with_clearable_conditions'),
		'Control: this is Stabilize\'s own helper.')
	assert_false(stabilize.get_adjacent_allies_with_clearable_conditions(mech).has(near),
		'Two out: Stabilize does not offer the ally in vanilla.')

	widen(mech)

	assert_widening_live(mech, near)
	assert_true(stabilize.get_adjacent_allies_with_clearable_conditions(mech).has(near),
		'Widened: Stabilize offers the ally two tiles out. Every adjacent_characters reader does.')

## Guardian scans get_units_within(attacked_unit, 1, ...) - a hard-coded 1 through distance_between
## (unit_relation.gd:457) - so a widened mech holding Guardian is NOT a guardian for the ally two
## out, while it is for the ally one out. Same for anything else measuring a radius: PassiveAura
## (passive_aura.gd:85, pinned for the Fungal Network by test_compat.gd), get_characters_within(.., 1)
## (Step of Mist and Thunder), is_close_enough_to_engage (:166). "Adjacent" via the widening and
## "within 1" via distance are different questions, and the card's own effects must ask the first.
func test_the_widening_never_reaches_guardian_or_the_distance_family() -> void:
	if skipped_without_talents(): return
	var near := ally(NEAR_TILE)
	var touching := ally(ADJACENT_TILE)
	SpecFactory.apply_buff(mech, GUARDIAN_BUFF)
	widen(mech)
	assert_widening_live(mech, near)

	assert_true(UnitRelation.get_guardian_units(touching).has(mech),
		'Control: the mech guards the ally it genuinely touches.')
	assert_false(UnitRelation.get_guardian_units(near).has(mech),
		'Guardian never sees the widening: hard-coded 1.')
	assert_eq(UnitRelation.distance_between(mech, near), 2,
		'distance_between is untouched by the widening...')
	assert_false(UnitRelation.get_characters_within(mech, 1, false).has(near),
		'...so get_characters_within(mech, 1) - the engine\'s own radius - still excludes the ally...')
	assert_false(UnitRelation.is_close_enough_to_engage(mech, near),
		'...and so does the engagement distance gate.')
