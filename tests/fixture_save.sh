#!/bin/sh
set -eu

fixture=tests/fixtures/pilots/crewmates-qa/autosave.ns
xmllint --noout "$fixture"

require_text() {
   if ! rg -q "$1" "$fixture"; then
      echo "QA pilot fixture is missing: $2" >&2
      exit 1
   fi
}

require_text 'player name="Crewmates QA"' 'sanitized pilot name'
require_text "model=\"Za'lek Hephaestus\"" 'six-bay carrier hull'
require_text '<plugin id="joyride">Auxiliary Ship Bay</plugin>' 'Joyride plugin identity'
require_text '<plugin id="TXCrewmates">Crewmate companions</plugin>' 'Crewmates plugin identity'
require_text '_crewmates_qa_fixture' 'one-shot roster marker'
require_text 'Empire Lancelot Bay' 'fighter bays'
require_text 'Sirius Fidelity Bay' 'secondary fighter bays'
require_text '<outfit slot="6">Auxiliary Ship Bay</outfit>' 'independent auxiliary bay'
require_text '<chapter>1</chapter>' 'post-introduction chapter'
require_text '<fleet_capacity>100</fleet_capacity>' 'post-Chapter 1 fleet capacity'
require_text '<diff>hypergates_3</diff>' 'post-Chapter 1 universe diff'
require_text '<done>Chapter 1</done>' 'completed Chapter 1 event'
require_text 'name="shipai_name"' 'ship AI identity'
require_text 'name="tut_disable"' 'disabled tutorial prompts'

if [ "$(rg -c 'Empire Lancelot Bay|Sirius Fidelity Bay' "$fixture")" -ne 4 ]; then
   echo 'QA pilot fixture must contain exactly four fighter bays' >&2
   exit 1
fi

if rg -q "Fresh McPilot|Homer|multiplayer|TXVariants|evoFactions|shiplover_lastplayed|Chapter 0|Evolution Sandbox|Multiplayer Arena|Multiplayer Lobby|Pyro's Pink Slip Storage|Somal's Ship Cemetery" "$fixture"; then
   echo 'QA pilot fixture contains source-pilot or unrelated-plugin state' >&2
   exit 1
fi

echo 'ok - QA pilot save fixture'
