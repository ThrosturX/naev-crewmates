-- Public cross-plugin API. Consumers must depend on TXCrewmates and should
-- call ensure_commander before using the other commander capabilities.
local api = {}

-- Naev gives each event its own module environment, so a module-local provider
-- installed by the Crewmates event is invisible to consumers such as Nomad.
-- naev.cache() is the engine-provided runtime-only bridge between those event
-- environments. Nothing stored here is persisted into a pilot save.
local function cached_provider()
	return naev.cache().crewmates_api_provider
end

local function implementation()
	local installed = cached_provider()
	assert(installed, "Crewmates event is not ready")
	return installed
end

function api.install(value)
	assert(type(value) == "table", "Crewmates API provider must be a table")
	naev.cache().crewmates_api_provider = value
end

function api.is_ready()
	return cached_provider() ~= nil
end

function api.ensure_commander(client, options)
   return implementation().ensure_commander(client, options)
end

function api.get_commander(client)
   return implementation().get_commander(client)
end

function api.get_commander_shuttle(client)
   return implementation().get_commander_shuttle(client)
end

function api.launch_commander_shuttle(client)
   return implementation().launch_commander_shuttle(client)
end

function api.attach_mothership(client, mothership_pilot)
   return implementation().attach_mothership(client, mothership_pilot)
end

function api.release_mothership(client, mothership_pilot)
   return implementation().release_mothership(client, mothership_pilot)
end

function api.can_dismiss(crewmember, replacement)
   return implementation().can_dismiss(crewmember, replacement)
end

function api.replace_commander(client, candidate, reason)
   return implementation().replace_commander(client, candidate, reason)
end

return api
