# LEOLETH SP3 PROBE (design 3.0): is a get_destructable_gear override on the UnitPrinter autoload
# reached from the STRUCTURE CHECK's real entry points, and from how deep?
#
# THE SEAM. Vanilla's get_destructable_gear (unit_printer.gd:311-320) requires has_charges_left(),
# which for a Limited Kit is charges_current > 0 (gear_core.gd:249). The Thermal Death Axe's card
# says "this weapon can be destroyed even if it has no charges remaining", so the mod's first
# unit_printer.gd_ext.gd whitelists it past that check by kit id - Thy Hubris' Injector Drill shape
# verbatim (its unit_printer.gd_ext.gd:25-35), super-first so it composes with the resident
# gavstarb-ssc_emperor extender (full_repair only) in any install order.
#
# THE DEPTHS (the ONE-LEVEL rule, memory lancer-tactics-extension-seams: an override is reached from
# an instance call through the autoload node, or from ONE unqualified static call below one, never
# deeper). event_unit_structure.execute_structure_check_result (:166-185) asks two ways:
#   level 0  LoadoutCore.get_destructable_gear(list)   (loadout_core.gd:575-576 ->
#            UnitPrinter.get_destructable_gear, qualified through the node)   - mount-less units, :177
#   level 1  LoadoutCore.get_destructable_mounts(mounts) (:573-574 -> UnitPrinter.get_destructable_mounts,
#            vanilla body, whose `get_destructable_gear(mount.get_gear())` at unit_printer.gd:306 is
#            UNQUALIFIED - one level down, the last depth the rule reaches)   - mechs with mounts, :176
# The Leoleth has mounts (Flex, Heavy), so level 1 is the production path. Both are measured here,
# plus the whole outcome end to end: a real structure event whose two cheated d6 land on
# DESTROY_WEAPON, on an AI-faction dummy so choose_to_destroy takes its no-prompt branch
# (event_unit_structure.gd:216-228) and the stock responder only has the brochure to answer.
#
# WHY BEHAVIOUR AND NOT A META (departure 1 from design 3.0). No production .gd_ext.gd in this mod
# carries a test hook, and the whitelist is a stronger discriminator: a stand-in Kit built at runtime
# with the PRODUCTION id (the real .tres does not exist yet - this file runs before any content) at
# zero charges is destroyed only if the override is reached; the same Kit under a control id is not.
#
# THE DICE. make_structure_check rolls structure_max - structure_current d6 (:80-83) - ONE at the
# first structure; 2-4 is SYSTEM TRAUMA and rolls a SECOND d6, 1-3 of which is DESTROY_WEAPON
# (:106-113). Queue [2, 1]. Under vanilla the weapon list is empty, the outcome cascades to
# DESTROY_SYSTEM (:127-136), and with no destructible system either it becomes a direct hit and STUNS
# (:141-153) - so the control asserts only "not destroyed" and leaves the cascade alone.
#
# MUTATION: change DESTRUCTIBLE_WHILE_EMPTY to a name nothing uses. Tests b, c, d must go RED; a
# (the control), e (mod_main) and f (the chain) stay green. If b is green and d is red, level 1 is
# NOT reached: override get_destructable_mounts in the extension too (super, then re-scan the mounts
# whose gear the whitelist admits) and re-measure.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-script=res://unpacked/Reag-TheSixthVoice/spec/test_spike_unit_printer_seam.gd
extends GutTest

const FrameIsolation := preload('res://testkit/frame_isolation.gd')

const OUR_MOD_MAIN := 'res://unpacked/Reag-TheSixthVoice/mod_main.gd'
const VANILLA_SCRIPT := 'res://engine/character/unit/service/unit_printer.gd'
const OUR_EXTENSION := 'res://unpacked/Reag-TheSixthVoice/res/engine/character/unit/service/unit_printer.gd_ext.gd'

## The production id the extension whitelists. The real Kit is Task 1's; this file builds a stand-in.
const AXE_ID := &'mw_thermal_death_axe'
## A Limited weapon id the extension does NOT whitelist.
const CONTROL_ID := &'reag_probe_limited_weapon'

const DUMMY_HP := 8
const DUMMY_STRUCTURE := 4
const HIT := 13
## [structure d6 = 2 -> SYSTEM TRAUMA, loss d6 = 1 -> DESTROY_WEAPON]
const DESTROY_WEAPON_DICE:Array[int] = [2, 1]

const DUMMY_TILE := Vector2i(4, 4)

var game:Gamemaster
var dummy:Unit
var axe:GearCore


func before_each() -> void:
	game = SpecFactory.setup_gamemaster(self)
	# AI faction: choose_to_destroy's player branch raises a choose_from_gear request the stock
	# responder does not answer; the AI branch sorts and picks (event_unit_structure.gd:216-228).
	dummy = SpecFactory.create_unit(game.map, DUMMY_TILE, Faction.AI_ENEMY)
	FrameIsolation.isolate_frame(dummy)
	dummy.core.frame.stat.health = DUMMY_HP
	dummy.core.frame.stat.armor = 0
	dummy.core.frame.stat.structure = DUMMY_STRUCTURE
	# One aux/aux mount, the vanilla test_event_gear_destroy.gd:36-37 idiom, so the MOUNT path
	# (level 1) is the one the structure check takes.
	dummy.core.frame.mount_types.append(ContentLibrary.get_mount(&'mount_aux_aux'))
	dummy.core.full_repair()
	assert_false(dummy.core.loadout.mounts.is_empty(), 'fixture: the dummy has a mount.')

func after_each() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()


# ---------------------------------------------------------------- helpers

## A LIMITED 1 aux melee weapon built at runtime under `id`, placed on the mount's primary slot and
## EMPTIED. Not through equip_primary: that reads ContentLibrary by id (mount_type.gd:44-46), and a
## runtime Kit is not there. GearCore.create (gear_core.gd:49-55) is what equip_primary calls anyway.
## No full_repair afterwards - it would refill the charge (gear_core.gd:156).
func mount_empty_weapon(id:StringName) -> GearCore:
	var swing := ActionAttackWeapon.new()
	swing.weapon_size = Lancer.WEAPON_SIZE.AUX
	swing.weapon_type = Lancer.WEAPON_TYPE.MELEE
	swing.damage_dice = '1'
	swing.aim_range = 0
	var kit := Kit.new()
	kit.compcon_id = id
	kit.charges_max = 1
	kit.actions.append(swing)
	var gear := GearCore.create(kit)
	gear.charges_current = 0
	dummy.core.loadout.mounts[0].slot_primary = gear
	assert_true(kit.is_destructable(), 'fixture: the stand-in is a destructible Kit shape.')
	assert_false(gear.has_charges_left(), 'fixture: it is empty.')
	return gear

## One real damage event past zero, which queues the structure event itself.
func structure_into_destroy_weapon() -> void:
	Dice.CHEAT_ROLL_QUEUE.clear()
	Dice.CHEAT_ROLL_QUEUE.assign(DESTROY_WEAPON_DICE)
	await game.execute_event(&'event_unit_damage', {
		unit = dummy, number = HIT, category = Lancer.DAMAGE_TYPE.KINETIC,
	})

## Every script in the live autoload's inheritance chain, most-derived first.
##
## BY SOURCE, NOT BY PATH - measured on the first RED run: ModLoader installs each extension with
## take_over_path, so the most-derived script in the chain answers to the VANILLA path and every
## script beneath it (the earlier extensions, and vanilla itself) reports resource_path "". With the
## resident ssc_emperor and Thy Hubris both extending this file the chain read
## ["res://engine/.../unit_printer.gd", "", ""] before ours was even installed. A script's
## source_code survives the rename, so membership is asserted on a line only that script carries.
func live_chain() -> Array[Script]:
	var chain:Array[Script] = []
	var script:Script = UnitPrinter.get_script()
	while script != null:
		chain.append(script)
		script = script.get_base_script()
	return chain

func chain_has_source(needle:String) -> bool:
	return live_chain().any(func(script:Script) -> bool: return script.source_code.contains(needle))


# ---------------------------------------------------------------- the probe

## a. CONTROL. A Limited weapon the extension does not name is refused at zero charges exactly as
## vanilla refuses it - the override widens nothing but the whitelist.
func test_a_control_an_unlisted_empty_weapon_is_not_destructible() -> void:
	var control := mount_empty_weapon(CONTROL_ID)
	assert_eq(UnitPrinter.get_destructable_gear([control]).size(), 0, 'level 0: refused.')
	assert_eq(LoadoutCore.get_destructable_mounts(dummy.core.loadout.mounts).size(), 0, 'level 1: refused.')
	await structure_into_destroy_weapon()
	assert_false(control.is_destroyed, 'The structure check found nothing to destroy on the mount.')
	assert_eq(dummy.core.current.structure, DUMMY_STRUCTURE - 1, 'It did structure.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'Both cheated dice were consumed.')

## b. LEVEL 0. The direct call through the node dispatches to the override.
func test_b_level_0_the_empty_axe_is_destructible_by_direct_call() -> void:
	axe = mount_empty_weapon(AXE_ID)
	assert_true(UnitPrinter.get_destructable_gear([axe]).has(axe),
		'THE SEAM: an empty axe is a destruction target - only the override can say so.')
	assert_true(LoadoutCore.get_destructable_gear([axe]).has(axe),
		'And through LoadoutCore, the structure check\'s mount-less entry (event_unit_structure.gd:177).')

## c. LEVEL 1. get_destructable_mounts (vanilla body) reaches the override one unqualified call down.
func test_c_level_1_the_mount_carrying_the_empty_axe_is_destructible() -> void:
	axe = mount_empty_weapon(AXE_ID)
	var mounts := LoadoutCore.get_destructable_mounts(dummy.core.loadout.mounts)
	assert_eq(mounts.size(), 1, 'THE PRODUCTION PATH (event_unit_structure.gd:176): the mount is offered.')

## d. END TO END. A real DESTROY_WEAPON outcome destroys the empty axe.
func test_d_a_structure_check_destroys_the_empty_axe() -> void:
	axe = mount_empty_weapon(AXE_ID)
	await structure_into_destroy_weapon()
	assert_eq(dummy.core.current.structure, DUMMY_STRUCTURE - 1, 'LIVENESS: it structured.')
	assert_true(axe.is_destroyed, 'The empty axe was chosen and destroyed - the whole chain is live.')
	assert_true(Dice.CHEAT_ROLL_QUEUE.is_empty(), 'Exactly two dice: the structure d6 and the loss d6.')

## e. THE RELOAD ENTRY IS OURS. Thy Hubris reloads the same UnitPrinter node with a chain that
## includes our script, so behaviour cannot tell whether OUR mod_main did its part (measured for
## UnitRelation 2026-09-19). Read the constant off our own file.
func test_e_this_mods_own_mod_main_reloads_unit_printer() -> void:
	var mod_main:Script = load(OUR_MOD_MAIN)
	assert_not_null(mod_main, 'fixture: our mod_main.gd loads.')
	var extended:Dictionary = mod_main.get_script_constant_map().get('EXTENDED_AUTOLOADS', {})
	assert_true(extended.has(&'UnitPrinter'),
		'EXTENDED_AUTOLOADS names UnitPrinter - without it the seam is dead for a player without Thy Hubris.')
	assert_eq(extended.get(&'UnitPrinter', ''), VANILLA_SCRIPT, 'And it points at the vanilla script.')

## f. THE LIVE CHAIN. Our extension is in the script the autoload node actually runs, and vanilla
## is its root. Identified by source (see live_chain): our banner line, and the vanilla copyright stamp.
func test_f_our_extension_is_in_the_live_autoloads_script_chain() -> void:
	var ours:Script = load(OUR_EXTENSION)
	assert_not_null(ours, 'fixture: our extension loads from its unpacked path.')
	if ours == null: return
	assert_true(chain_has_source('THERMAL DEATH AXE (Leoleth, mw_thermal_death_axe)'),
		'Our unit_printer.gd_ext.gd is in the live chain (%d scripts deep).' % live_chain().size())
	# THE YEAR IS DELIBERATELY NOT MATCHED (test_compat.gd's idiom): every modkit release re-stamps the
	# per-file copyright line, so baking 2026 in would turn this into a release-day red that says
	# nothing at all about the seam.
	var root_header:String = live_chain().back().source_code.get_slice('\n', 0)
	assert_true(root_header.begins_with('# Copyright (c) ') and root_header.contains('Lancer Tactics v'),
		'Vanilla is the root of the chain.')
	assert_true(live_chain().size() >= 2, 'At least vanilla plus ours.')
