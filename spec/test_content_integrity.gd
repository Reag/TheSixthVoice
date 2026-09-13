# Content integrity for The Sixth Voice.
#
# A standing spec, built in SP0 against an EMPTY mod and never rewritten: every later sub-project
# adds its ids to the tables below and this file guards them. It is about wiring rather than
# behaviour - is everything registered, under the right index, with localization and an icon to
# match. Behaviour specs belong beside each ability as it is built.
#
# The tables are deliberately empty right now. That is not the same as the file asserting nothing:
# the mod-is-loaded, manifest, localization and glossary tests all bite today, and they are the ones
# that fail silently in play rather than loudly in a run.
#
#   godot --resolution 800x600 --position 20,20 --path . res://testkit/run_mod_tests_scene.tscn -- --gut-dir=res://unpacked/Reag-TheSixthVoice/spec
extends GutTest

const ModContentAudit := preload('res://testkit/mod_content_audit.gd')
const ModResources := preload('res://testkit/mod_resources.gd')
const Compat := preload('res://testkit/modkit_compat.gd')

const MOD_ID := 'Reag-TheSixthVoice'

# ModUtil and ModLibrary are class_name scripts that exist only on the 1.4 line. This mod targets
# 1.4.x only, but naming them directly would make the whole file fail to PARSE on any other engine -
# and GUT skips an unparsable script instead of failing it, so the suite would go green and smaller.
# Reaching them by path costs nothing and keeps the failure mode loud.
const MOD_UTIL := 'res://engine/mod/mod_util.gd'
const MOD_LIBRARY := 'res://engine/mod/mod_library.gd'

## Every ContentLibrary index this mod will ever contribute to. Walked by the audit and the icon
## guard so a new index cannot be added without the guards noticing.
const OUR_INDEXES:Array[StringName] = [&'frames', &'kits', &'buffs', &'licenses']

func test_the_mod_is_actually_loaded():
	# Everything below passes vacuously if the mod did not install, so this is the gate.
	assert_true(Compat.is_mod_active(MOD_ID), '%s is loaded and active.' % MOD_ID)

func test_no_resource_is_filed_under_the_wrong_index():
	# ContentLibrary sorts by FILENAME PREFIX, not by script class and not by folder. A Buff named
	# bt_* lands in the kits index and get_buff can never find it - no warning, no log line.
	# See testkit/mod_content_audit.gd.
	var problems := ModContentAudit.find_misfiled_resources(MOD_ID)
	for problem:String in problems: gut.p('  %s' % problem)
	assert_eq(problems.size(), 0, 'Every resource landed in the right ContentLibrary index.')

func test_the_manifest_names_the_running_engine():
	# 1.4.1 changed ModUtil.is_likely_compatible_with_game_version from "older than the game is fine"
	# to !=, on major and minor, and on PATCH too for any mod declaring requires_restart - which this
	# one does. So EVERY modkit patch release silently un-declares this mod: the player gets a
	# version-mismatch warning in Mod Manage and on mod.io, with nothing in a normal test run to say
	# so. The check is an any() over the array, so the fix is always to APPEND the new version to
	# compatible_game_version, never to replace what is there.
	var mod_util = load(MOD_UTIL)
	var library = load(MOD_LIBRARY)
	var manifest = library.get_manifest(StringName(MOD_ID))
	assert_not_null(manifest, '%s has a manifest.' % MOD_ID)
	if manifest == null: return
	assert_true(
		mod_util.is_mod_likely_compatible_with_game_version(manifest),
		'manifest.json compatible_game_version names %s.' % Compat.version_label()
	)

func test_the_mod_name_is_localized():
	# A key with an empty value in the CSV is not registered at all, so tr() hands back the raw key
	# and THAT is what renders in game. This also proves localizations.en.translation was actually
	# regenerated after the last CSV edit: the compiled artifact is what Translate loads, and a stale
	# one hands back raw keys while the CSV beside it looks perfect.
	assert_ne(tr('mod.reag_thesixthvoice.name'), 'mod.reag_thesixthvoice.name',
		'The mod name resolves to real text.')

# ---------------------------------------------------------------- the glossary
#
# The supplement's Efficient tag (Maiden's Blush, Lovers Knot, Black Mountain) is not in the base
# game's glossary json, so |Efficient| in rule text renders as coloured text with no hover unless
# mod_main.register_glossary_terms appends the key and the CSV carries both rows. It ships in the
# skeleton, ahead of its first consumer, so the seam is proven on this engine before a frame leans
# on it (author's call, 2026-09-13).
#
# WHY THESE THREE TESTS AND NOT ONE. The obvious check - ask GlossaryItem whether the term resolves -
# CANNOT FAIL IN A TESTKIT RUN, because Thy Hubris is loaded alongside us and registers
# `lancer.term.efficient` itself, with its own CSV rows. Verified 2026-09-13 by emptying this mod's
# GLOSSARY_TERMS and re-running: the global lookup stayed green. Both the glossary cache and tr() are
# GLOBAL, so neither can say which mod supplied the term - and a player with only this mod installed
# would get a dead label. So the two tests that have to discriminate read THIS MOD'S OWN files, and
# the end-to-end one is kept for what it is worth with that limitation written down.

const OUR_MOD_MAIN := 'res://unpacked/Reag-TheSixthVoice/mod_main.gd'
const OUR_TRANSLATION := 'res://unpacked/Reag-TheSixthVoice/localization/localizations.en.translation'

func test_this_mod_registers_the_efficient_term_itself():
	# Reads our own mod_main rather than the shared glossary cache, so another mod registering the
	# same term cannot cover for us.
	var script:Script = load(OUR_MOD_MAIN)
	assert_not_null(script, 'mod_main.gd loads.')
	if script == null: return
	var terms:Array = script.get_script_constant_map().get('GLOSSARY_TERMS', [])
	assert_has(terms, &'lancer.term.efficient', 'This mod declares the term in GLOSSARY_TERMS.')

func test_this_mods_own_translation_carries_both_glossary_rows():
	# Loads THIS MOD'S compiled artifact directly, for two reasons. It is the only way to attribute a
	# row to us rather than to Thy Hubris. And it is the check for the staleness trap: Translate loads
	# `localizations.en.translation`, NOT the csv beside it, and `filesystem_manage(op="reimport")`
	# refreshes the filesystem entry WITHOUT regenerating the artifact - only op="scan" does. So a
	# correct CSV can sit next to an artifact that has never heard of these keys.
	#
	# The artifact is an OptimizedTranslation, which hashes its keys, so grep cannot answer this and a
	# zero hit is not evidence of anything. get_message can.
	var translation:Translation = load(OUR_TRANSLATION)
	assert_not_null(translation, 'This mod has a compiled translation.')
	if translation == null: return
	for key:String in ['lancer.term.efficient', 'lancer.term.efficient.desc']:
		assert_ne(translation.get_message(key), StringName(''),
			'Our own artifact carries %s.' % key)

func test_the_efficient_term_resolves_end_to_end():
	# The real behaviour, with the caveat above: green here does NOT prove this mod supplied the term
	# while Thy Hubris is loaded. It is still worth running - it is the only test that exercises the
	# priming call in register_glossary_terms and the ".desc must exist" rule inside
	# find_key_from_label, and it would catch an engine change that broke the mechanism for everybody.
	# Matching is case-insensitive, so |efficient| in a rule row resolves to the same entry.
	assert_eq(GlossaryItem.find_key_from_label('Efficient'), 'lancer.term.efficient',
		'|Efficient| links to its own glossary entry.')
	assert_eq(GlossaryItem.find_key_from_label('efficient'), 'lancer.term.efficient', 'Either case.')

## Every kit and player-facing buff this mod ships, and the actions on each kit that need their own
## icon. Filled in by each sub-project as it builds content; the icon pass is what makes it green.
##
## Shape: kit id => the action ids on that kit that are player-facing. A kit whose only action is
## the kit itself wears the kit's icon, so it lists none.
const ICON_TARGETS := {}
## Player-facing buffs. A buff with hide_from_player needs no icon and does not belong here.
const VISIBLE_BUFFS:Array[StringName] = []

func test_every_player_facing_kit_and_action_has_a_real_icon():
	# A kit or action without icon_override falls back to the generic glyph, which reads as "this
	# gear is unfinished" in the gear bar. The placeholder check is the other half: an icon pass that
	# wired the stand-in everywhere would otherwise sail through.
	#
	# The subject is the mod's OWN contributions, not ICON_TARGETS, so a kit added without a table
	# row cannot slip past unchecked - that is what the size assertion pins, and it is also what
	# makes this test assert something while the mod is still empty. It reads through
	# testkit/mod_resources.gd rather than ContentLibrary.get_all, which loads every installed mod
	# and fails on a stranger's parse error.
	var kits:Array[Resource] = ModResources.load_ours(MOD_ID, &'kits')
	assert_eq(ICON_TARGETS.size(), kits.size(), 'ICON_TARGETS lists every kit this mod ships.')
	for kit:Kit in kits:
		assert_true(Kit.is_valid(kit), '%s is registered.' % kit.resource_path.get_file())
		if not Kit.is_valid(kit): continue
		_assert_real_icon(kit.icon_override, kit.compcon_id)
		var listed:Array = ICON_TARGETS.get(kit.compcon_id, [])
		var by_id := {}
		for action:Action in kit.actions: by_id[action.get_id()] = action
		for action_id:StringName in listed:
			assert_true(by_id.has(action_id), '%s carries %s.' % [kit.compcon_id, action_id])
			if not by_id.has(action_id): continue
			_assert_real_icon(by_id[action_id].icon_override, '%s.%s' % [kit.compcon_id, action_id])

func test_every_visible_buff_has_a_real_icon():
	# Same shape: driven by what the mod contributed, so VISIBLE_BUFFS cannot fall behind. A buff
	# with hide_from_player needs no icon and is not counted.
	var visible:Array[Buff] = []
	for buff:Buff in ModResources.load_ours(MOD_ID, &'buffs'):
		if not buff.hide_from_player: visible.append(buff)
	assert_eq(VISIBLE_BUFFS.size(), visible.size(), 'VISIBLE_BUFFS lists every player-facing buff.')
	for buff:Buff in visible:
		assert_true(VISIBLE_BUFFS.has(buff.compcon_id),
			'%s is listed in VISIBLE_BUFFS.' % buff.resource_path.get_file())
		_assert_real_icon(buff.icon, buff.compcon_id)

func test_the_mod_reports_what_it_contributed():
	# Not an assertion about content - a report, so a run that goes quietly green because nothing
	# loaded is visible in the log rather than mistaken for a pass. Grows into a real count check as
	# soon as SP1 lands the frame.
	for index_name:StringName in OUR_INDEXES:
		gut.p('  %-10s %d' % [index_name, ModResources.our_paths_in(MOD_ID, index_name).size()])
	assert_true(Compat.is_mod_active(MOD_ID), 'Reported against a mod that is actually installed.')

## An icon has to exist AND not be a stand-in. Shared by the kit, action and buff guards.
func _assert_real_icon(icon:Texture2D, label:String) -> void:
	assert_not_null(icon, '%s has an icon.' % label)
	if icon == null: return
	assert_false(icon.resource_path.contains('placeholder'),
		'%s does not wear the placeholder icon.' % label)
