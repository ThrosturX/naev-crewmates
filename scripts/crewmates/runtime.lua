-- Composition root for the persistent crewmates event. Domain modules declare
-- contracts, the contract loader wires their dependencies without leaking
-- implementation symbols, and the callback adapter exposes only names that
-- Naev must resolve from hook strings.

local contract = require "crewmates.module_contract"
local callbacks = require "crewmates.callbacks"

local specifications = {
   require "crewmates.context",
   require "crewmates.content.random",
   require "crewmates.content.character",
   require "crewmates.memory",
   require "crewmates.conversation_runtime",
   require "crewmates.crew_factory",
   require "crewmates.crew_factory_officers",
   require "crewmates.qa_fixture",
   require "crewmates.crew_factory_npcs",
   require "crewmates.simulation",
   require "crewmates.management",
   require "crewmates.management_discussions",
   require "crewmates.management_ui",
   require "crewmates.shuttle",
   require "crewmates.missions.away",
   (require "crewmates.abilities.engineers"),
}

local registry, host_environment = contract.wire(specifications)
local installed_callbacks = callbacks.install(registry, host_environment)

return {
   registry = registry,
   callbacks = installed_callbacks,
}
