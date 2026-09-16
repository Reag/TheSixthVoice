# Shared mechanics

Helpers used by more than one frame. Roadmap §4 is the registry; the rule there is that **a helper
is born with its first consumer**, in its own sub-folder, with its own specs — and its interface is
frozen the moment that sub-project ships, recorded in roadmap §4 and in memory
`sixth-voice-build-state`. A later frame that needs more extends the helper in its own sub-project,
with every earlier spec still green.

The shape is the Draugr's: a static-function script plus whatever `.tres` it needs, no autoload, no
`class_name`. Every consumer reaches it by `preload`.

**Why no `class_name`**: global class names are registered from `project.godot`'s class list, which
is built at startup — so a `class_name` declared in a script a mod loads at runtime is never
registered, and cannot be referenced by that name at all. (This is a different problem from Godot
#83542, which is why a `class_name` script in the *base game* cannot be reliably script-extended;
that one is why the engine has so many autoloads. Both end at the same advice, for different
reasons.)

Built, and the interface frozen when its sub-project shipped:

| Family | Born with | Interface | Consumers |
|---|---|---|---|
| Overshield | 4 Myconid, SP1 | `current` `has` `grant` `increase` `grit` | Sluagh, Hazard, Naga, Primrose, Black Mountain |

Planned:

| Family | Born with | Consumers |
|---|---|---|
| Teleport | 5 Maiden's Blush | Purple Thorn, Leoleth, Sluagh, Koremasa, Six Sky |
| Efficient (core-power refund) | 5 Maiden's Blush | Lovers Knot, Black Mountain |
| Difficult terrain | 6 Vauban | Leoleth, Shackleton |
| Lock-on consumed hook | 7 Naga | Black Mountain |
| Attack redirection | 3 Subutai | Sluagh, Rakshasa, Lovers Knot — shape set by that frame's spike |

Nothing with a vanilla precedent belongs here: limited weapons that attack without charges follow
the Injector Drill, and `mt_guardian` / `mt_fragile` / `mt_slow` / `mt_exposed_reactor` are vanilla
trait Kits to be referenced, not reimplemented.
