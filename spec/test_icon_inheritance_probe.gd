extends GutTest

## TEMPORARY - deleted in Task 2 of the icon-glyph-families plan, once the integrity guard covers
## the same ground on every Kit.
##
## The whole glyph-family design rests on one engine claim: an Action with no icon_override
## resolves to its Kit's texture (action.gd:324-326 -> get_icon_from_kit -> kit.gd:209). A comment
## at test_content_integrity.gd:288 asserts the OPPOSITE - that it falls back to a generic. This
## settles which is true before anything is built on it.

const MOD_ID := 'Reag-TheSixthVoice'

func test_an_action_with_no_icon_override_wears_its_kits_glyph():
	var kit:Kit = ContentLibrary.get_kit(&'mt_sap')
	assert_true(Kit.is_valid(kit), 'mt_sap is registered.')
	if not Kit.is_valid(kit): return
	assert_not_null(kit.icon_override, 'mt_sap carries an icon_override to inherit FROM.')
	assert_false(kit.actions.is_empty(), 'mt_sap carries an action.')
	if kit.actions.is_empty(): return
	var action:Action = kit.actions[0]
	assert_null(action.icon_override, 'action_sap carries no icon_override of its own.')
	assert_eq(action.get_icon(kit), kit.icon_override,
		'Action.get_icon(kit) resolves to the Kit texture, NOT a generic.')
	assert_ne(action.get_icon(kit), Action.DEFAULT_ICON,
		'and specifically not to Action.DEFAULT_ICON.')

func test_the_kit_card_also_shows_that_texture():
	var kit:Kit = ContentLibrary.get_kit(&'mt_sap')
	if not Kit.is_valid(kit): return
	assert_eq(kit.icon_and_flavor().icon, kit.icon_override,
		'kit.gd:209 overrides actions[0].get_icon() with the Kit own override.')

func test_the_action_resource_is_shared_and_the_inherited_icon_is_cached_on_it():
	# Why a KIT row is banned for a multi-Kit action: action.gd:58 caches icon_from_kit on the
	# Action INSTANCE, and ContentLibrary hands out one instance per .tres, so two Kits carrying
	# the same Action would both show whichever asked first.
	#
	# Uses mt_halo, not mt_sap: the test above calls get_icon on mt_sap's Action, which warms the
	# very cache this test exists to demonstrate. Rather than depend on which of them GUT happens
	# to run first, this test takes a Kit that NO other test in this file touches, so its Action's
	# icon_from_kit is still at its declared default (action.gd:58, = null) whatever the order.
	# The assertion on the BEFORE state below is what turns that into evidence: it demonstrates
	# the null -> non-null transition rather than asserting an end state that something else
	# could have produced.
	var kit:Kit = ContentLibrary.get_kit(&'mt_halo')
	assert_true(Kit.is_valid(kit), 'mt_halo is registered.')
	if not Kit.is_valid(kit): return
	assert_not_null(kit.icon_override, 'mt_halo carries an icon_override to inherit FROM.')
	assert_false(kit.actions.is_empty(), 'mt_halo carries an action.')
	if kit.actions.is_empty(): return
	var a:Action = kit.actions[0]
	var b:Action = ContentLibrary.get_kit(&'mt_halo').actions[0]
	# Objects compare by reference, so assert_eq here IS an identity check.
	assert_eq(a, b, 'ContentLibrary returns one shared Action instance, not a copy.')
	assert_null(a.icon_from_kit,
		"nothing has resolved this Action's icon yet, so the cache starts empty.")
	a.get_icon(kit)
	assert_not_null(a.icon_from_kit,
		'the resolution is now cached on the shared Action, where a second Kit would inherit it.')
