# ZWARTE HOOP's "+1 KNOCKBACK on the attack", once or twice (design ruling 13). Read in
# ActionAttackWeapon.on_hit (action_attack_weapon.gd:322-345), once per hit target. UNGATED
# (boolean false): a weapon with no printed Knockback still takes it. The count is BuffCore.state 'n'.
extends Buff

func get_values(core:BuffCore, _context:Context) -> Context:
	return Context.create({
		number = core.get_state('n', 0) if core != null else 0,
		boolean = false,
	})
