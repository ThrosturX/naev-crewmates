# Maintainer Guide

## Runtime boundaries

`events/companions.lua` is the Naev event adapter. It declares the event and
loads `scripts/crewmates/runtime.lua`, the composition root for the domain
modules and Naev callbacks. New gameplay logic should live in dedicated
modules under `scripts/crewmates/` rather than growing the runtime module.

Domain files end with a `module_contract.capture` declaration listing their
exports and required domains. The contract loader removes implementation
symbols from `_G` and binds functions to restricted environments where only
Naev globals, their own exports, and declared dependencies are visible.
`callbacks.lua` is the sole allowlist for functions Naev must resolve globally
from hook strings. Adding a new string callback requires exporting it from its
domain and adding it to that allowlist.

Current domain modules include `roster.lua` for crew lookup and bay capacity,
`crew_lifecycle.lua` for removal and death cleanup, `hooks.lua` for lifecycle
hook registration, and `interface.lua` for commander UI registration.

Persistent data belongs under `mem`. Use `scripts/crewmates/state.lua` when
adding or changing persisted fields. Runtime hook IDs, NPC caches, and pilots
must not be stored as persistent crew data.

## Where to make changes

- `content/`: dialogue ingredients and generated character content.
- `crew_factory*.lua`: crew construction, officer specializations, and bar NPCs.
- `conversation_runtime.lua` and `memory.lua`: live conversations and memories.
- `simulation.lua`: landing, takeoff, roster accounting, pay, and fatigue.
- `management*.lua`: commands, assessments, and management dialogue/UI.
- `missions/away.lua`, `shuttle.lua`, and `abilities/`: active crew gameplay.
- `context.lua`: compatibility globals shared by the split modules. Avoid adding
  new gameplay here; prefer a focused module with explicit inputs.
- `config.lua`, `state.lua`, `util.lua`, and the small service modules: the best
  places for isolated logic that can be covered by `tests/modules.lua`.

## Safe refactoring rules

1. Preserve existing crew field names and hook callback names.
2. Add migrations before changing the shape of saved data.
3. Keep content tables separate from code that applies effects.
4. Keep Naev globals at module boundaries; pass ordinary data to helpers.
5. Declare every cross-domain dependency in the file's module contract.
6. Run `make check` before testing in-game.

## Validation

Run `make check` for Lua syntax validation and the standalone module tests.
The plugin has no standalone Naev integration runner, so changes involving
hooks, pilots, dialogue, or save/load must also be checked in game:

1. Load an existing save that already has hired crew.
2. Land, verify crew NPCs appear, and speak to a regular crewmate.
3. Take off and use **Discuss Command** with a first officer.
4. Jump and land again; confirm crew, salaries, and memories persisted.
5. Assign and complete one shuttle mission if the save has a shuttle-capable
   officer or pilot.

### Reusable QA pilot

`tests/fixtures/pilots/crewmates-qa/autosave.ns` is a sanitized, landed pilot
in a Za'lek Hephaestus with four fighter bays, an independent auxiliary ship
bay, and 50 million credits. Install
it into the normal Naev data directory with:

```sh
tests/install-qa-pilot.sh
```

For an isolated profile, pass the directory that contains that profile's
`saves/` directory:

```sh
tests/install-qa-pilot.sh /tmp/naev-crewmates-probe/share/naev
```

The installer only replaces `saves/Crewmates QA`; all other pilots are left
untouched. On first load, `_crewmates_qa_fixture=1` asks `qa_fixture.lua` to build
the roster through the real crew factories, then the marker is removed. Save
once after loading if you want the expanded roster serialized immediately.

The 27-person roster intentionally includes combinations normal hiring rules
do not allow: a first officer, pirate commander, escort companion, and smuggler
share the same ship. It also includes a shuttle pilot, every engineer variant,
psychology/morale/science/personnel managers, cargo and maintenance support,
security and pirate crew, cleaners, every ordinary rank, and a passenger.
Satisfaction and XP span negative, neutral, experienced, and near-promotion
states. The interior begins dirty, making cleaning and management feedback easy
to exercise.

The fixture was derived from a brand-new pilot and transformed into a
post-Chapter 1 state so the introduction cinematic and AI conversation do not
run. To refresh its base
for a new save format, run `tests/fixtures/qa-save-transform.xsl` with
`xsltproc` against another newly-created, landed pilot, review the output for
source-pilot data, and run `make check`.
