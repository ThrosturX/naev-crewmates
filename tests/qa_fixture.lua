package.path = 'scripts/?.lua;scripts/?/init.lua;' .. package.path

local assertions = 0
local host = getfenv and getfenv(1) or _ENV
local function check(condition, message)
   assertions = assertions + 1
   if not condition then error(message, 2) end
end

local marker = 1
local event_persistent = false
host.evt = {
   save = function(persistent)
      check(persistent == true, 'fixture preserves the companion event')
      event_persistent = true
   end,
}
host.var = {
   peek = function(name)
      check(name == '_crewmates_qa_fixture', 'fixture reads only its namespaced marker')
      if marker == nil then return end
      return marker
   end,
   pop = function(name)
      check(name == '_crewmates_qa_fixture', 'fixture removes only its namespaced marker')
      marker = nil
   end,
}
local shuttle = { name = 'Alpaca' }
host.ship = { get = function(name)
   check(name == 'Alpaca', 'fixture installs the expected shared shuttle')
   return shuttle
end }

local function character(kind)
   return {
      kind = kind,
      conversation = { backstory = {}, special = {} },
   }
end

local contract = require 'crewmates.module_contract'

host.createGenericCrewmate = function() return character('generic') end
host.createPsychologistManager = function() return character('psychologist') end
host.createMoraleOfficer = function() return character('morale') end
host.createScienceFarmer = function() return character('science') end
host.createGenericManager = function() return character('manager') end
host.createPassenger = function() return character('passenger') end
local factory = contract.capture {
   name = 'crew_factory',
   exports = {
      'createGenericCrewmate', 'createPsychologistManager',
      'createMoraleOfficer', 'createScienceFarmer',
      'createGenericManager', 'createPassenger',
   },
}

host.createFirstOfficer = function() return character('first officer') end
host.createPirateOfficer = function() return character('pirate commander') end
host.createShuttlePilot = function() return character('pilot') end
host.createEscortCompanion = function() return character('escort') end
host.createSmuggler = function() return character('smuggler') end
host.createArmorEngineer = function() return character('hull engineer') end
host.createShieldEngineer = function() return character('shield engineer') end
host.createPowerEngineer = function() return character('core engineer') end
host.createExplosivesEngineer = function() return character('demolitions engineer') end
local officers = contract.capture {
   name = 'crew_factory_officers',
   exports = {
      'createFirstOfficer', 'createPirateOfficer', 'createShuttlePilot',
      'createEscortCompanion', 'createSmuggler', 'createArmorEngineer',
      'createShieldEngineer', 'createPowerEngineer',
      'createExplosivesEngineer',
   },
}

local fixture = require 'crewmates.qa_fixture'
local registry = contract.wire { factory, officers, fixture }
local mem = { companions = {}, ship_interior = {} }

check(registry.module('qa_fixture').seedQaFixture(mem), 'fixture seeds when requested')
check(#mem.companions == 27, 'fixture provides a broad 27-person roster')
check(mem.companions[1].name == 'QA First Officer', 'first officer is easy to identify')
check(mem.companions[2].name == 'QA Pirate Commander', 'competing commander is present')
check(mem.companions[4].name == 'QA Escort Companion', 'escort companion is present')
check(mem.companions[5].name == 'QA Smuggler', 'first-officer/smuggler exclusion is bypassed')
check(mem.companions[5].satisfaction < 0, 'fixture includes an unhappy specialist')
check(mem.companions[16].satisfaction < 0, 'fixture includes an unhappy ordinary worker')
check(mem.ship_interior.shuttle.ship == shuttle, 'shared shuttle is bay-ready')
check(mem.ship_interior.dirt > 0 and mem.ship_interior.dirt_accum > 0,
   'dirty-ship management starts in a testable state')
check(mem.qa_fixture_version == 1 and mem.qa_fixture_seeded,
   'seed provenance remains visible in the event state')
check(event_persistent, 'seeded roster belongs to a persistent event')
check(marker == nil, 'one-shot marker is removed after success')
check(not registry.module('qa_fixture').seedQaFixture(mem), 'fixture cannot seed twice')

marker = 1
local ok, fixture_error = pcall(registry.module('qa_fixture').seedQaFixture, mem)
check(not ok and fixture_error:find('refusing to seed', 1, true) ~= nil,
   'fixture refuses to overwrite an existing roster')
check(marker == 1, 'failed fixture bootstrap retains its marker for diagnosis')

print(string.format('ok - %d QA fixture assertions', assertions))
