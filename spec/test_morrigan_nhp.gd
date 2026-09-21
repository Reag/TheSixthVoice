# THE MORRÍGAN-CLASS NHP's FACE, NAME AND VOICE (release 0.8.1). The Kit and In Triumvirate
# themselves are test_in_triumvirate.gd; this file is only the PassiveAiPrivilege the Sluagh's SP4
# close left open, waiting on a barkset from Bel. The lines landed 2026-09-21 and the portrait JSON
# was already in hand, so both ship together.
#
# THEY HAVE TO SHIP TOGETHER, and this is the fact that decided the release's scope: the nhp_name
# assignment sits INSIDE the `if passive.default_portrait:` branch of
# PassiveAiPrivilege.inherit_default_nhp_settings (passive_ai_privilege.gd:66-70), reached from
# UnitPrinter.full_repair (unit_printer.gd:79). A barkset with no portrait would have given the
# Morrígan her own lines under whatever name the pilot's NHP already carried.
#
# THE LINES ARE NOT IN THE RESOURCE. bark_nhp_morrigan.tres is an empty BarkSet; the 38 lines are
# bark.nhp_morrigan.<incident>.<N> rows in localizations.csv, discovered by
# get_possible_bark_keys_for counting N upward from 1 and STOPPING AT THE FIRST MISSING KEY
# (bark_set.gd:168-186). A gap in the numbering is therefore silent data loss with no error, which
# is why the per-incident counts below are asserted one by one rather than only in total.
#
# BARKS ARE THIS MOD'S ONE EXEMPTION FROM localization-matches-the-lcp: the supplement carries no
# bark lines for any NHP, so there is nothing to match. Recorded in the barkset template's Voice note.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_morrigan_nhp.gd
extends GutTest

const SluaghFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/sluagh_fixture.gd')

## test_in_triumvirate.gd's convention: read THIS MOD'S OWN compiled artifact, not the global tr(),
## so a passing display-text test cannot be satisfied by a sibling Reag-* mod in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const BARKSET := &'bark_nhp_morrigan'
const SLUAGH_TILE := Vector2i(4, 6)

## Every incident and the number of lines written for it. The engine offers eighteen
## (BarkSet.BARKS); all eighteen are covered, and the totals are what a numbering gap would break.
const LINES_PER_INCIDENT := {
	&'deploy': 3,
	&'start_turn': 2,
	&'crit_target': 2,
	&'structure_target': 2,
	&'stress_target': 3,
	&'destroy_target': 3,
	&'structure_self': 2,
	&'stress_self': 2,
	&'destroy_self': 3,
	&'destroy_ally': 3,
	&'friendly_fire_self': 2,
	&'friendly_fire_target': 2,
	&'core_power': 2,
	&'overcharge': 2,
	&'brace': 2,
	&'leader_accuracy': 1,
	&'leader_damage': 1,
	&'leader_reduce': 1,
}
const TOTAL_LINES := 38

var game:Gamemaster
var sluagh:Unit

func before_each() -> void:
	game = SluaghFixture.create_game(self)
	sluagh = SluaghFixture.create_sluagh(game, SLUAGH_TILE)
	SluaghFixture.equip_morrigan(sluagh)
	# create_sluagh has already printed the mech, so the pilot may be carrying the adopted defaults
	# from that. Clear all three so each test watches the adoption happen rather than inspecting a
	# leftover; test_a_hand_authored_face_is_not_overwritten then fills them in deliberately.
	sluagh.core.pilot.nhp_name = ''
	sluagh.core.pilot.nhp_portrait_json = {}
	sluagh.core.pilot.nhp_barks = null

func privilege() -> PassiveAiPrivilege:
	# get_passives is typed Array[Passive] whatever it is asked to filter for (kit.gd:157), so the
	# narrowing happens here rather than in the declaration - an Array[PassiveAiPrivilege] local
	# would not even PARSE, and a spec that fails to parse is skipped rather than failed.
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.MORRIGAN)
	var found:Array[Passive] = kit.get_passives(PassiveAiPrivilege)
	return found[0] as PassiveAiPrivilege if not found.is_empty() else null

func barkset() -> BarkSet:
	return ContentLibrary.get_barkset(BARKSET)

# ------------------------------------------------------------------ the wiring

func test_the_kit_carries_one_ai_privilege_with_both_defaults():
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.MORRIGAN)
	assert_eq(kit.get_passives(PassiveAiPrivilege).size(), 1, 'Exactly one PassiveAiPrivilege.')
	var ai := privilege()
	if ai == null: return fail_test('The Kit carries a PassiveAiPrivilege.')
	assert_not_null(ai.default_portrait, 'It hands out a portrait JSON...')
	assert_true(BarkSet.is_valid(ai.default_barkset), '...and a barkset.')

func test_it_stays_an_ordinary_one_per_mech_ai():
	# increases_limit, counts_against_limit and can_benefit_from_talents are all left at their
	# defaults, as every vanilla NHP but the Lesson of Shaping leaves them. Adding the privilege
	# must not have loosened the single-AI limit the Kit was already subject to.
	var ai := privilege()
	if ai == null: return fail_test('The Kit carries a PassiveAiPrivilege.')
	assert_false(ai.increases_limit, 'Does not raise the AI limit.')
	assert_true(ai.counts_against_limit, 'Counts against it.')
	assert_false(ai.can_benefit_from_talents, 'No talents while in control.')
	assert_eq(ai.disable_unless_also_has_kit, StringName(''), 'Not gated behind another kit.')
	var kit:Kit = ContentLibrary.get_kit(SluaghFixture.MORRIGAN)
	assert_true(PassiveAiPrivilege.is_kit_illegal_to_equip_due_to_ai_limit(kit, sluagh.core.loadout),
		'A second AI on a mech that already has this one is still refused.')

# ------------------------------------------------------------------ the barkset

func test_the_barkset_is_indexed_and_is_the_one_the_kit_points_at():
	var set:BarkSet = barkset()
	assert_true(BarkSet.is_valid(set), '%s is in the barks index (**/bark_*.tres).' % BARKSET)
	if not BarkSet.is_valid(set): return
	assert_true(set.is_nhp, 'Flagged as an NHP barkset, so the picker files it with the co-pilots.')
	assert_eq(set.compcon_id, BARKSET, 'Indexed under its own filename.')
	var ai := privilege()
	if ai == null: return fail_test('The Kit carries a PassiveAiPrivilege.')
	assert_eq(ai.default_barkset, set, 'And the Kit hands out this exact resource.')

func test_the_barkset_carries_no_resource_state_of_its_own():
	# The author's stated odds match BarkSet.BARKS' defaults for all eighteen incidents, so
	# `probabilities` is deliberately empty rather than restating them; `custom` and `redirects`
	# are empty because the lines live in the CSV. is_blank() being TRUE is what lets the pilot
	# adopt a replacement later (:73-79), so it is a feature, not an omission.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	assert_true(set.custom.is_empty(), 'No straight-text overrides.')
	assert_true(set.redirects.is_empty(), 'No incident redirected to another preset.')
	assert_true(set.probabilities.is_empty(), 'No probability overrides.')
	assert_false(set.intentionally_blank, 'Not marked intentionally blank.')

func test_every_incident_uses_the_engine_default_odds():
	# Restates the author's table against BarkSet.BARKS. With `probabilities` empty this can only
	# fail if the engine's defaults move under us in a modkit release - which is exactly the check
	# worth having, because the table was written against 1.4.3's numbers.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	var expected := {
		&'deploy': 1.0, &'start_turn': 0.15, &'crit_target': 0.10,
		&'structure_target': 0.25, &'stress_target': 1.0, &'destroy_target': 0.30,
		&'structure_self': 0.25, &'stress_self': 0.25, &'destroy_self': 1.0,
		&'destroy_ally': 0.5, &'friendly_fire_self': 0.5, &'friendly_fire_target': 1.0,
		&'core_power': 1.0, &'overcharge': 0.25, &'brace': 1.0,
		&'leader_accuracy': 1.0, &'leader_damage': 1.0, &'leader_reduce': 1.0,
	}
	for incident:StringName in expected:
		assert_almost_eq(set.get_probability_for(incident), float(expected[incident]), 0.001,
			'%s fires at the odds the author wrote.' % incident)

# ------------------------------------------------------------------ the lines

func test_the_barkset_finds_all_thirty_eight_lines_with_no_gap():
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	var total := 0
	for incident:StringName in LINES_PER_INCIDENT:
		var keys:Array[StringName] = set.get_possible_bark_keys_for(incident)
		assert_eq(keys.size(), int(LINES_PER_INCIDENT[incident]),
			'%s has %s lines, numbered without a gap.' % [incident, LINES_PER_INCIDENT[incident]])
		total += keys.size()
	assert_eq(total, TOTAL_LINES, 'Thirty-eight lines in all.')
	assert_eq(LINES_PER_INCIDENT.size(), BarkSet.BARKS.size(),
		'And every incident the engine offers is covered, so nothing falls through to bark_unknown.')

func test_no_line_falls_back_to_the_default_barkset():
	# A missing incident is not silence: get_bark_for drops through to bark_unknown and the
	# Morrígan speaks a generic NHP line in someone else's register. Checked per incident against
	# the keys the default set would have offered instead.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	for incident:StringName in BarkSet.BARKS:
		var line:Dictionary = set.get_bark_for(incident, {}, [], true)
		assert_true(String(line.key).begins_with('bark.nhp_morrigan.'),
			'%s came back as one of ours, not bark_unknown: %s' % [incident, line.key])
		assert_false(String(line.text).is_empty(), '%s has text.' % incident)

func test_no_line_carries_a_format_placeholder():
	# is_bark_available_to_play SKIPS a line whose {placeholder} has no value, so a stray brace
	# would make a line silently unplayable rather than render wrong. None of the 38 use one -
	# PESTILENCE's 38 do not either - and this is what keeps that true.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	for incident:StringName in LINES_PER_INCIDENT:
		for key:StringName in set.get_possible_bark_keys_for(incident):
			assert_false(X.tr(key).contains('{'), '%s is plain prose: %s' % [key, X.tr(key)])

func test_the_comma_bearing_line_survived_the_csv():
	# localizations.csv is comma-separated and exactly one line contains a comma, so it is the
	# only row that had to be quoted. An unquoted one would have truncated at the comma and left
	# the remainder as a phantom second column - which imports without error.
	assert_eq(X.tr('bark.nhp_morrigan.overcharge.1'), 'WE CANNOT STOP, WE CANNOT FALTER',
		'The quoted row round-tripped whole.')

func test_the_display_name_comes_from_our_own_artifact():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_ne(translation.get_message('bark.nhp_morrigan'), StringName(''),
		'Our own artifact carries bark.nhp_morrigan.')
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	assert_eq(set.name(), 'NHP Morrígan',
		'Named from bark.nhp_morrigan via strip_prefix, diacritic and all - vanilla\'s "NHP Agni" casing.')

# ------------------------------------------------------- what the pilot adopts

func test_the_pilot_adopts_the_barkset_on_a_print():
	sluagh.core.full_repair()
	assert_true(BarkSet.is_valid(sluagh.core.pilot.nhp_barks), 'A barkset was adopted.')
	if not BarkSet.is_valid(sluagh.core.pilot.nhp_barks): return
	assert_eq(sluagh.core.pilot.nhp_barks.compcon_id, BARKSET, 'And it is this one.')
	assert_ne(sluagh.core.pilot.nhp_barks, barkset(),
		'As a DUPLICATE, not the shared library resource - the player may edit their copy.')

func test_the_pilot_adopts_the_name_from_the_csv():
	sluagh.core.full_repair()
	assert_eq(sluagh.core.pilot.nhp_name, 'Morrígan',
		'gear.ms_the_morrigan_class_nhp.default_name, adopted by inherit_default_nhp_settings.')

func test_the_pilot_adopts_the_portrait_and_it_ships_as_stock():
	sluagh.core.full_repair()
	var json:Dictionary = sluagh.core.pilot.nhp_portrait_json
	assert_false(json.is_empty(), 'A portrait was adopted.')
	assert_true(json.get('is_nhp', false), 'And it is an NHP portrait.')
	assert_true(json.get('is_stock', false),
		'Shipped as stock, matching pestilence.json: a player who later swaps NHPs gets that '
		+ 'NHP\'s face instead of being stuck with this one. The portrait editor exports false.')

func test_the_portrait_actually_deserializes():
	# A malformed or too-old json is refused at portrait_sandwich_core.gd:131-132 and the mech
	# renders with a blank face and nothing the player could act on.
	sluagh.core.full_repair()
	var core := PortraitSandwichCore.deserialize(sluagh.core.pilot.nhp_portrait_json, true)
	assert_true(is_instance_valid(core), 'The author json survives deserialization.')
	if is_instance_valid(core): assert_true(core.is_nhp, 'As an NHP.')

func test_a_hand_authored_face_is_not_overwritten():
	sluagh.core.pilot.nhp_name = 'Someone Else'
	sluagh.core.pilot.nhp_portrait_json = {is_stock = false, is_nhp = true}
	sluagh.core.full_repair()
	assert_eq(sluagh.core.pilot.nhp_name, 'Someone Else', 'A custom name survives.')
	assert_false(sluagh.core.pilot.nhp_portrait_json.get('is_stock', true),
		'And so does the custom portrait.')

func test_a_hand_authored_barkset_is_not_overwritten():
	# The barkset has no is_stock notion: the guard is is_blank(), i.e. the default id and no
	# custom content (bark_set.gd:73-79). A player's own set is kept.
	var mine := BarkSet.new()
	mine.compcon_id = &'bark_ritualist'
	sluagh.core.pilot.nhp_barks = mine
	sluagh.core.full_repair()
	assert_eq(sluagh.core.pilot.nhp_barks.compcon_id, &'bark_ritualist', 'A chosen barkset survives.')
