# BINDING FANGS' ONE PROFILE (Naga SP3 Task 1, design ruling 14).
#
#   "You may attack with this weapon without expending or requiring charges"
#
# The Thermal Death Axe's standard profile verbatim (action_tda_standard.gd, whose header has the
# whole argument): Action.consumes_charges (action.gd:108) is read at exactly two places,
# unit_action.gd:153 (availability - "without requiring") and :274 (the spend - "without expending"),
# so one override covers the sentence. The charges exist only for the on-hit lock, which spends one
# BY HAND (onhit_binding_fangs.gd), and "can be destroyed even if it has no charges remaining" is the
# whitelist in res/engine/character/unit/service/unit_printer.gd_ext.gd.
extends ActionAttackWeapon

func consumes_charges(_specific:SpecificAction) -> bool: return false
