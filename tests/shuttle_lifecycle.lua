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
package.preload['bioship.skills'] = function()
   return { set = { attack = { attack1 = {}, attack2 = {} } } }
end

local pilot_adds = 0
local template_outfits = {}
local template = {
   setVel = function() end,
   setDir = function() end,
   outfitRm = function() end,
   outfitAdd = function(_, name) template_outfits[#template_outfits + 1] = name end,
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
host.ship = {
   get = function(name) return 'ship:' .. name end,
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
   manager = {
      outfits = { 'Small Cargo Pod' },
      virtual_state = {
         hull = 'Alpaca',
         shipvars = { biostage = 2, bio_attack1 = true },
         weapon_sets = { [1] = { 3 } },
      },
   },
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
local external_profile
host.getExternalShuttleProfile = function()
   return external_profile, external_profile and 'nomad' or nil
end
specifications[#specifications + 1] = contract.capture {
   name = 'integration',
   exports = { 'getExternalShuttleProfile' },
}
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
assert(swap_call.profile.persist_virtual_state
   and swap_call.profile.virtual_state == manager.manager.virtual_state,
   'Crewmates must opt into restoring its persistent virtual shuttle state')
local persistent_vars = {}
for _shipvar_index, name in ipairs(swap_call.profile.shipvars) do
   persistent_vars[name] = true
end
assert(persistent_vars.bioshipexp and persistent_vars.biostage
   and persistent_vars.bio_attack1 and persistent_vars.bio_attack2,
   'Crewmates must request core and discovered bioship variables')
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
   client = 'TXCrewmates', returned_kind = 'virtual', hull = 'Llama',
   outfits = { 'Pulse Scanner' },
   virtual_state = {
      hull = 'Llama', shipvars = { biostage = 3 },
      weapon_sets = { [2] = { 4 } },
   },
}
assert(not host.mem.crewmates_joyride and not host.mem.ship_interior.shuttle.out,
   'returning must clear Crewmates joyride state')
assert(manager.manager.outfits[1] == 'Pulse Scanner',
   'returned shuttle outfitting must be preserved')
assert(manager.shuttle.ship == 'ship:Llama',
   'a returned virtual replacement must become the commander shuttle')
assert(manager.manager.virtual_state.hull == 'Llama'
   and manager.manager.virtual_state.shipvars.biostage == 3
   and manager.manager.virtual_state.weapon_sets[2][1] == 4,
   'returned virtual state must remain attached to the shuttle manager')
assert(commander.pilot == nil
   and registry.module('context').joyride_commander == nil,
   'returning must release the transient commander pilot')

host.mem.ship_interior.shuttle = { ship = 'Alpaca' }
commander.shuttle = host.mem.ship_interior.shuttle
commander.manager = { outfits = { 'Persistent Scanner' } }
commander.manager.virtual_state = {
   hull = 'Alpaca', shipvars = { bioshipexp = 700 },
   weapon_sets = { [3] = { 5 } },
}
template_outfits = {}
assert(shuttle.player_swaps_to_shuttle {
   commander = commander,
   shuttle_manager = commander,
}, 'a required commander must launch its own shuttle')
assert(template_outfits[1] == 'Persistent Scanner',
   'command launch must restore the commander shuttle loadout')
assert(swap_call.profile.virtual_state == commander.manager.virtual_state,
   'command launch must pass the commander shuttle state back to Joyride')
shuttle.joyride_ended {
   client = 'TXCrewmates', returned_kind = 'virtual', hull = 'Alpaca',
   outfits = { 'Updated Scanner' },
   virtual_state = {
      hull = 'Alpaca', shipvars = { bioshipexp = 900 },
      weapon_sets = { [4] = { 6 } },
   },
}
assert(commander.manager.outfits[1] == 'Updated Scanner',
   'command return must persist the updated shuttle loadout')
assert(commander.manager.virtual_state.shipvars.bioshipexp == 900
   and commander.manager.virtual_state.weapon_sets[4][1] == 6,
   'command return must persist bioship and weapon-set state')

host.mem.ship_interior.shuttle = { ship = 'Alpaca' }
manager.shuttle = host.mem.ship_interior.shuttle
external_profile = {
   client = 'nomad', landable = true, trade_replacement = true,
   owned_handoff = true, owned_escorts = true,
}
shuttle.player_swaps_to_shuttle {
   commander = commander,
   shuttle_manager = manager,
}
assert(swap_call.profile.client == 'nomad' and swap_call.profile.landable,
   'registered Nomad options must select the opt-in Joyride profile')
shuttle.joyride_shuttle_returned {
   client = 'nomad', outfits = { 'Scanner' },
}
assert(not manager.shuttle.out and host.mem.crewmates_joyride,
   'Buy handoff must mark the virtual shuttle returned without ending the sortie')
shuttle.joyride_ended {
   client = 'nomad', returned_kind = 'owned', hull = 'Hyena', outfits = {},
}
assert(manager.shuttle.ship == 'Alpaca',
   'returning an owned seat must not replace the commander virtual shuttle')

host.naev.claimTest = function() return false end
local launched, launch_reason = shuttle.player_swaps_to_shuttle {
   commander = commander,
   shuttle_manager = manager,
   show_error = false,
}
assert(not launched and launch_reason:find('Electromagnetic interference', 1, true),
   'API launches must return claim failures without opening a VN dialogue')

print('ok - Crewmates Joyride integration')
