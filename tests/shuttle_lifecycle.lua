package.path = 'scripts/?.lua;scripts/?/init.lua;' .. package.path

local host = getfenv and getfenv(1) or _ENV
host._ = function(text) return text end

local swap_call
package.preload.joyride = function()
   return {
      swap_to_subship = function(player_pilot, template, acquired, profile)
         swap_call = {
            player_pilot = player_pilot,
            template = template,
            acquired = acquired,
            profile = profile,
         }
      end,
   }
end
package.preload.format = function()
   return { f = function(text) return text end }
end
package.preload.vntk = function()
   return { msg = function() error('unexpected launch error') end }
end

local pilot_adds = 0
local template = {
   setVel = function() end,
   setDir = function() end,
   outfitRm = function() end,
   outfitAdd = function() end,
}
local player_pilot = {
   pos = function() return 'position' end,
   vel = function() return 'velocity' end,
   dir = function() return 0 end,
   setHealth = function() end,
   setEnergy = function() end,
   target = function() return nil end,
   nav = function() return nil end,
}
host.pilot = {
   add = function()
      pilot_adds = pilot_adds + 1
      return template
   end,
}
host.player = {
   pilot = function() return player_pilot end,
   ship = function() return 'QA Carrier' end,
}
host.system = { cur = function() return 'Delta Polaris' end }
host.naev = {
   claimTest = function() return true end,
   cache = function() return {} end,
}
local hail_pilot
host.hook = {
   pilot = function(pilot)
      hail_pilot = pilot
      return 1
   end,
   timer = function() return 2 end,
   rm = function() end,
}
host.rnd = { rnd = function() return 0 end }
host.mem = {
   ship_interior = {
      shuttle = { ship = 'Alpaca' },
   },
}
host.FAKE_CAPTAIN = {}
host.SHIP_OFFICERS = {}
host.mothership = 'initial mothership'
host.joyride_commander = false
host.clearCommanderInterface = function() end
host.addCommanderInterface = function() end
host.getConversation = function() return { message = { 'hello' } } end
host.pick_one = function(items) return items[1] end

local commander = {
   name = 'QA First Officer',
   skill = 'First Officer',
   typetitle = 'Commander',
   faction = 'Independent',
   xp = 20,
   satisfaction = 0,
}
local manager = {
   name = 'QA Shuttle Pilot',
   manager = { outfits = { 'Small Cargo Pod' } },
   shuttle = host.mem.ship_interior.shuttle,
}
host.getCommander = function() return commander end
host.findManagerOfType = function() return manager end
host.findCrewOfType = function() return manager end

local contract = require 'crewmates.module_contract'
local specifications = {
   contract.capture {
      name = 'context',
      exports = {
         'FAKE_CAPTAIN', 'SHIP_OFFICERS', 'mothership', 'joyride_commander',
         'getCommander', 'findManagerOfType', 'findCrewOfType',
         'clearCommanderInterface', 'addCommanderInterface',
         'getConversation', 'pick_one',
      },
   },
}
for index, name in ipairs {
   'content.character', 'management', 'management_discussions',
} do
   local export = 'dependency_' .. index
   host[export] = true
   specifications[#specifications + 1] = contract.capture {
      name = name,
      exports = { export },
   }
end
specifications[#specifications + 1] = require 'crewmates.shuttle'
local registry = contract.wire(specifications)
local shuttle = registry.module('shuttle')

assert(shuttle.player_swaps_to_shuttle {
   commander = commander,
   shuttle_manager = manager,
}, 'Crewmates joyride should launch')
assert(pilot_adds == 1, 'Crewmates may create only the disposable shuttle template')
assert(swap_call and swap_call.profile.client == 'TXCrewmates',
   'Crewmates must identify itself to Joyride')
assert(swap_call.profile.ai == 'escort_guardian',
   'Joyride must receive the commander mothership AI')
assert(host.mem.crewmates_joyride and host.mem.ship_interior.shuttle.out,
   'Crewmates must mark its shuttle in flight')

local mothership_pilot = {}
shuttle.joyride_mothership_spawned { client = 'joyride', pilot = mothership_pilot }
assert(commander.pilot == nil, 'independent joyrides must not alter Crewmates state')
shuttle.joyride_mothership_spawned {
   client = 'TXCrewmates', pilot = mothership_pilot,
}
assert(commander.pilot == mothership_pilot and hail_pilot == mothership_pilot,
   'Crewmates must attach its commander to Joyride\'s mothership')

shuttle.joyride_ended {
   client = 'TXCrewmates', outfits = { 'Pulse Scanner' },
}
assert(not host.mem.crewmates_joyride and not host.mem.ship_interior.shuttle.out,
   'returning must clear Crewmates joyride state')
assert(manager.manager.outfits[1] == 'Pulse Scanner',
   'returned shuttle outfitting must be preserved')
assert(commander.pilot == nil
   and registry.module('context').joyride_commander == nil,
   'returning must release the transient commander pilot')

print('ok - Crewmates Joyride integration')
