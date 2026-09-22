# JÖRMUNGANDR-CLASS NHP: the face, the name and the voice (Leoleth SP4, design ruling 17). The
# Automatic Retaliation Core's three effects are spec/test_automatic_retaliation.gd; this file is the
# barkset, the portrait, and the PassiveAiPrivilege that hands both to the pilot.
#
# THE KEY'S SPELLING IS THE ENGINE'S DECISION, NOT A STYLE CHOICE - the first thing SP4 had to
# settle. BarkSet.get_possible_bark_keys_for builds every key as
# 'bark.%s.%s.%s' % [prefixless_id, incident, index] (bark_set.gd:164-186), where prefixless_id is
# BarkSet.strip_prefix(compcon_id) and compcon_id is ContentLibrary.get_compcon_id(self) - the
# RESOURCE'S FILENAME. So the key is the .tres basename, and the author's written form
# `bark.nhp_Jörmungandr` would have meant shipping a non-ASCII filename through every resource-group
# glob and into every mod zip. The barkset is therefore bark_nhp_jormungandr.tres and the diaeresis
# lives where it is only ever displayed: in the ROWS. That is the Morrígan's shape exactly
# (bark.nhp_morrigan -> "NHP Morrígan"), and vanilla's too.
#
# THE LINES ARE NOT IN THE RESOURCE. bark_nhp_jormungandr.tres is an empty BarkSet; the 38 lines are
# bark.nhp_jormungandr.<incident>.<N> rows in localizations.csv, discovered by
# get_possible_bark_keys_for counting N upward from 1 and STOPPING AT THE FIRST MISSING KEY. A gap
# in the numbering is silent data loss with no error, which is why the per-incident counts below are
# asserted one by one rather than only in total.
#
# BARKS ARE THIS MOD'S ONE EXEMPTION FROM localization-matches-the-lcp: the supplement carries no
# bark lines for any NHP, so there is nothing to match. The lines are the author's file
# (specs/sixth-voice/jormungandr-barks.md) transcribed mechanically, not retyped.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_jormungandr_nhp.gd
extends GutTest

## test_morrigan_nhp.gd's convention: read THIS MOD'S OWN compiled artifact, not the global tr(), so
## a passing display-text test cannot be satisfied by a sibling Reag-* mod in the same run.
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const BARKSET := &'bark_nhp_jormungandr'
const PORTRAIT_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/portraits/default_nhps/jormungandr.json'

## Every incident and the number of lines the author wrote for it. The engine offers eighteen
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

func barkset() -> BarkSet:
	return ContentLibrary.get_barkset(BARKSET)

# ------------------------------------------------------------------ the barkset

func test_the_barkset_is_indexed_under_its_ascii_filename():
	var set:BarkSet = barkset()
	assert_true(BarkSet.is_valid(set), '%s is in the barks index (**/bark_*.tres).' % BARKSET)
	if not BarkSet.is_valid(set): return
	assert_true(set.is_nhp, 'Flagged as an NHP barkset, so the picker files it with the co-pilots.')
	assert_eq(set.compcon_id, BARKSET, 'Indexed under its own filename.')

func test_the_filename_is_what_every_bark_key_is_built_from():
	# The header's ruling, pinned at its source rather than trusted: strip_prefix of the compcon_id
	# is the middle segment of every key the engine will ever look up for this set.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	assert_eq(BarkSet.strip_prefix(set.compcon_id), 'nhp_jormungandr',
		'ASCII and lower case - the diaeresis would have had to be in the FILENAME.')
	var keys:Array[StringName] = set.get_possible_bark_keys_for(&'deploy')
	assert_false(keys.is_empty(), 'Deploy lines were found at all.')
	if keys.is_empty(): return
	assert_eq(keys[0], StringName('bark.nhp_jormungandr.deploy.1'),
		'And the key the engine builds is exactly the row we shipped.')

func test_the_barkset_carries_no_resource_state_of_its_own():
	# The author's stated odds match BarkSet.BARKS' defaults for all eighteen incidents, so
	# `probabilities` is deliberately empty rather than restating them; `custom` and `redirects` are
	# empty because the lines live in the CSV. is_blank() being TRUE is what lets a player adopt a
	# replacement later (bark_set.gd:73-79), so it is a feature, not an omission.
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
	# A missing incident is not silence: get_bark_for drops through to bark_unknown and JÖRMUNGANDR
	# speaks a generic NHP line in someone else's register.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	for incident:StringName in BarkSet.BARKS:
		var line:Dictionary = set.get_bark_for(incident, {}, [], true)
		assert_true(String(line.key).begins_with('bark.nhp_jormungandr.'),
			'%s came back as one of ours, not bark_unknown: %s' % [incident, line.key])
		assert_false(String(line.text).is_empty(), '%s has text.' % incident)

func test_no_line_carries_a_format_placeholder():
	# is_bark_available_to_play SKIPS a line whose {placeholder} has no value, so a stray brace would
	# make a line silently unplayable rather than render wrong. None of the 38 use one.
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	for incident:StringName in LINES_PER_INCIDENT:
		for key:StringName in set.get_possible_bark_keys_for(incident):
			assert_false(X.tr(key).contains('{'), '%s is plain prose: %s' % [key, X.tr(key)])

func test_the_six_comma_bearing_lines_survived_the_csv():
	# localizations.csv is comma-separated and six of the 38 contain a comma, so those six rows had
	# to be quoted. An unquoted one truncates at the comma and leaves the remainder as a phantom
	# second column - which imports without error.
	var expected := {
		'bark.nhp_jormungandr.destroy_target.3': 'LUCKY YOU, IM OUT OF TIME TO PLAY WITH MY FOOD',
		'bark.nhp_jormungandr.structure_self.1': 'AGAIN, AGAIN!',
		'bark.nhp_jormungandr.core_power.2': 'MY REACH IS BOUNDLESS, MY HATE IS INFINITE',
		'bark.nhp_jormungandr.overcharge.1': 'NEVER SLOW, NEVER STOP',
		'bark.nhp_jormungandr.overcharge.2': 'IF YOU SURVIVE, I HAVE FAILED',
		'bark.nhp_jormungandr.leader_damage.1': 'SWING HARDER, SHOOT FASTER',
	}
	for key:String in expected:
		assert_eq(X.tr(key), String(expected[key]), '%s round-tripped whole.' % key)

func test_the_apostrophe_free_lines_are_the_authors_own_spelling():
	# Transcribed mechanically from specs/sixth-voice/jormungandr-barks.md, not retyped: IM and DONT
	# carry no apostrophe in the author's file and must not acquire one.
	assert_eq(X.tr('bark.nhp_jormungandr.brace.1'), 'DONT DO THAT AGAIN', 'brace.1, verbatim.')
	assert_eq(X.tr('bark.nhp_jormungandr.destroy_ally.1'), 'DONT GET IN MY WAY', 'destroy_ally.1, verbatim.')

func test_the_question_mark_line_round_tripped():
	assert_eq(X.tr('bark.nhp_jormungandr.leader_reduce.1'),
		'WHAT THE HELL ARE YOU DOING? THEY NEED NOT LIVE', 'leader_reduce.1, verbatim.')

func test_the_display_name_keeps_its_diaeresis_and_comes_from_our_own_artifact():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_ne(translation.get_message('bark.nhp_jormungandr'), StringName(''),
		'Our own artifact carries bark.nhp_jormungandr.')
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	assert_eq(set.name(), 'NHP JÖRMUNGANDR',
		'Named from bark.nhp_jormungandr via strip_prefix - ASCII key, diaeresis in the ROW.')

# ------------------------------------------------------------------ the portrait

func test_the_portrait_json_is_shipped_and_parses():
	var json:JSON = load(PORTRAIT_PATH)
	assert_not_null(json, 'jormungandr.json is in the mod and imports as a JSON resource.')
	if json == null: return
	assert_true(json.data is Dictionary, 'It parses to a dictionary.')

func test_the_portrait_is_an_nhp_and_ships_as_stock():
	var json:JSON = load(PORTRAIT_PATH)
	if json == null or json.data is not Dictionary: return fail_test('jormungandr.json loads.')
	var data:Dictionary = json.data
	assert_true(data.get('is_nhp', false), 'Marked an NHP portrait.')
	assert_true(data.get('is_stock', false),
		'Shipped as stock, matching morrigan.json and pestilence.json: a player who later swaps '
		+ 'NHPs gets that NHP\'s face instead of being stuck with this one. The portrait editor '
		+ 'exports is_stock FALSE, so this is a deliberate edit to the author\'s file.')

func test_the_portrait_actually_deserializes():
	# A malformed or too-old json is refused at portrait_sandwich_core.gd:131-132 and the mech
	# renders with a blank face and nothing the player could act on.
	var json:JSON = load(PORTRAIT_PATH)
	if json == null or json.data is not Dictionary: return fail_test('jormungandr.json loads.')
	var core := PortraitSandwichCore.deserialize(json.data, true)
	assert_true(is_instance_valid(core), 'The author json survives deserialization.')
	if is_instance_valid(core): assert_true(core.is_nhp, 'As an NHP.')
