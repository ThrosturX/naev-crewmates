# Repository Guidelines

## Project Structure & Module Organization

This repository is a Lua plugin for Naev. `events/companions.lua` is the event entry point, while `scripts/crewmates/runtime.lua` composes the gameplay domains under `scripts/crewmates/`. Keep dialogue and generated character data in `content/`, active abilities in `abilities/`, and away-mission logic in `missions/`. `ai/` contains escort AI, and `scripts/pilotname/` and `scripts/language/` provide supporting modules. Automated checks and the reusable QA save live in `tests/`; plugin metadata is defined by `plugin.xml` and `plugin.toml`.

## Build, Test, and Development Commands

- `make check`: run every required pre-commit check: Lua and shell syntax, XML validation, fixture validation, and standalone tests.
- `make syntax`: parse Lua with `luac` and validate shell syntax.
- `make manifest`: validate XML/XSL and the saved-game fixture.
- `make test`: run shell installer tests and Lua module/contract tests; repeats supported tests under LuaJIT when installed.
- `tests/install-qa-pilot.sh [NAEV_DATA_DIRECTORY]`: install or refresh the isolated `Crewmates QA` pilot for manual in-game testing.

The development dependencies are `lua`, `luac`, `xmllint`, and standard POSIX shell tools; LuaJIT is optional.

## Coding Style & Naming Conventions

Match the existing Lua style: three-space indentation, `snake_case` locals/functions, and lowercase module paths such as `crewmates.crew_lifecycle`. Keep Naev globals at module boundaries and declare cross-domain dependencies through `module_contract.capture`. New gameplay belongs in a focused module, not the runtime composition root. Persisted fields must be initialized and migrated in `scripts/crewmates/state.lua`; preserve existing save-field and callback names.

## Testing Guidelines

Place standalone Lua tests in `tests/<feature>.lua`, using deterministic stubs for Naev APIs and clear assertion messages. Add new tests to the `test` target in `Makefile`. Run `make check`, then manually verify hook, pilot, dialogue, and save/load changes with the QA pilot. The full smoke-test checklist is in `MAINTAINERS.md`.

## Commit & Pull Request Guidelines

History favors short, imperative summaries such as `update outdated escort ai` or concise scope descriptions such as `various fixes`. Keep each commit focused and explain migrations or compatibility changes in its body. Pull requests should summarize player-visible behavior, list validation performed, link relevant issues, and include screenshots or reproduction steps for UI/dialogue changes. Call out save-format effects and Naev-version assumptions explicitly.
