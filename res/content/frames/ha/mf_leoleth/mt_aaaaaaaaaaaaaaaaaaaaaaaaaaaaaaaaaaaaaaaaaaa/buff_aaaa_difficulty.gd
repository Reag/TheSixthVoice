# The 43-A trait's whole mechanism (ruling 4): +2 difficulty on every RANGED attack the Leoleth makes.
#
# NO BEHAVIOUR OF ITS OWN. Every field this buff needs is a BuffWeaponTypeBonus export, and the
# .tres sets them. The subclass exists so the resource has a local path to point at and so this
# reasoning lives next to the file a reader will open.
#
# "RANGED" IS THE ENGINE'S OWN PREDICATE. ActionAttackWeapon.is_difficulty_when_engaged is literally
# `weapon_type != Lancer.WEAPON_TYPE.MELEE` (action_attack_weapon.gd:254-255), and it is what drives
# the engaged penalty at attack_roll.gd:173. So weapon_types_forbidden = [MELEE] with NO positive
# weapon_types filter is exactly the card's "ranged": CQB, Cannon, Rifle, Launcher and Nexus all get
# it, melee does not.
#
# TECH ATTACKS ARE OUT WITH NO CLAUSE AT ALL. BuffWeaponType.check_if_passive_applies returns false
# on its first line for anything that is not an ActionAttackWeapon (buff_weapon_type.gd:35).
#
# allow_basic IS SET AND HAS NOTHING TO CATCH TODAY. The card says "all ranged attacks" with no
# qualifier, and buff_weapon_type.gd:52 is what decides whether basic gear is included - but every
# basic weapon in content/gear/basic/basic_loadout_mech_player.tres is MELEE (mw_ram, mw_grapple and
# mw_improvised_attack all set weapon_type = 2), so no vanilla basic is a ranged attack. The flag is
# the card's, not a measured behaviour; spec/test_aaaa_difficulty.gd asserts it declaratively and
# says why.
#
# THE CHIP IS HIDDEN. The trait card is the explanation a player needs; a permanent chip on the token
# would be noise. It IS still drawn in the roll breakdown, though - attack_roll.gd:189 passes
# buff_core.base.icon RAW rather than through Buff.get_icon(), so BuffBonus's difficulty-svg fallback
# never runs there and a null icon leaves a blank beside the -2. That is why it is listed in
# test_content_integrity.HIDDEN_BUFFS_NEEDING_ICONS, and why that guard is red until SP5.
extends BuffWeaponTypeBonus
