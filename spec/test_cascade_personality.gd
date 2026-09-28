# CASCADE PERSONALITIES - our NHPs' personality file for fateofman's Cascade Personalities mod.
#
# THE MECHANISM IS ONE JSON FILE AND NO CODE. Cascade Personalities' personality_registry.gd walks
# every installed mod's res/ files and reads any .json under /res/cascade_personality/, keyed by NHP
# kit id (its MODDING.md). Without that mod installed, LancerTacticsMod hands the .json to the
# resource groups as a "new resource" and no resgrp glob matches .json, so it is dropped silently
# (lancer_tactics_mod.gd:82-91) - the portrait JSONs already ride that path. Nothing to guard.
#
# THIS SPEC NEEDS NONE OF FATEOFMAN'S CODE. It mirrors the registry's own rules
# (personality_registry.gd:10-15, 61-78 in fateofman-cascade_personalities 1.43.0): nine trait
# names, two of them 0..1 and the rest -1..1, clamped with a warning when out of range - so a value
# that would clamp is a bug here, not a warning there. Tag names are the set MODDING.md says the
# scorer emits. The end-to-end half - the registry actually resolving our kits - is the opt-in
# spec/test_cascade_integration.gd, which is PENDING unless fateofman's folders are unpacked.
#
# Design: D:/DEV/lancer-tactics-claude/specs/2026-09-28-cascade-personalities-integration-design.md
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log C:/Users/User/AppData/Local/Temp/x.log --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_cascade_personality.gd
extends GutTest

const ModResources := preload('res://testkit/mod_resources.gd')

const MOD_ID := 'Reag-TheSixthVoice'
const MOD_RES_DIR := 'res://unpacked/Reag-TheSixthVoice/'
const FOLDER := 'res://unpacked/Reag-TheSixthVoice/res/cascade_personality'
const FILE_NAME := 'sixth_voice.json'
const FILE := FOLDER + '/' + FILE_NAME

## Every NHP Kit this mod ships. A fifth NHP added without a personality goes red below.
const OUR_NHP_KITS:Array[StringName] = [
	&'ms_brigid_class_nhp',
	&'ms_jormungandr_class_nhp',
	&'ms_the_morrigan_class_nhp',
]

## personality_registry.gd KNOWN_TRAITS and ZERO_TO_ONE_TRAITS, verbatim.
const KNOWN_TRAITS:Array[StringName] = [
	&'subtlety', &'logical_emotional', &'aggression', &'esotericism', &'range_preference',
	&'relationship_with_pilot', &'self_preservation', &'restraint', &'misanthropy',
]
const ZERO_TO_ONE_TRAITS:Array[StringName] = [&'esotericism', &'range_preference']

## The tags MODDING.md documents the scorer emitting (action_traits.gd get_tags + system_category.gd
## CATEGORY_TAGS). An unknown tag is not an error to the registry - it is simply never matched, which
## is exactly the silent no-op this list exists to catch.
const KNOWN_TAGS:Array[StringName] = [
	# system type
	&'nhp', &'shield', &'buff', &'debuff', &'grenade', &'mine', &'drone', &'deployable', &'utility',
	# action kind
	&'protocol', &'reaction', &'overcharge', &'core_power', &'teleport', &'disengage',
	# attacks
	&'attack', &'melee', &'aoe', &'tech',
	# weapon tags and damage types
	&'knockback', &'loading', &'thrown', &'arcing', &'seeking', &'kinetic', &'energy', &'explosive', &'burn', &'heat',
	# inflicted statuses
	&'grappled', &'stunned', &'impaired', &'slowed', &'immobilized', &'lockon',
]

func _parsed() -> Dictionary:
	if not FileAccess.file_exists(FILE): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed if parsed is Dictionary else {}

func _personalities() -> Dictionary:
	var personalities = _parsed().get('personalities', {})
	return personalities if personalities is Dictionary else {}

func test_the_folder_holds_exactly_our_one_json_file():
	assert_true(DirAccess.dir_exists_absolute(FOLDER), '%s exists.' % FOLDER)
	if not DirAccess.dir_exists_absolute(FOLDER): return
	var jsons:Array[String] = []
	for file_name:String in DirAccess.get_files_at(FOLDER):
		if file_name.get_extension() == 'json': jsons.append(file_name)
	assert_eq(jsons, [FILE_NAME], 'One personality file, named as the design says. Every .json in this folder is read by the registry.')

func test_the_file_is_a_json_object_with_a_personalities_object():
	assert_true(FileAccess.file_exists(FILE), '%s exists.' % FILE)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	assert_true(parsed is Dictionary, 'The file parses to a JSON object (the registry skips anything else with a warning).')
	assert_true(_parsed().get('personalities') is Dictionary, 'It carries a "personalities" object.')
	assert_false(_parsed().has('action_tags'), 'No action_tags: nothing of ours needs an undetectable tag (design §3).')
	assert_false(_parsed().has('bark_incidents'), 'No bark_incidents: our NHPs raise no custom incidents (design §3).')

func test_every_personality_names_one_of_our_own_nhp_kits():
	var personalities := _personalities()
	assert_false(personalities.is_empty(), 'At least one personality.')
	for kit_id in personalities:
		var id := StringName(kit_id)
		assert_true(OUR_NHP_KITS.has(id), '%s is one of this mod\'s NHP kits.' % kit_id)
		var kit:Kit = ContentLibrary.get_kit(id)
		assert_true(Kit.is_valid(kit), '%s is a Kit ContentLibrary knows.' % kit_id)
		if not Kit.is_valid(kit): continue
		assert_true(kit.is_nhp(), '%s carries the NHP tag - the bit Cascades keys on.' % kit_id)
		var path:String = ContentLibrary.main.compcon_id_to_path.get(id, '')
		assert_true(path.begins_with(MOD_RES_DIR), '%s is OUR resource, at %s.' % [kit_id, path])
		assert_true(personalities[kit_id] is Dictionary, '%s\'s personality is an object.' % kit_id)

func test_every_nhp_kit_this_mod_ships_has_a_personality():
	var personalities := _personalities()
	var found:Array[StringName] = []
	for resource:Resource in ModResources.load_ours(MOD_ID, &'kits'):
		if resource is Kit and resource.is_nhp(): found.append(resource.compcon_id)
	found.sort()
	var expected:Array[StringName] = OUR_NHP_KITS.duplicate()
	expected.sort()
	assert_eq(found, expected, 'OUR_NHP_KITS lists exactly the NHP kits in this mod - update both when an NHP is added.')
	for id:StringName in found:
		assert_true(personalities.has(String(id)), '%s has a personality entry.' % id)

func test_every_trait_is_known_and_inside_the_registrys_range():
	var personalities := _personalities()
	for kit_id in personalities:
		var weights = personalities[kit_id].get('trait_weights', {})
		assert_true(weights is Dictionary, '%s.trait_weights is an object.' % kit_id)
		if not (weights is Dictionary): continue
		assert_eq(weights.size(), KNOWN_TRAITS.size(), '%s sets all nine axes explicitly (a missing axis is neutral; we say so on purpose).' % kit_id)
		for trait_name in weights:
			var trait_id := StringName(trait_name)
			assert_true(KNOWN_TRAITS.has(trait_id), '%s.%s is a trait the registry knows.' % [kit_id, trait_name])
			var value = weights[trait_name]
			assert_true(value is float or value is int, '%s.%s is a number.' % [kit_id, trait_name])
			if not (value is float or value is int): continue
			var minimum := 0.0 if ZERO_TO_ONE_TRAITS.has(trait_id) else -1.0
			assert_between(float(value), minimum, 1.0, '%s.%s = %s is inside %s..1, so the registry never clamps it.' % [kit_id, trait_name, value, minimum])

func test_every_tag_affinity_is_a_known_tag_with_a_number():
	var personalities := _personalities()
	for kit_id in personalities:
		var affinity = personalities[kit_id].get('tag_affinity', {})
		assert_true(affinity is Dictionary, '%s.tag_affinity is an object.' % kit_id)
		if not (affinity is Dictionary): continue
		assert_false(affinity.is_empty(), '%s names at least one favourite kind of action.' % kit_id)
		for tag in affinity:
			assert_true(KNOWN_TAGS.has(StringName(tag)), '%s.tag_affinity.%s is a tag the scorer emits.' % [kit_id, tag])
			assert_true(affinity[tag] is float or affinity[tag] is int, '%s.tag_affinity.%s is a number.' % [kit_id, tag])

func test_the_authors_rulings_are_the_shipped_values():
	# Design §3, D3 (2026-09-28): Jörmungandr at every extreme but esotericism; the Morrígan's pilot
	# bond maxed (Bel's yandere read); Brigid never catches an ally.
	var personalities := _personalities()
	var jormungandr:Dictionary = personalities.get('ms_jormungandr_class_nhp', {}).get('trait_weights', {})
	for extreme_positive:String in ['aggression', 'misanthropy', 'logical_emotional']:
		assert_eq(float(jormungandr.get(extreme_positive, 0.0)), 1.0, 'Jörmungandr %s is 1.0.' % extreme_positive)
	for extreme_negative:String in ['self_preservation', 'restraint', 'subtlety', 'relationship_with_pilot']:
		assert_eq(float(jormungandr.get(extreme_negative, 0.0)), -1.0, 'Jörmungandr %s is -1.0.' % extreme_negative)
	assert_eq(float(jormungandr.get('range_preference', 0.5)), 0.0, 'Jörmungandr wants to be close.')
	assert_eq(float(jormungandr.get('esotericism', 0.0)), 0.2, 'Jörmungandr is violent, not strange - the one axis off its extreme.')
	var morrigan:Dictionary = personalities.get('ms_the_morrigan_class_nhp', {}).get('trait_weights', {})
	assert_eq(float(morrigan.get('relationship_with_pilot', 0.0)), 1.0, 'The Morrígan is devoted to her pilot.')
	var brigid:Dictionary = personalities.get('ms_brigid_class_nhp', {}).get('trait_weights', {})
	assert_eq(float(brigid.get('misanthropy', 0.0)), -1.0, 'Brigid never catches an ally.')
	assert_eq(float(brigid.get('relationship_with_pilot', 0.0)), 1.0, 'Brigid is the pilot\'s guardian angel.')
