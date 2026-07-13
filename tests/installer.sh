#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
profile=$(mktemp -d)
trap 'rm -rf "$profile"' EXIT HUP INT TERM

"$root/tests/install-qa-pilot.sh" "$profile" >/dev/null
destination="$profile/saves/Crewmates QA"
fixture="$root/tests/fixtures/pilots/crewmates-qa"

cmp "$fixture/autosave.ns" "$destination/autosave.ns"
echo stale >"$destination/stale-file"
echo damaged >"$destination/autosave.ns"

output=$("$root/tests/install-qa-pilot.sh" "$profile")
test "$output" = "replaced Crewmates QA pilot at: $destination"
test ! -e "$destination/stale-file"
cmp "$fixture/autosave.ns" "$destination/autosave.ns"

echo 'ok - QA pilot installer replacement'
