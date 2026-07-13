package.path = 'scripts/?.lua;scripts/?/init.lua;' .. package.path

local assertions = 0
local host = getfenv and getfenv(1) or _ENV

local function equal(actual, expected, message)
   assertions = assertions + 1
   if actual ~= expected then
      error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2)
   end
end

host._ = function(value) return value end
host.rnd = {
   rnd = function(first, _last)
      return first or 0.5
   end,
}

local util = require 'crewmates.util'
equal(util.pick_one({}, 'fallback'), 'fallback', 'empty arrays use their fallback')
equal(util.join_arrays({ 1, 2 }, { 3 })[3], 3, 'arrays are joined')
equal(util.sanitize_phrase('the good ship', { 'the' }), 'good ship', 'phrases are sanitized')

local state = require 'crewmates.state'
local mem = { ship_interior = { dirt = '2.5' } }
state.initialize(mem)
equal(mem.ship_interior.dirt, 2.5, 'numeric save fields are normalized')
equal(mem.ship_interior.bay_strength, 0, 'missing save fields get defaults')
equal(mem.state_version, state.VERSION, 'save state is migrated')

local legacy_shuttle = { nameRaw = function() return 'Cargo Shuttle' end }
local alpaca = { nameRaw = function() return 'Alpaca' end }
local legacy = {
   state_version = 1,
   companions = { { shuttle = { ship = legacy_shuttle } } },
   ship_interior = { shuttle = { ship = legacy_shuttle } },
}
state.initialize(legacy, {
   get = function(name)
      equal(name, 'Alpaca', 'migration requests the replacement hull')
      return alpaca
   end,
})
equal(legacy.ship_interior.shuttle.ship, alpaca, 'shared shuttle migrates to Alpaca')
equal(legacy.companions[1].shuttle.ship, alpaca, 'personal shuttle migrates to Alpaca')

mem.conversation_hook = 1
mem.fatigue_hook = 2
mem.hail_hook = 3
state.reset_runtime_hooks(mem)
equal(mem.conversation_hook, nil, 'conversation hooks are transient')
equal(mem.fatigue_hook, nil, 'fatigue hooks are transient')
equal(mem.hail_hook, nil, 'hail hooks are transient')

local roster = require 'crewmates.roster'
local docking = require 'crewmates.docking'
local crew_mem = {
   companions = {
      { typetitle = 'Engineer', manager = { type = 'Science' } },
      { typetitle = 'Commander', manager = { type = 'Command' }, away = true },
   },
   ship_interior = {},
}
equal(roster.find_with_title(crew_mem, 'engineer').typetitle, 'Engineer', 'crew lookup ignores case')
equal(roster.find_with_title(crew_mem, 'commander'), nil, 'away crew are unavailable by default')
equal(docking.range({ xp = 0, satisfaction = 0, bonus = 0 }), 350,
   'docking range clears the current follow controller deadband')
equal(docking.range({ xp = 100, satisfaction = 10, bonus = 50 }), 450,
   'docking skill bonus is capped deterministically')
equal(roster.find_with_title(crew_mem, 'commander', true).typetitle, 'Commander', 'away crew can be included')

local outfits = {
   { nameRaw = function() return 'Fighter Bay' end },
   { nameRaw = function() return 'Docking Clamp' end },
}
local player = {
   pilot = function()
      return { outfitsList = function() return outfits end }
   end,
}
roster.calculate_bay_strength(crew_mem, 3, player)
equal(crew_mem.ship_interior.bay_strength, 4.02, 'bay strength includes cargo workers')

print(('ok - %d module assertions'):format(assertions))
