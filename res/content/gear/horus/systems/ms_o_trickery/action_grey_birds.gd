# THE FLIGHT OF THE CRESCENT OF GREY BIRDS, O' Trickery's first invade (SP2 Task 5).
#
#   "Until the end of the next round, if your target takes an action that could target you, they
#    must target you with that action."
#
# THE WHOLE ABILITY IS THE THREE BUFFS IT HANGS. buff_grey_birds_ban is the targeting channel,
# buff_grey_birds_recentre (SP2 Task 6) is the AoE half that channel never sees, and buff_grey_birds
# is what the player reads. All three share buff_grey_birds_lifetime.gd and expire themselves.
#
# on_hit IS THE SLOT, NOT on_hit_effects, and the difference is the hostility test: the declarative
# array applies its buffs to whoever was hit, and an ALLIED invade auto-hits
# (action_attack_tech.gd:71-73). Vanilla's Puppet System uses the same scripted slot for the same
# kind of reason (action_puppet_system.gd:16).
#
# APPLIED THROUGH UnitCondition.apply_buffs, THE PLURAL FORM, on purpose: it batches the cache update
# instead of running one per buff ("Use this if applying multiple buffs from one effect",
# unit_condition.gd:702). Passing context.gear is what sets each BuffCore's from_gear, which is the
# only way get_owner_unit can resolve the Sluagh later (buff_core.gd:102-105) - and the ban is
# nothing without that.
extends ActionAttackTech

const BUFF_IDS:Array[StringName] = [
	&'buff_grey_birds_ban',
	&'buff_grey_birds_recentre',
	&'buff_grey_birds',
]

func on_hit(activation:EventCore, attacked_unit:Unit) -> void:
	if not Unit.is_valid(attacked_unit): return
	var context:Context = activation.context
	if not Unit.is_valid(context.unit): return
	# RULING 4 IS ABOUT A TARGET, AND AN ALLY IS NOT ONE. An allied invade auto-hits, so without this
	# clause pressing Grey Birds on a friend would bind them to the Sluagh - the opposite of the card.
	if not UnitRelation.are_enemies(context.unit, attacked_unit): return

	var buffs:Array[Buff] = []
	for buff_id:StringName in BUFF_IDS:
		var buff:Buff = ContentLibrary.get_buff(buff_id)
		# A missing buff is a content error, not a runtime one - but silently applying two of three
		# would leave the card half-working with nothing red, so say so.
		if buff == null:
			X.error('action_grey_birds: %s did not load; the invade applied an incomplete set.' % buff_id)
			continue
		buffs.append(buff)
	UnitCondition.apply_buffs(activation, attacked_unit, buffs, context.gear)
