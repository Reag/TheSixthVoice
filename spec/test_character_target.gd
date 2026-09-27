# The CHARACTER TARGET helper (close-out Pass F Task 11, 2026-09-27, author decision T14): a buff-
# applying action that may target a drone. Each consumer's own spec is the behavioural proof
# (test_fell_the_mighty.gd, test_entrap_rakshasa.gd, test_reinforcement_blast.gd); this file pins the
# interface, and that the helper is vanilla's can_target_unit minus only its is_actor() line.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_character_target.gd
extends GutTest

const FitzgeraldFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/fitzgerald_fixture.gd')
const CharacterTarget := preload('res://unpacked/Reag-TheSixthVoice/res/content/gear/shared/character_target/character_target.gd')

const SYSTEM_ID := &'ms_grit_latch_magnets'
const ACTION_ID := &'action_reinforcement_blast'
const FITZ_TILE := Vector2i(2, 4)
const DRONE_TILE := Vector2i(4, 4)
const COVER_TILE := Vector2i(4, 6)

# test_lockon.gd's shape: TYPE_BOOL=1, TYPE_OBJECT=24.
const FROZEN_SIGNATURES := {
	can_target_drone = {
		args = [
			['action', TYPE_OBJECT, &'ActionSystemApplyBuff'],
			['target', TYPE_OBJECT, &'Unit'],
			['specific', TYPE_OBJECT, &'SpecificAction'],
		],
		return_type = TYPE_BOOL, return_class = &'',
	},
}

var game:Gamemaster
var fitz:Unit
var magnets:GearCore

func before_each() -> void:
	game = FitzgeraldFixture.create_game(self)
	fitz = FitzgeraldFixture.create_fitzgerald(game, FITZ_TILE)
	magnets = fitz.core.equip_system(SYSTEM_ID)

func _specific() -> SpecificAction:
	return SpecificAction.create(fitz, magnets, magnets.kit.get_action(ACTION_ID))

func test_the_frozen_interface_pins_this_one_signature():
	# Through a Script-typed local: a preloaded constant in call position is read as a class
	# (test_overshield.gd records the error).
	var script:Script = CharacterTarget
	var by_name:Dictionary = {}
	for entry:Dictionary in script.get_script_method_list(): by_name[entry.name] = entry

	var names:Array = by_name.keys()
	names.sort()
	var expected_names:Array = []
	for key in FROZEN_SIGNATURES: expected_names.append(String(key))
	expected_names.sort()
	assert_eq(names, expected_names, 'Exactly this one method exists today (additions update this list).')

	for required:String in FROZEN_SIGNATURES:
		assert_true(by_name.has(required), 'CharacterTarget.%s survives.' % required)
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

func test_only_the_is_actor_line_differs_from_vanilla():
	# The same action, the same drone: vanilla's function refuses it on is_actor() alone, the helper
	# does not. And the helper keeps vanilla's other gates: a Hidden drone is refused by the helper through
	# the copied is_hidden_from line. (Vanilla refuses any drone at :64 first, so only the helper's answer
	# can show that gate.)
	var drone := FitzgeraldFixture.create_drone(game, DRONE_TILE, Faction.AI_ENEMY)
	var specific := _specific()
	var vanilla := ActionSystemApplyBuff.new() # the stock script, Reinforcement Blast's one relevant export
	vanilla.can_apply_to_self = true
	assert_true(drone.is_drone(), 'fixture: a drone.')
	assert_false(vanilla.can_target_unit(drone, specific), "Vanilla's function refuses the drone (:64).")
	assert_true(CharacterTarget.can_target_drone(vanilla, drone, specific), 'The helper, same action, takes it.')
	assert_true(CharacterTarget.can_target_drone(specific.action, drone, specific), 'As it does for the real .tres.')
	SpecFactory.apply(drone, Lancer.STATUS.HIDDEN)
	assert_false(CharacterTarget.can_target_drone(specific.action, drone, specific),
		'A Hidden drone is refused: vanilla\'s is_hidden_from gate survives the copy.')

func test_consumers_still_refuse_an_object():
	# Only a drone is routed to the helper; an object still meets vanilla's is_actor() line.
	var cover := FitzgeraldFixture.create_deployable(game, COVER_TILE, 40, 0, 5)
	assert_false(cover.is_actor(), 'fixture: an object.')
	assert_false(cover.is_drone(), 'fixture: not a drone.')
	var specific := _specific()
	assert_false(specific.action.can_target_unit(cover, specific), 'Reinforcement Blast still refuses cover.')
