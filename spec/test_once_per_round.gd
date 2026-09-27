# The ONCE-PER-ROUND ON-HIT helper (close-out Pass D, 2026-09-27), extracted from four line-for-line
# copies: the Fitzgerald's Knock 'Em Down, the Maiden's Blush's Rend, and the Primrose's Magnetic
# Weight Redistribution and Wormhole Grasp. Each consumer's own spec is the behavioural proof; this
# file pins the interface and the two gates the helper owns.
#
#   godot --resolution 800x600 --position -2400,-2400 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_once_per_round.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const OncePerRound := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/once_per_round/once_per_round.gd')

const TRAIT_ID := &'mt_knock_em_down'
const USAGE_KEY := &'knock_em_down'

const FITZGERALD_TILE := Vector2i(4, 4)
const TARGET_TILE := Vector2i(8, 4)

# test_lockon.gd's shape: TYPE_BOOL=1, TYPE_STRING_NAME=21, TYPE_OBJECT=24, TYPE_NIL=0 for void.
const FROZEN_SIGNATURES := {
	is_unspent = {
		args = [['gear', TYPE_OBJECT, &'GearCore'], ['usage_key', TYPE_STRING_NAME, &'']],
		return_type = TYPE_BOOL, return_class = &'',
	},
	spend = {
		args = [
			['attacker', TYPE_OBJECT, &'Unit'],
			['target', TYPE_OBJECT, &'Unit'],
			['gear_id', TYPE_STRING_NAME, &''],
			['usage_key', TYPE_STRING_NAME, &''],
		],
		return_type = TYPE_NIL, return_class = &'',
	},
}

var game:Gamemaster
var fitzgerald:Unit

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	fitzgerald = FitzgeraldFixture.create_fitzgerald(game, FITZGERALD_TILE)

func _trait_gear() -> GearCore:
	return fitzgerald.get_gear(TRAIT_ID)

func test_the_frozen_interface_pins_these_two_signatures():
	# Through a Script-typed local, as test_lockon.gd does: a preloaded constant in call position is
	# read as a class.
	var script:Script = OncePerRound
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	var names:Array = by_name.keys()
	names.sort()
	var expected_names:Array = []
	for key in FROZEN_SIGNATURES: expected_names.append(String(key))
	expected_names.sort()
	assert_eq(names, expected_names, 'Exactly these two methods exist (additions update this list).')

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'OncePerRound.%s survives.' % required)
		if not by_name.has(required): continue
		var entry:Dictionary = by_name[required]
		var expected:Dictionary = FROZEN_SIGNATURES[required]
		var expected_args:Array = expected.args
		assert_eq(entry.args.size(), expected_args.size(),
			'%s takes exactly %d argument(s).' % [required, expected_args.size()])
		for i:int in range(min(entry.args.size(), expected_args.size())):
			var actual_arg:Dictionary = entry.args[i]
			var expected_arg:Array = expected_args[i]
			assert_eq(actual_arg.name, expected_arg[0], '%s arg %d is named "%s".' % [required, i, expected_arg[0]])
			assert_eq(actual_arg.type, expected_arg[1], '%s arg %d has the frozen Variant.Type.' % [required, i])
			assert_eq(actual_arg.class_name, expected_arg[2], '%s arg %d has the frozen class_name.' % [required, i])
		assert_true((entry.flags & METHOD_FLAG_STATIC) != 0, '%s is static.' % required)
		assert_eq(entry.default_args.size(), 0, '%s takes no default arguments.' % required)
		assert_eq(entry.return.type, expected.return_type, '%s has the frozen return Variant.Type.' % required)
		assert_eq(entry.return.class_name, expected.return_class, '%s has the frozen return class_name.' % required)

func test_a_spend_on_a_character_closes_the_round():
	var target := FitzgeraldFixture.create_dummy(game, TARGET_TILE, 10)
	var gear := _trait_gear()
	assert_true(GearCore.is_valid(gear), 'Fixture: the Fitzgerald carries Knock \'Em Down.')
	assert_true(OncePerRound.is_unspent(gear, USAGE_KEY), 'A fresh round is unspent.')

	OncePerRound.spend(fitzgerald, target, TRAIT_ID, USAGE_KEY)

	assert_eq(gear.get_uses_this_round_alt(USAGE_KEY), 1, 'One spend is one use.')
	assert_false(OncePerRound.is_unspent(gear, USAGE_KEY), 'And the round now reads spent.')

func test_a_spend_on_a_non_character_spends_nothing():
	var cover := FitzgeraldFixture.create_deployable(game, TARGET_TILE, 10, 0, 10)
	assert_false(cover.is_character(), 'Fixture: a Jericho cover is not a character.')

	OncePerRound.spend(fitzgerald, cover, TRAIT_ID, USAGE_KEY)

	assert_eq(_trait_gear().get_uses_this_round_alt(USAGE_KEY), 0,
		'A hit on an object forces no save, so it spends nothing.')

func test_the_helper_is_null_safe():
	var target := FitzgeraldFixture.create_dummy(game, TARGET_TILE, 10)
	assert_false(OncePerRound.is_unspent(null, USAGE_KEY), 'No gear reads spent, never open.')
	OncePerRound.spend(null, target, TRAIT_ID, USAGE_KEY)
	OncePerRound.spend(fitzgerald, null, TRAIT_ID, USAGE_KEY)
	OncePerRound.spend(target, target, TRAIT_ID, USAGE_KEY) # a unit without the trait
	assert_eq(_trait_gear().get_uses_this_round_alt(USAGE_KEY), 0, 'None of those spent anything.')
