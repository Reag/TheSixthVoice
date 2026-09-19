# THE THREAT INDICATOR ON THE CHARACTER SHEET (author report, 2026-09-19).
#
#   "The DDMR does not increase the threat of the weapon it's attached to in the mech's pilot roster
#    screen. It does function correctly mechanically, but the actual threat indicator did not move
#    from 3 to 4."
#
# NOT A PRIMROSE BUG - A VANILLA UI GAP, and the file says so itself. range_display.gd:65-67 renders
# the PRINTED `attack.threat`, never `attack.threat_distance(specific)`. Its rerender_specific
# (:6-43) computes an override for AIM RANGE only, and does it with a block commented
# `# TEMPORARY HOTFIX HACK` that hard-codes two compcon ids - wm_stabilizer_mod +5 and
# cb_neurolink_targeting +3. The general buff walk that would have covered everything else is
# commented out below it under `# TOO CRASHY TO RUN OUT OF COMBAT` (:21-41). THREAT has no override
# parameter at all: `rerender(attack, aim_range_override)` takes one number and it is the aim range.
#
# So no weapon mod and no trait in the game can move that number, ours or anyone's. The DDMR is the
# report, but mt_artful_caress (+1 threat on Heavy and Superheavy melee, on this very frame) has the
# same gap and nobody noticed because the two stack on the same weapons.
#
# WHY THE EXTENSION WALKS STATIC DATA INSTEAD OF CALLING BuffBonus.get_bonus_for_subtype. Vanilla's
# own comment is the warning: the buff walk is "TOO CRASHY TO RUN OUT OF COMBAT". Reading it, the
# reason is concrete - BuffWeaponType.check_if_passive_applies ends at `from_weapon_mod and not
# context.gear.is_weapon_mod_attached(core.from_gear)` (buff_weapon_type.gd:53), and a BuffCore
# minted by hand for a display pass has no `from_gear`, so exactly the buffs we care about are the
# ones that dereference a null there. The extension therefore does what vanilla's WORKING hotfix
# does - reads the loadout - but generically, over whatever weapon mods and traits are fitted,
# instead of by hard-coded id. See the extension's own header for the filter rules it re-implements.
#
# ============================== WHY THIS SPEC EXISTS AT ALL ==============================
#
# THE INSTALL LOG IS NOT EVIDENCE THAT AN OVERRIDE RUNS (memory lancer-tactics-extension-seams):
# ModLoader logs a dead seam exactly as it logs a live one, and unit_action.gd is the known-dead
# case. Unlike the Spin FX - which ruling 20 puts beyond a spec, so its call site needed a
# source-level pin - this one is fully observable: TagIcon.rerender writes `Number.text = str(number)`
# (tag_icon.gd:22-24), so the number a player would actually read is a string this spec can assert.
# Every test below therefore fails if the extension is not installed, which is the point.
#
# THE CONTROLS ARE THE OTHER HALF. A widget that simply printed threat+1 for everything would pass
# the two positive tests, so the MAIN-melee and HEAVY-rifle cases below are load-bearing: they are
# the two filters buff_artful_caress declares (weapon_sizes [2,3], weapon_types [2]) and the DDMR
# repeats (allowed_sizes/allowed_types on its PassiveWeaponMod), and a display that ignored them
# would be lying in the other direction.
extends GutTest

const PrimroseFixture := preload('res://unpacked/Reag-TheSixthVoice/spec/primrose_fixture.gd')
const RANGE_DISPLAY_SCENE := 'res://ui/page/character_sheet/widgets/range_display.tscn'

const PRIMROSE_TILE := Vector2i(4, 4)
const OTHER_TILE := Vector2i(9, 9)

var game:Gamemaster
var primrose:Unit

func before_each() -> void:
	game = PrimroseFixture.create_game(self)
	primrose = PrimroseFixture.create_primrose(game, PRIMROSE_TILE)

## Render a unit's weapon through the real widget and hand back what the player would read.
##
## The widget has to be IN THE TREE before rerender_specific: TagIcon's Number/PreIcon are @onready
## (tag_icon.gd:5-9), so a rerender on a detached instance dereferences null. add_child_autoqfree
## puts it in and takes it out again per test.
func threat_shown_for(unit:Unit, kit_id:StringName) -> Dictionary:
	var specific := PrimroseFixture.specific(unit, kit_id)
	assert_true(SpecificAction.is_valid(specific), 'fixture: %s is equipped and has an action.' % kit_id)
	if not SpecificAction.is_valid(specific): return {}

	var widget:Node = load(RANGE_DISPLAY_SCENE).instantiate()
	add_child_autoqfree(widget)
	widget.rerender_specific(specific)

	var tag:Node = widget.get_node('%ThreatRange')
	return {
		printed = specific.action.threat,
		engine = specific.action.threat_distance(specific),
		shown = tag.Number.text,
		visible = tag.visible,
	}

# ------------------------------------------------------------------ the report

## The reported case, verbatim: a Heavy melee weapon on the Primrose with the DDMR fitted. The
## Primrose's own Artful Caress is the other +1, which is why the printed 1 reads 3 in play.
func test_a_ddmr_modded_heavy_melee_weapon_shows_its_buffed_threat():
	var weapon := PrimroseFixture.equip_heavy_melee(primrose)
	PrimroseFixture.fit_ddmr(primrose, weapon)

	var seen := threat_shown_for(primrose, PrimroseFixture.HEAVY_MELEE)
	assert_eq(seen.engine, 3, 'the engine measures 1 printed + 1 Caress + 1 DDMR.')
	assert_eq(seen.shown, '3', 'the sheet shows what the engine measures, not the printed 1.')
	assert_true(seen.visible, 'the threat indicator is on screen.')

## The same weapon WITHOUT the mod. Isolates the DDMR's own +1 from the frame trait's.
func test_the_same_weapon_without_the_ddmr_shows_one_less():
	PrimroseFixture.equip_heavy_melee(primrose)

	var seen := threat_shown_for(primrose, PrimroseFixture.HEAVY_MELEE)
	assert_eq(seen.engine, 2, 'the engine measures 1 printed + 1 Caress.')
	assert_eq(seen.shown, '2', 'the sheet follows the engine down as well as up.')

# ------------------------------------------------------------------ the filters

## MAIN melee: the right weapon TYPE, the wrong SIZE. buff_artful_caress declares
## weapon_sizes [2, 3] and the DDMR's PassiveWeaponMod allowed_sizes [2, 3].
func test_a_main_melee_weapon_shows_its_printed_threat():
	PrimroseFixture.equip(primrose, PrimroseFixture.MAIN_MELEE)

	var seen := threat_shown_for(primrose, PrimroseFixture.MAIN_MELEE)
	assert_eq(seen.engine, seen.printed, 'the engine adds nothing to a MAIN melee weapon.')
	assert_eq(seen.shown, str(seen.printed), 'and neither does the sheet.')

## HEAVY rifle: the right SIZE, the wrong TYPE. weapon_types [2] is MELEE.
##
## ASSERTED ON VISIBILITY, NOT ON TEXT, and that is not a softer test - it is the only correct one.
## A rifle with printed threat 1 takes rerender's else branch and %ThreatRange is HIDDEN
## (range_display.gd:65-69), so TagIcon.rerender never runs on it and Number.text is still the
## placeholder the scene ships with: `text = "10"` (tag_icon.tscn:22). The first draft of this test
## asserted the text and failed reading that placeholder back as though it were a rendered value -
## which is exactly the shape of a spec that passes while measuring nothing, so it is recorded here.
## What the extension must not do is make this indicator APPEAR.
func test_a_heavy_rifle_shows_no_threat_indicator_at_all():
	PrimroseFixture.equip(primrose, PrimroseFixture.HEAVY_RIFLE)

	var seen := threat_shown_for(primrose, PrimroseFixture.HEAVY_RIFLE)
	assert_eq(seen.engine, seen.printed, 'the engine adds nothing to a rifle.')
	assert_false(seen.visible, 'and the sheet does not start showing one.')

## A unit that is NOT a Primrose, carrying the identical weapon. Nothing this mod ships is fitted,
## so the sheet must read exactly as it does in a vanilla install - this is the test that fails if
## the extension starts inventing threat for everyone.
func test_a_weapon_on_another_frame_is_untouched():
	var other := SpecFactory.create_unit(game.map, OTHER_TILE)
	PrimroseFixture.equip(other, PrimroseFixture.HEAVY_MELEE)

	var seen := threat_shown_for(other, PrimroseFixture.HEAVY_MELEE)
	assert_eq(seen.engine, seen.printed, 'the engine adds nothing on a frame with no Caress.')
	assert_eq(seen.shown, str(seen.printed), 'and the sheet shows the printed value.')

# ------------------------------------------------------ what the extension must not break

## The aim-range half of rerender_specific is vanilla's and stays vanilla's: the override calls
## super() first and only touches %ThreatRange afterwards. A rifle is the case where AttackRange is
## the interesting number, so it is the one worth pinning.
func test_the_aim_range_half_still_renders():
	PrimroseFixture.equip_main_rifle(primrose)
	var specific := PrimroseFixture.specific(primrose, PrimroseFixture.MAIN_RIFLE)

	var widget:Node = load(RANGE_DISPLAY_SCENE).instantiate()
	add_child_autoqfree(widget)
	widget.rerender_specific(specific)

	var tag:Node = widget.get_node('%AttackRange')
	assert_true(tag.visible, 'the aim-range indicator is still drawn.')
	assert_eq(tag.Number.text, str(specific.action.aim_range), 'and still shows the printed range.')
