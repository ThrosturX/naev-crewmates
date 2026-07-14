# Crewmates Public API

Plugins that declare `TXCrewmates` as a dependency can use:

```lua
local crewmates = require "crewmates.api"
assert(crewmates.is_ready(), "Crewmates event has not loaded yet")
local commander = assert(crewmates.ensure_commander("nomad", {
   minimum = 1,
   shuttle = "Alpaca",
   shuttle_profile = {
      client = "nomad",
      landable = true,
      trade_replacement = true,
      owned_handoff = true,
      owned_escorts = true,
   },
}))
local shuttle_ship = assert(crewmates.get_commander_shuttle("nomad"))
local launched, reason = crewmates.launch_commander_shuttle("nomad")
assert(launched, reason)
```

`ensure_commander` registers a runtime requirement, creates a First Officer if
none is available, and guarantees that the selected commander owns the named
shuttle. The default and currently supported contract is exactly one commander
with an Alpaca. Requirements are runtime-only and must be registered whenever
the consuming event loads.

When `shuttle_profile` is present, Crewmates passes it to Joyride when that
commander launches the shuttle. Omitting it retains the standard non-landable
`TXCrewmates` profile.

Use `launch_commander_shuttle(client)` when the registered commander should
immediately pilot that shuttle. This delegates to Crewmates' normal launch and
return lifecycle: the commander's saved outfit list is applied to the shuttle
template, and Joyride's returned outfit list is persisted back to the same
commander record. Consumers should not construct their own shuttle template.

Use `get_commander(client)` to access the live Crewmates record. During an
external Joyride, call `attach_mothership(client, pilot)` after the mothership
spawns and `release_mothership(client, pilot)` when it returns. This connects
the normal commander hail interface without exposing Crewmates event memory.

Crewmates dismissal paths consult `can_dismiss(crewmember, replacement)`. The
last eligible required commander cannot be fired or expelled. Hiring flows add
an eligible replacement before removing the incumbent. Integrations that own a
Crewmates candidate can perform the same operation with:

```lua
local commander, reason = crewmates.replace_commander(
   "nomad", candidate, "Changed mothership commander."
)
```

The candidate must already be a valid Crewmates commander record. The public
method guarantees the required shuttle and rolls back a rejected candidate.
