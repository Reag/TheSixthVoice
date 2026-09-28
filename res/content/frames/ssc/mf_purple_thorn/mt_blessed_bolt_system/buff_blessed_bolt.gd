# BLESSED BOLT's +3 (ruling 4): a one-time BuffDamage to plain Buff.TO.BONUS_DAMAGE, hung on the Thorn
# by action_blessed_bolt at ATTACK POST and read by the declared attack's general bonus-damage roll a
# moment later (event_unit_attack_declared.gd:95) - after it has awaited every per-target attack
# (:69), so after every POST reaction. Measured by spec/test_spike_specific_bonus_at_post.gd's
# general-channel probe (close-out Pass F Task 13).
#
# HALVED ACROSS A MULTI-TARGET ATTACK (rulings.md Pass E, reversing ledger J-1): the engine halves
# general bonus damage when more than one character is attacked (declared_attack_summary.gd:44-45,
# attack_util.gd:309-312) and adds it to every victim's damage, as Lancer does. It was
# bonus_damage_specific until Pass F, gated on the one roll that was offered: the full +3 on one Blast
# victim, nothing on the others. A single-target attack deals exactly what it did.
#
# The rest is BuffDamage's own: damage_dice "3" (flat, rolls nothing), inherit_type_from_attack
# ("+3 bonus damage" is of the weapon's type - the Nexus's kinetic, a thermal pistol's energy),
# onetime (consumed by the general read's consume_buffs, :124), until FINISH_DAMAGE (cleared after the
# attack's damage either way, so nothing leaks to the next attack), hidden. NO require_hit: it hides a
# buff from the general read, which carries no AttackRoll (buff_damage.gd:20). The reaction is the hit
# gate - the buff only exists once an Aux hit has been offered and accepted.
extends BuffDamage
