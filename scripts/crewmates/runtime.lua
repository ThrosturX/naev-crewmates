-- Composition root for the persistent crewmates event. Domain modules declare
-- contracts, the contract loader wires their dependencies without leaking
-- implementation symbols, and the callback adapter exposes only names that
-- Naev must resolve from hook strings.

local contract = require "crewmates.module_contract"
local callbacks = require "crewmates.callbacks"
local public_api = require "crewmates.api"

local specifications = {
   require "crewmates.context",
   require "crewmates.content.random",
   require "crewmates.content.character",
   require "crewmates.memory",
   require "crewmates.conversation_runtime",
   require "crewmates.crew_factory",
   require "crewmates.crew_factory_officers",
   require "crewmates.integration",
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
local integration = registry.module("integration")
local shuttle = registry.module("shuttle")

local function ensure_commander(client, options)
   local commander = integration.ensureExternalCommander(client, options)
   -- External requirements can create the first crewmember after the event's
   -- ordinary empty-roster path marked it non-persistent. Keep that commander
   -- and its shuttle in the pilot save.
   evt.save(true)
   naev.trigger("crewmates_commander_ready", { client = client })
   return commander
end

local function launch_commander_shuttle(client)
   local commander, reason = integration.getExternalCommander(client)
   if not commander then return false, reason end
   if commander.shuttle and commander.shuttle.out then
      return false, _("the commander shuttle is already deployed")
   end
   if naev.cache().joyride then
      return false, _("another auxiliary ship is already active")
   end
   local launched = shuttle.player_swaps_to_shuttle {
      commander = commander,
      -- The required commander owns and pilots this shuttle. Using the same
      -- persisted manager record makes Crewmates apply and retain its loadout.
      shuttle_manager = commander,
   }
   if not launched then
      return false, _("the commander shuttle could not launch")
   end
   return true
end

public_api.install {
   ensure_commander = ensure_commander,
   launch_commander_shuttle = launch_commander_shuttle,
   get_commander = integration.getExternalCommander,
   get_commander_shuttle = integration.getExternalCommanderShuttle,
   attach_mothership = integration.attachExternalMothership,
   release_mothership = integration.releaseExternalMothership,
   can_dismiss = integration.canDismissRequiredCrew,
   replace_commander = integration.replaceExternalCommander,
}

return {
   registry = registry,
   callbacks = installed_callbacks,
}
