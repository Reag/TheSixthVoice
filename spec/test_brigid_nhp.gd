# BRIGID-CLASS NHP: the face, the name and the voice (Hazard SP4 Task 3). The Kit and Rallying Cry
# themselves are spec/test_rallying_cry.gd; this file is the barkset, the portrait, and the
# PassiveAiPrivilege that hands both to the pilot - the Morrígan's and the Jörmungandr's shape
# (test_morrigan_nhp.gd, test_jormungandr_nhp.gd), read those headers for the long form.
#
# THE NHP BIT IS WHAT MAKES ANY OF THIS AUDIBLE. Design ruling 13 set system_tags = 5 (UNIQUE + AI,
# the card's two tags). But UnitCore.has_nhp_copilot() reads Kit.is_nhp() and nothing else
# (unit_core.gd:319), and it gates the NHP speaking at all (unit_bark.gd:39) and her face on the
# token, tooltip, sheet and roster. With 5 the barkset and portrait below would be adopted by the
# pilot and then never used. So the Kit carries 13, every vanilla NHP's value and the Morrígan's
# and the Jörmungandr's; test_the_hazard_has_an_nhp_copilot is the pin.
#
# THE LINES ARE NOT IN THE RESOURCE. bark_nhp_brigid.tres is an empty BarkSet; the 38 lines are
# bark.nhp_brigid.<incident>.<N> rows in localizations.csv, found by counting N upward from 1 and
# STOPPING AT THE FIRST MISSING KEY (bark_set.gd:168-186).
#
# FRIENDLY_FIRE_TARGET WAS SILENT AT SP4 (the author's file had no lines for it) AND IS VOICED SINCE
# THE AUTHOR'S 358beb5 (2026-09-24), which added two rows. The silence test went with it; the voiced
# test below now covers the incident like every other.
#
# BARKS ARE THIS MOD'S ONE EXEMPTION FROM localization-matches-the-lcp. The lines are the author's
# file (D:/DEV/lancer-tactics-claude/brigid_barks.txt) transcribed verbatim, trailing spaces trimmed
# - "Lets", "em", "Dont", "peazy" carry the author's own spelling.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_brigid_nhp.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')

## test_morrigan_nhp.gd's convention: read THIS MOD'S OWN compiled artifact, not the global tr().
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

const KIT_ID := &'ms_brigid_class_nhp'
const BARKSET := &'bark_nhp_brigid'
const PORTRAIT_PATH := 'res://unpacked/Reag-TheSixthVoice/res/content/portraits/default_nhps/brigid.json'
const HAZARD_TILE := Vector2i(4, 6)

## Every incident and the number of lines the author wrote for it.
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
	&'friendly_fire_target': 2, # added by the author in 358beb5 (2026-09-24); was silent at SP4
	&'core_power': 2,
	&'overcharge': 2,
	&'brace': 2,
	&'leader_accuracy': 1,
	&'leader_damage': 1,
	&'leader_reduce': 1,
}
const TOTAL_LINES := 38

var game:Gamemaster
var hazard:Unit

func before_each() -> void:
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	Fixture.equip(hazard, KIT_ID)
	# equip has already printed the mech, so the pilot may carry the adopted defaults from that.
	# Clear all three so each test watches the adoption happen (test_morrigan_nhp.gd's reason).
	hazard.core.pilot.nhp_name = ''
	hazard.core.pilot.nhp_portrait_json = {}
	hazard.core.pilot.nhp_barks = null

func privilege() -> PassiveAiPrivilege:
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	var found:Array[Passive] = kit.get_passives(PassiveAiPrivilege)
	return found[0] as PassiveAiPrivilege if not found.is_empty() else null

func barkset() -> BarkSet:
	return ContentLibrary.get_barkset(BARKSET)

# ------------------------------------------------------------------ the wiring

func test_the_kit_carries_one_ai_privilege_with_both_defaults():
	var kit:Kit = ContentLibrary.get_kit(KIT_ID)
	assert_not_null(kit, 'The Kit loads.')
	if kit == null: return
	assert_eq(kit.get_passives(PassiveAiPrivilege).size(), 1, 'One PassiveAiPrivilege.')
	var passive := privilege()
	if passive == null: return
	assert_not_null(passive.default_portrait, 'It names a default portrait.')
	assert_true(BarkSet.is_valid(passive.default_barkset), 'And a default barkset.')
	if BarkSet.is_valid(passive.default_barkset):
		assert_eq(passive.default_barkset.compcon_id, BARKSET, 'This one.')

func test_it_stays_an_ordinary_one_per_mech_ai():
	var passive := privilege()
	if passive == null: return fail_test('The privilege exists.')
	assert_true(passive.counts_against_limit, 'Counts against the one-AI limit.')
	assert_false(passive.increases_limit, 'Does not raise it.')
	assert_false(passive.can_benefit_from_talents, 'As every vanilla NHP but the Lesson of Shaping.')

func test_the_hazard_has_an_nhp_copilot():
	# The load-bearing reason for system_tags 13 (header). Without it nothing below is ever heard.
	assert_true(hazard.core.has_nhp_copilot(), 'Brigid counts as an NHP co-pilot.')

# ------------------------------------------------------------------ the barkset

func test_the_barkset_is_indexed_and_named():
	var set:BarkSet = barkset()
	assert_true(BarkSet.is_valid(set), '%s is in the barks index (**/bark_*.tres).' % BARKSET)
	if not BarkSet.is_valid(set): return
	assert_true(set.is_nhp, 'Flagged as an NHP barkset.')
	assert_eq(set.compcon_id, BARKSET, 'Indexed under its own filename.')
	assert_eq(set.name(), 'NHP Brigid', 'bark.nhp_brigid, the author\'s display name.')

func test_the_display_name_comes_from_our_own_artifact():
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	assert_ne(translation.get_message('bark.nhp_brigid'), StringName(''), 'Our own artifact carries bark.nhp_brigid.')

func test_the_barkset_carries_no_resource_state_of_its_own():
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	assert_true(set.custom.is_empty(), 'No straight-text overrides.')
	assert_true(set.redirects.is_empty(), 'No redirects.')
	assert_true(set.probabilities.is_empty(), 'No probability overrides - the author\'s odds are the defaults.')
	assert_false(set.intentionally_blank, 'Not marked intentionally blank.')

func test_every_incident_uses_the_engine_default_odds():
	# The author's table, restated against BarkSet.BARKS (1.4.3).
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
	assert_eq(LINES_PER_INCIDENT.size(), BarkSet.BARKS.size(), 'Every incident the engine offers is listed.')

func test_every_voiced_incident_is_hers_and_not_the_default():
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	for incident:StringName in LINES_PER_INCIDENT:
		if int(LINES_PER_INCIDENT[incident]) == 0: continue
		var line:Dictionary = set.get_bark_for(incident, {}, [], true)
		assert_true(String(line.key).begins_with('bark.nhp_brigid.'),
			'%s came back as one of ours, not bark_unknown: %s' % [incident, line.key])
		assert_false(String(line.text).is_empty(), '%s has text.' % incident)

func test_no_line_carries_a_format_placeholder():
	var set:BarkSet = barkset()
	if not BarkSet.is_valid(set): return fail_test('%s resolves.' % BARKSET)
	for incident:StringName in LINES_PER_INCIDENT:
		for key:StringName in set.get_possible_bark_keys_for(incident):
			assert_false(X.tr(key).contains('{'), '%s is plain prose: %s' % [key, X.tr(key)])

func test_the_comma_bearing_line_survived_the_csv():
	assert_eq(X.tr('bark.nhp_brigid.destroy_self.2'), "I'll be okay, keep going!", 'The quoted row round-tripped whole.')

func test_the_apostrophes_and_the_authors_spelling_are_verbatim():
	assert_eq(X.tr('bark.nhp_brigid.destroy_self.3'), "You'll do great without me!", 'destroy_self.3.')
	assert_eq(X.tr('bark.nhp_brigid.leader_reduce.1'), "Isn't that better?", 'leader_reduce.1.')
	assert_eq(X.tr('bark.nhp_brigid.deploy.1'), 'Up and at em!', 'deploy.1, no apostrophe added.')
	assert_eq(X.tr('bark.nhp_brigid.destroy_target.2'), 'Easy peazy!', 'destroy_target.2, the author\'s spelling.')
	assert_eq(X.tr('bark.nhp_brigid.brace.2'), 'Try not to take another one of those please.', 'brace.2, the longest line.')

# ------------------------------------------------------------------ the portrait

func test_the_portrait_json_is_shipped_and_ships_as_stock():
	var json:JSON = load(PORTRAIT_PATH)
	assert_not_null(json, 'brigid.json is in the mod and loads as a JSON resource.')
	if json == null or json.data is not Dictionary: return
	var data:Dictionary = json.data
	assert_true(data.get('is_nhp', false), 'Marked an NHP portrait.')
	assert_true(data.get('is_stock', false),
		'Shipped as stock, matching morrigan.json and jormungandr.json - a deliberate edit to the '
		+ 'author\'s export, which says false.')

# ------------------------------------------------------- what the pilot adopts

func test_the_pilot_adopts_the_barkset_on_a_print():
	hazard.core.full_repair()
	assert_true(BarkSet.is_valid(hazard.core.pilot.nhp_barks), 'A barkset was adopted.')
	if not BarkSet.is_valid(hazard.core.pilot.nhp_barks): return
	assert_eq(hazard.core.pilot.nhp_barks.compcon_id, BARKSET, 'And it is this one.')
	assert_ne(hazard.core.pilot.nhp_barks, barkset(), 'As a DUPLICATE, not the shared library resource.')

func test_the_pilot_adopts_the_name_from_the_csv():
	hazard.core.full_repair()
	assert_eq(hazard.core.pilot.nhp_name, 'Brigid', 'gear.ms_brigid_class_nhp.default_name.')

func test_the_pilot_adopts_the_portrait_and_it_deserializes():
	hazard.core.full_repair()
	var json:Dictionary = hazard.core.pilot.nhp_portrait_json
	assert_false(json.is_empty(), 'A portrait was adopted.')
	assert_true(json.get('is_stock', false), 'The stock one.')
	var core := PortraitSandwichCore.deserialize(json, true)
	assert_true(is_instance_valid(core), 'The author json survives deserialization.')
	if is_instance_valid(core): assert_true(core.is_nhp, 'As an NHP.')

func test_a_hand_authored_face_is_not_overwritten():
	hazard.core.pilot.nhp_name = 'Someone Else'
	hazard.core.pilot.nhp_portrait_json = {is_stock = false, is_nhp = true}
	hazard.core.full_repair()
	assert_eq(hazard.core.pilot.nhp_name, 'Someone Else', 'A custom name survives.')
	assert_false(hazard.core.pilot.nhp_portrait_json.get('is_stock', true), 'And a custom face.')
