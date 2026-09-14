# Localization conventions

`localizations.csv` is `id,en`, one row per key, blocks separated by a bare `,` row. Conventions are
Thy Hubris', so the two mods read the same in play.

## The compiled artifact is what the game reads, not the CSV

The CSV is an *imported* asset (`importer="csv_translation"`) that generates
`localizations.en.translation` beside it, and `Translate.add_translation_from_file` globs the
directory for `*.translation` and loads those — the csv path it is handed only locates the folder.

So **a spec asserting on `tr()` reads the compiled artifact, and will happily pass against text you
just deleted.** After every CSV edit, run `filesystem_manage(op="scan")` in the running editor and
confirm the artifact's mtime and size actually moved. `op="reimport"` does **not** do this: it
reports success and refreshes the filesystem entry without running the import.

The artifact is an `OptimizedTranslation`, so multi-word strings are invisible to `grep` — a zero
hit is not evidence of anything. Use mtime and size, or a spec.

## Key shapes

| Key | What it names |
|---|---|
| `mod.reag_thesixthvoice.name` | **nothing the player sees.** Kept as a test canary — see below |
| `frame.<mf_id>.name` / `.flavor` / `.flavor.short` | a frame |
| `gear.<kit_id>.name` / `.effect` / `.trigger` / `.flavor` | a kit: trait, core power, system, weapon, weapon mod |
| `gear.<kit_id>.<action_id>.name` / `.effect` | one action on a multi-action kit |
| `gear.<buff_id>.name` / `.effect` | a player-facing buff |
| `lancer.term.<term>` + `lancer.term.<term>.desc` | a glossary term |

## Flavour comes from the LCP. Do not write your own.

Established 2026-09-14, after the Fitzgerald shipped with invented flavour while Bel's own text sat
unused in the source book. The rules sheets in `specs/sixth-voice/` now print every flavour string
verbatim, labelled with the key it belongs in, so there is nothing to go looking for.

| LCP field | Key |
|---|---|
| `frame["description"]` | `frame.<mf_id>.flavor` |
| `frame["core_system"]["description"]` | `gear.<cp_id>.flavor` |
| weapon / system / mod `["description"]` | `gear.<kit_id>.flavor` |

**A frame TRAIT is the exception.** It has no `effect` field, so its `description` is the RULES text
and goes in `gear.<trait_id>.effect`.

`gear.<id>.flavor` is currently near-dead - its only live reader is the text-to-speech voice preview
in audio settings (`setting_volume.gd:118-126`), which falls back to `effect` then `name`. Write it
regardless: it costs nothing, it is the author's own prose, and nothing has to be revisited if the
engine starts rendering it. **Never fold flavour into the `.effect` row** - vanilla keeps rules and
prose in separate keys, and mixing them makes the rules text impossible to check against the source.

The id is the resource's **filename without extension**, which is also what decides its
ContentLibrary index — so a renamed `.tres` is a renamed localization key.

## Wiki markup

`|term|` renders as a glossary link when the term resolves. `|Label=gear.<kit>.<action>|` links
arbitrary text to a **kit** — use it whenever rule text names another ability of the same frame, so
the player can read it without leaving the tooltip.

Note the link target is the kit, not the action: `GlossaryItem.process_glossed_text` takes
`split_key[1]` as the kit id and emits `[url={"kit":"<kit>"}]`, discarding the `.<action>` segment
(`engine/utils/glossary_item.gd:240-250`). Keep writing the full `gear.<kit>.<action>` form — it is
what vanilla and Thy Hubris do, and it is the right key if the engine ever resolves deeper — but do
not expect the tooltip to scroll to a particular action.

## The `mod.*` row is dead

Nothing in the engine reads a `mod.*` key. Mod Manage shows `ModCore.tr_label()`
(`engine/mod/mod_core.gd:80-84`), which returns `manifest.title`, then `manifest.name`, then the
mod id — no translation lookup anywhere. **To change what Mod Manage displays, edit `title` in
`manifest.json`.**

The row stays because `spec/test_content_integrity.gd` uses it as a canary: it is the only key only
this mod supplies, so `tr()` resolving it is the proof that `add_translations` registered our
artifact with the TranslationServer. Loading the `.translation` file directly, as the glossary test
does, proves the file is right but not that anything can see it.

## Glossary terms

A term needs **both** rows: `lancer.term.<term>` and `lancer.term.<term>.desc`.
`GlossaryItem.find_key_from_label` refuses any key whose `.desc` row is missing, so a term with only
a name silently renders as plain text.

It also needs registering in `mod_main.gd`'s `GLOSSARY_TERMS` — the base game's glossary json has no
entry for any of these, and `cached_term_keys` is what the lookup consults.

`Efficient` is registered and defined here because the supplement uses it (Maiden's Blush, Lovers
Knot, Black Mountain). The Fitzgerald does not, but the term ships in the skeleton so the glossary
seam is proven on 1.4.3 before a frame depends on it — the author's call, 2026-09-13.
