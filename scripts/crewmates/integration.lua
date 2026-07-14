local fmt = require "format"
local commander_service = require "crewmates.commander_service"
local crew_lifecycle = require "crewmates.crew_lifecycle"
local roster = require "crewmates.roster"
local state = require "crewmates.state"
local contract = require "crewmates.module_contract"

local requirements = {}

local function requirement_for(client)
   return requirements[client]
end

local function normalize_requirement(options)
   options = options or {}
   assert(not options.minimum or tonumber(options.minimum) == 1,
      "Crewmates currently supports exactly one required commander")
   return {
      minimum = 1,
      shuttle = options.shuttle or "Alpaca",
      shuttle_profile = options.shuttle_profile,
   }
end

local function commander_title()
   return _("Commander")
end

local function in_roster(candidate)
   for _, crewmember in ipairs(mem.companions) do
      if crewmember == candidate then
         return true
      end
   end
   return false
end

function ensureExternalCommander(client, options)
   assert(type(client) == "string" and client ~= "",
      "Crewmates commander requirements need a client ID")
   local requirement = normalize_requirement(options)
   requirements[client] = requirement
   state.initialize(mem, ship)
   local commander = commander_service.ensure(
      mem, requirement, commander_title(), createFirstOfficer, ship, getCommander)
   requirement.commander = commander
   roster.ensure_bay_strength(mem, player)
   return commander
end

function getExternalCommander(client)
   local requirement = requirement_for(client)
   if not requirement then
      return nil, "commander requirement is not registered"
   end
   local commander = requirement.commander
   if in_roster(commander)
      and commander_service.is_eligible(commander, requirement, commander_title()) then
      return commander
   end
   commander = commander_service.find(mem, requirement, commander_title())
   requirement.commander = commander
   return commander
end

function getExternalCommanderShuttle(client)
   local commander, reason = getExternalCommander(client)
   if not commander then
      return nil, reason
   end
   return commander.shuttle and commander.shuttle.ship
end

function getExternalShuttleProfile(commander)
   for client, requirement in pairs(requirements) do
      if requirement.commander == commander and requirement.shuttle_profile then
         return requirement.shuttle_profile, client
      end
   end
end

function canDismissRequiredCrew(crewmember, replacement)
   local allowed, client = commander_service.can_dismiss(
      mem, requirements, crewmember, replacement, commander_title())
   if allowed then
      return true
   end
   return false, fmt.f(
      _("{name} is the last eligible commander required by {client}. Select a replacement before dismissing this crewmate."),
      { name = crewmember.name, client = client }
   )
end

function attachExternalMothership(client, mothership_pilot)
   local commander, reason = getExternalCommander(client)
   if not commander then
      return nil, reason
   end
   commander.pilot = mothership_pilot
   -- Joyride's custom lifecycle event installs the named hail hook from the
   -- Crewmates event. Installing it through this cross-event API would make
   -- Naev resolve startCommandDiscussion in the caller's event instead.
   return commander
end

function releaseExternalMothership(client, mothership_pilot)
   local commander, reason = getExternalCommander(client)
   if not commander then
      return nil, reason
   end
   if not mothership_pilot or commander.pilot == mothership_pilot then
      commander.pilot = nil
   end
   return commander
end

function replaceExternalCommander(client, candidate, reason)
   local requirement = requirement_for(client)
   if not requirement then
      return nil, "commander requirement is not registered"
   end
   if not commander_service.is_eligible(candidate, { minimum = 1 }, commander_title()) then
      return nil, "replacement is not an eligible commander"
   end
   commander_service.prepare(candidate, requirement, ship)
   local incumbent = getExternalCommander(client)
   if incumbent == candidate then
      return candidate
   end

   local present = false
   for _, crewmember in ipairs(mem.companions) do
      if crewmember == candidate then
         present = true
         break
      end
   end
   if not present then
      mem.companions[#mem.companions + 1] = candidate
   end

   if not incumbent then
      requirement.commander = candidate
      mem.ship_interior.shuttle = candidate.shuttle
      return candidate
   end

   local allowed, denial = canDismissRequiredCrew(incumbent, candidate)
   if not allowed then
      if not present then
         for index, crewmember in ipairs(mem.companions) do
            if crewmember == candidate then
               table.remove(mem.companions, index)
               break
            end
         end
      end
      return nil, denial
   end
   crew_lifecycle.terminate(
      mem, npcs, incumbent,
      reason or fmt.f(_("You replaced '{old_name}' with '{new_name}'."), {
         old_name = incumbent.name, new_name = candidate.name,
      }),
      player, logidstr
   )
   requirement.commander = candidate
   mem.ship_interior.shuttle = candidate.shuttle
   return candidate
end

return contract.capture {
   name = "integration",
   requires = { "context", "crew_factory_officers" },
   exports = {
      "ensureExternalCommander", "getExternalCommander",
      "getExternalCommanderShuttle", "getExternalShuttleProfile",
      "canDismissRequiredCrew",
      "attachExternalMothership", "releaseExternalMothership",
      "replaceExternalCommander",
   },
}
