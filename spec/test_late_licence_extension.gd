# THE SIX SKY'S LICENCE IN EITHER INSTALL ORDER (frame close, 2026-09-27; the author's call) - AND THE
# BLACK MOUNTAIN'S, which rides the same carrier since its SP1 the same day (the last section).
#
# In the real game ModApplier installs one mod at a time and mounts each zip only as it installs it
# (mod_applier.gd:110-113, :139-141). Vanilla modset.gd:253 assigns an int to the dependency_importance
# Dictionary, so optional_dependencies orders nothing, and a player whose list has The Sixth Voice above
# HA Sunzi installs us FIRST. Then li_sunzi does not exist yet: extendable() drops it, and the engine's
# own queue skips it too (lancer_tactics_mod.gd:180-183) - the Six Sky is registered and never grantable.
#
# The fix queues a LATE extension on a key that always loads (our own frame), which the engine runs after
# every mod is installed and before ContentLibrary.initialize (mod_applier.gd:116, :121). A test run
# mounts every resident from disk before anything installs, so the real order cannot be reproduced; this
# spec pins the pieces instead: what is deferred, what is queued, and that the late call extends an
# un-extended li_sunzi exactly once, retains it, and does nothing for a player without the Sunzi.
#
#   powershell -ExecutionPolicy Bypass -File D:/DEV/lancer-tactics-claude/tools/run-hidden.ps1 -Log <ssd log> --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_late_licence_extension.gd
extends GutTest

const Fixture := preload('res://unpacked/Reag-TheSixthVoice/spec/six_sky_fixture.gd')

const MISSING := 'res://unpacked/nobody-absent_mod/res/content/licenses/x/li_absent.tres'
const VANILLA := 'res://content/licenses/gms/li_gms.tres'

## Loaded, not preloaded: a function missing from mod_main then fails the TEST at run time instead of
## failing this script's parse (GUT skips an unparsed script and the suite reads green).
var MainScript:Script = load('res://unpacked/Reag-TheSixthVoice/mod_main.gd')

var license:UnlockTree
var frame:Frame
var saved_frames:Array[Frame] = []
var saved_meta:bool

func before_each() -> void:
	license = load(Fixture.LICENSE_PATH)
	frame = ContentLibrary.get_mech_frame(Fixture.FRAME_ID)
	saved_frames.assign(license.rank_2.granted_frames)
	saved_meta = license.has_meta(MainScript.APPLIED_META)

## Every test leaves the shared, cached li_sunzi exactly as the run's install left it.
func after_each() -> void:
	license.rank_2.granted_frames.assign(saved_frames)
	if saved_meta: license.set_meta(MainScript.APPLIED_META, true)
	else: license.remove_meta(MainScript.APPLIED_META)

func six_skies() -> int:
	return license.rank_2.granted_frames.count(frame)

func test_fixture_the_run_installed_the_extension():
	assert_eq(six_skies(), 1, 'fixture: the run granted the Six Sky once.')
	assert_true(saved_meta, 'fixture: and stamped it applied.')

func test_only_a_missing_other_mod_path_is_deferred():
	var paths:Array[String] = [VANILLA, Fixture.LICENSE_PATH, MISSING]
	assert_eq(MainScript.deferred(paths), [MISSING] as Array[String],
		'Deferred: an unpacked path not mounted yet. Never a vanilla path, never a mounted one.')

func test_a_deferred_path_is_queued_on_the_carrier():
	var queue:Dictionary = {}
	MainScript.queue_late_extensions(queue, [MISSING] as Array[String], [])
	assert_eq(queue.keys(), [MainScript.LATE_EXTENSION_CARRIER], 'One key, the carrier, which always loads.')
	assert_eq(queue.get(MainScript.LATE_EXTENSION_CARRIER, []).size(), 1, 'One callable.')
	assert_true(ResourceLoader.exists(MainScript.LATE_EXTENSION_CARRIER), 'The carrier exists.')

func test_nothing_deferred_queues_nothing():
	var queue:Dictionary = {}
	MainScript.queue_late_extensions(queue, [] as Array[String], [])
	assert_true(queue.is_empty(), 'Nothing to defer: the queue is untouched.')

func test_the_late_call_extends_an_unextended_licence_once_and_retains_it():
	# The Sixth-Voice-first state: li_sunzi loaded fresh, no Six Sky, no stamp.
	license.rank_2.granted_frames.erase(frame)
	license.remove_meta(MainScript.APPLIED_META)
	assert_eq(six_skies(), 0, 'fixture: un-extended.')
	var retained:Array = []
	var carrier:Resource = load(MainScript.LATE_EXTENSION_CARRIER)
	var returned = MainScript.extend_late(carrier, [Fixture.LICENSE_PATH] as Array[String], retained)
	assert_eq(returned, carrier, 'The carrier comes back unchanged - never null (resource_extension.gd:23-30).')
	assert_eq(six_skies(), 1, 'The Six Sky is granted.')
	assert_true(license.has_meta(MainScript.APPLIED_META), 'Stamped.')
	assert_true(retained.has(license), 'Retained, so bug 7 cannot evaporate it before ContentLibrary loads it.')
	MainScript.extend_late(carrier, [Fixture.LICENSE_PATH] as Array[String], retained)
	assert_eq(six_skies(), 1, 'A second call does not append it again.')

func test_the_late_call_without_the_sunzi_does_nothing():
	var retained:Array = []
	var carrier:Resource = load(MainScript.LATE_EXTENSION_CARRIER)
	var returned = MainScript.extend_late(carrier, [MISSING] as Array[String], retained)
	assert_eq(returned, carrier, 'The carrier comes back.')
	assert_true(retained.is_empty(), 'Nothing loaded, nothing retained.')

# ---------------------------------------------------------------- the Black Mountain rides the same carrier

const BlackMountainFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/black_mountain_fixture.gd')

func test_the_emperor_licence_is_declared_and_deferrable_like_the_sunzis():
	assert_has(MainScript.EXTENDED_RESOURCES, BlackMountainFixture.LICENSE_PATH,
		'li_emperor is declared by the Emperor mod\'s own path.')
	var paths:Array[String] = [BlackMountainFixture.LICENSE_PATH, MISSING]
	assert_eq(MainScript.deferred(paths), [MISSING] as Array[String],
		'Mounted in a test run, so not deferred - the SAME test a Sixth-Voice-first install would fail and defer.')

func test_the_late_call_extends_an_unextended_emperor_licence_once_and_retains_it():
	# The Sixth-Voice-first state for li_emperor: loaded fresh, no Black Mountain, no stamp.
	var emperor_license:UnlockTree = load(BlackMountainFixture.LICENSE_PATH)
	var black_mountain:Frame = ContentLibrary.get_mech_frame(BlackMountainFixture.FRAME_ID)
	var saved:Array[Frame] = []
	saved.assign(emperor_license.rank_2.granted_frames)
	var was_stamped := emperor_license.has_meta(MainScript.APPLIED_META)
	emperor_license.rank_2.granted_frames.erase(black_mountain)
	emperor_license.remove_meta(MainScript.APPLIED_META)
	assert_eq(emperor_license.rank_2.granted_frames.count(black_mountain), 0, 'fixture: un-extended.')
	var retained:Array = []
	var carrier:Resource = load(MainScript.LATE_EXTENSION_CARRIER)
	var returned = MainScript.extend_late(carrier, [BlackMountainFixture.LICENSE_PATH] as Array[String], retained)
	assert_eq(returned, carrier, 'The carrier comes back unchanged.')
	assert_eq(emperor_license.rank_2.granted_frames.count(black_mountain), 1, 'The Black Mountain is granted.')
	assert_true(emperor_license.has_meta(MainScript.APPLIED_META), 'Stamped.')
	assert_true(retained.has(emperor_license), 'Retained.')
	MainScript.extend_late(carrier, [BlackMountainFixture.LICENSE_PATH] as Array[String], retained)
	assert_eq(emperor_license.rank_2.granted_frames.count(black_mountain), 1, 'A second call does not append it again.')
	# Leave the shared, cached li_emperor exactly as the run's install left it.
	emperor_license.rank_2.granted_frames.assign(saved)
	if was_stamped: emperor_license.set_meta(MainScript.APPLIED_META, true)
	else: emperor_license.remove_meta(MainScript.APPLIED_META)
