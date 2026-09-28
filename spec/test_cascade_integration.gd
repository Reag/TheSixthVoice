# CASCADE PERSONALITIES, END TO END - OPT-IN. Proves fateofman's registry actually resolves our NHP
# kits to res/cascade_personality/sixth_voice.json, and that a cascading Hazard plays as Brigid.
#
# fateofman's two mods are NOT residents and never will be (author's brief, 2026-09-28). A testkit
# run on 1.4.x loads only res://unpacked/ checkouts, so this spec can only see them when both zips
# are unpacked there by hand. Absent, every test is PENDING - not passing, not failing - with the
# recipe in its message. Present, the mods must be ACTIVE, or the tests fail: a folder that did not
# install is a broken run, not a quiet one.
#
# NOTHING HERE MAY NAME A FATEOFMAN CLASS OR PRELOAD A FATEOFMAN PATH: GDScript resolves both at
# parse time, and a spec that fails to parse is SKIPPED by GUT with the suite still reading green
# (CLAUDE.md). Everything is load()ed inside a test body, after the presence check.
#
# Design: D:/DEV/lancer-tactics-claude/specs/2026-09-28-cascade-personalities-integration-design.md §5
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/hazard_fixture.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const CASCADES_DIR := 'res://unpacked/fateofman-cascades'
const PERSONALITIES_DIR := 'res://unpacked/fateofman-cascade_personalities'
const CASCADE_UTIL := CASCADES_DIR + '/res/cascade_util.gd'
const REGISTRY := PERSONALITIES_DIR + '/res/personality_registry.gd'
const CASCADE_AI := PERSONALITIES_DIR + '/res/cascade_ai.gd'
const OUR_JSON := 'res://unpacked/Reag-TheSixthVoice/res/cascade_personality/sixth_voice.json'

const NHP_KIT := &'ms_brigid_class_nhp'
const HAZARD_TILE := Vector2i(4, 6)

const RECIPE := """OPT-IN: fateofman's mods are not unpacked. To run this spec:
  cd D:/DEV/lancer-tactics-modkit
  unzip -oq C:/Users/User/AppData/Roaming/LancerTactics/mods/fateofman-cascades.zip -d .
  unzip -oq C:/Users/User/AppData/Roaming/LancerTactics/mods/fateofman-cascade_personalities.zip -d .
  rm -f .godot/uid_cache.bin && "D:/DEV/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
  <run this spec through tools/run-hidden.ps1>
  rm -rf unpacked/fateofman-cascades unpacked/fateofman-cascade_personalities
  rm -f .godot/uid_cache.bin && <--import again>; git diff our mods for collateral re-saves."""

var game:Gamemaster
var hazard:Unit

static func fateofman_present() -> bool:
	return DirAccess.dir_exists_absolute(CASCADES_DIR) and DirAccess.dir_exists_absolute(PERSONALITIES_DIR)

func before_each() -> void:
	if not fateofman_present(): return
	game = Fixture.create_game(self)
	hazard = Fixture.create_hazard(game, HAZARD_TILE)
	Fixture.equip(hazard, NHP_KIT)

func _ours() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(OUR_JSON)).get('personalities', {})

func test_both_fateofman_mods_are_active_when_unpacked():
	if not fateofman_present(): return pending(RECIPE)
	assert_true(Compat.is_mod_active('fateofman-cascades'), 'fateofman-cascades installed from unpacked/.')
	assert_true(Compat.is_mod_active('fateofman-cascade_personalities'), 'fateofman-cascade_personalities installed from unpacked/.')

func test_the_registry_resolves_each_of_our_nhps_to_our_json():
	if not fateofman_present(): return pending(RECIPE)
	var registry = load(REGISTRY)
	var ours := _ours()
	for kit_id in ours:
		var found:Dictionary = registry.get_personality_for_kit(StringName(kit_id))
		assert_false(found.is_empty(), '%s is registered.' % kit_id)
		if found.is_empty(): continue
		var weights:Dictionary = found[&'trait_weights']
		for trait_name in ours[kit_id].trait_weights:
			assert_eq(weights.get(StringName(trait_name)), float(ours[kit_id].trait_weights[trait_name]),
				'%s.%s reached the registry unclamped.' % [kit_id, trait_name])
		var affinity:Dictionary = found[&'tag_affinity']
		for tag in ours[kit_id].tag_affinity:
			assert_eq(affinity.get(StringName(tag)), float(ours[kit_id].tag_affinity[tag]), '%s affinity %s reached the registry.' % [kit_id, tag])

func test_the_registry_warned_about_nothing_of_ours():
	if not fateofman_present(): return pending(RECIPE)
	# The registry logs a warning per malformed entry under its own mod id. We cannot read
	# modloader.log from here, so this pins the two things a warning would follow from: the file
	# parses, and every trait is already inside the range the registry clamps to (the schema spec
	# holds the full rule; this is the cross-check against the LIVE registry's own constants).
	var registry = load(REGISTRY)
	var ours := _ours()
	for kit_id in ours:
		for trait_name in ours[kit_id].trait_weights:
			var trait_id := StringName(trait_name)
			assert_true(registry.KNOWN_TRAITS.has(trait_id), '%s.%s is in the live registry\'s KNOWN_TRAITS.' % [kit_id, trait_name])
			var minimum:float = 0.0 if registry.ZERO_TO_ONE_TRAITS.has(trait_id) else -1.0
			assert_between(float(ours[kit_id].trait_weights[trait_name]), minimum, 1.0, '%s.%s inside the live range.' % [kit_id, trait_name])

func test_a_cascading_hazard_plays_as_brigid():
	if not fateofman_present(): return pending(RECIPE)
	var util = load(CASCADE_UTIL)
	var ai = load(CASCADE_AI)
	var gear:GearCore = hazard.get_gear(NHP_KIT)
	if not GearCore.is_valid(gear): return fail_test('Fixture: the Hazard carries Brigid.')

	# What Cascades does on a natural 1: mark the gear cascading, then the full takeover.
	gear.set_state(util.NHP_CASCADING_GEAR_STATE_KEY, true)
	util.apply_full_cascade(hazard, SpecFactory.dummy_event(), gear)

	assert_true(util.is_cascading(hazard), 'The Hazard is cascading.')
	assert_eq(hazard.get_faction(), Faction.AI_ALLY, 'And the AI holds it - which is what makes our is_player_controlled guards matter.')
	var traits:Dictionary = ai.get_traits(hazard)
	assert_eq(traits.get(&'misanthropy'), -1.0, 'Brigid never catches an ally - OUR value, not the neutral default.')
	assert_eq(traits.get(&'relationship_with_pilot'), 1.0, 'Brigid protects her pilot.')
	assert_eq(traits.get(&'aggression'), -0.6, 'Brigid would rather buff than shoot.')
