#!/bin/sh
set -eu

if [ "$#" -gt 1 ]; then
   echo "usage: $0 [NAEV_DATA_DIRECTORY]" >&2
   exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fixture="$script_dir/fixtures/pilots/crewmates-qa"
naev_data=${1:-"${XDG_DATA_HOME:-$HOME/.local/share}/naev"}
destination="$naev_data/saves/Crewmates QA"

mkdir -p "$naev_data/saves"
staging=$(mktemp -d "$naev_data/saves/.crewmates-qa.XXXXXX")
trap 'rm -rf "$staging"' EXIT HUP INT TERM
cp -R "$fixture"/. "$staging"

if [ -e "$destination" ] || [ -L "$destination" ]; then
   rm -rf "$destination"
   action=replaced
else
   action=installed
fi

mv "$staging" "$destination"
trap - EXIT HUP INT TERM
echo "$action Crewmates QA pilot at: $destination"
