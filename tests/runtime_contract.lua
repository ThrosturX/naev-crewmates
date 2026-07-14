package.path = 'scripts/?.lua;scripts/?/init.lua;events/?.lua;' .. package.path

local assertions = 0
local host = getfenv and getfenv(1) or _ENV
local function check(condition, message)
   assertions = assertions + 1
   if not condition then
      error(message, 2)
   end
end

-- Naev's event environment inherits some engine builtins instead of storing
-- them directly on the event chunk.
local inherited_globals = {
   __contract_inherited_builtin = function() return 23 end,
}
setmetatable(host, { __index = inherited_globals })

host._ = function(value) return value end
host.p_ = function(_context, value) return value end
host.n_ = function(singular, plural, count) return count == 1 and singular or plural end
host.mem = {}
host.rnd = {
   rnd = function(first, _last) return first or 0.5 end,
   sigma = function() return 0 end,
   twosigma = function() return 0 end,
   threesigma = function() return 0 end,
}
local naev_cache = {}
local triggered_event
local event_saved
host.evt = {
   save = function(value) event_saved = value end,
}
host.naev = {
   cache = function() return naev_cache end,
   trigger = function(name, payload)
      triggered_event = { name = name, payload = payload }
   end,
}

local object
object = setmetatable({}, {
   __index = function(_, key)
      if key == 'name' or key == 'nameRaw' then
         return function() return 'Test' end
      end
      if key == 'size' then
         return function() return 2 end
      end
      return function() return object end
   end,
})
object.outfitsList = function() return {} end

host.player = {
   name = function() return 'Test Captain' end,
   pilot = function() return object end,
   ship = function() return 'Test Ship' end,
   isLanded = function() return true end,
}
host.var = {
   peek = function() return nil end,
   pop = function() end,
}
host.ship = {
   get = function() return object end,
   getAll = function() return { object } end,
}
host.outfit = {
   getAll = function() return { object } end,
}
host.spob = {
   getAll = function() return {} end,
}
host.faction = {
   get = function(name) return name end,
}
local shiplog_creates = 0
host.shiplog = {
   create = function() shiplog_creates = shiplog_creates + 1 end,
   append = function() end,
}
host.hook = setmetatable({
   rm = function() end,
}, {
   __index = function()
      return function() return 1 end
   end,
})

package.preload.format = function()
   return {
      f = function(text, _values) return text end,
      credits = tostring,
      number = tostring,
   }
end
package.preload.portrait = function()
   return {
      getMale = function() return 'male.webp' end,
      getFemale = function() return 'female.webp' end,
      getFullPath = function(value) return value end,
   }
end
package.preload['pilotname.human'] = function()
   return function() return 'Tester', 'Casey' end
end
package.preload['pilotname.pirate'] = function()
   return function() return 'Corsair' end
end
package.preload['pilotname.generic'] = function()
   return function() return 'Generic' end
end
package.preload.vntk = function() return {} end
package.preload.vn = function() return { textbox_font = {} } end
local money_sounds = 0
package.preload.lmisn = function()
   return { sfxMoney = function() money_sounds = money_sounds + 1 end }
end
package.preload['love.graphics'] = function() return {} end
package.preload.love_shaders = function() return {} end
package.preload['common.derelict'] = function() return { sfx = {} } end
package.preload['common.pirate'] = function()
   return { factionIsPirate = function() return false end }
end
package.preload.prng = function()
   return { new = function() return { random = function(_, first) return first or 0.5 end } end }
end
package.preload.joyride = function() return {} end

local runtime = require 'crewmates.runtime'
local context = runtime.registry.module('context')
local random_content = runtime.registry.module('content.random')
local crew_factory = runtime.registry.module('crew_factory')

check(type(host.create) == 'function', 'Naev create callback must be installed')
check(type(host.startCommandDiscussion) == 'function', 'named hook callbacks must be installed')
check(host.pick_one == nil, 'ordinary helpers must not leak into the host environment')
check(host.getCommander == nil, 'domain functions must not leak into the host environment')
check(context.pick_one({ 42 }) == 42, 'module APIs remain callable')
check(random_content.getSpaceThing() ~= nil, 'declared cross-module dependencies resolve')
local isolated_backstory = crew_factory.generateBackstory {
   typetitle = 'Commander', faction = 'Independent', skill = 'First Officer',
}
check(type(isolated_backstory) == 'table' and isolated_backstory.origin ~= nil,
   'commander backstories survive systems with no faction spob candidates')

host.create()
check(type(context.npcs) == 'table', 'shared module slots propagate explicit mutations')
check(shiplog_creates == 1, 'event startup creates its ship log before appending')
context.playMoney()
check(money_sounds == 1, 'money cues use Naev mission sound helpers')

package.loaded['crewmates.api'] = nil
local public_api = require 'crewmates.api'
check(public_api.is_ready(),
   'public API provider survives a separate consumer module environment')
local alpaca = { nameRaw = function() return 'Alpaca' end }
local commander = {
   name = 'Nomad Commander', firstname = 'Nomad', skill = 'First Officer',
   typetitle = 'Commander', xp = 10, satisfaction = 2,
   shuttle = { ship = alpaca },
   hook = { func = 'command' },
}
host.mem.companions[#host.mem.companions + 1] = commander
local nomad_profile = { client = 'nomad', landable = true }
host.player.isLanded = function() return false end
check(public_api.ensure_commander('nomad', {
   shuttle_profile = nomad_profile,
}) == commander,
   'public API returns an existing eligible commander')
check(event_saved == true,
   'external commander requirements make the Crewmates event persistent')
check(type(public_api.launch_commander_shuttle) == 'function',
   'public API exposes command shuttle launch')
host.player.isLanded = function() return true end
check(triggered_event and triggered_event.name == 'crewmates_commander_ready'
   and triggered_event.payload.client == 'nomad',
   'external registration requests activation through the Crewmates event')
local selected_profile, selected_client = runtime.registry.module(
   'integration').getExternalShuttleProfile(commander)
check(selected_profile == nomad_profile and selected_client == 'nomad',
   'commander requirements retain their selected Joyride profile')
check(public_api.get_commander('nomad') == commander,
   'public API exposes the commander selected for mothership control')
check(public_api.get_commander_shuttle('nomad') == alpaca,
   'public API exposes the guaranteed commander Alpaca')
local dismissible, denial = public_api.can_dismiss(commander)
check(not dismissible and type(denial) == 'string',
   'public API protects the last registered commander')
local replacement = {
   name = 'Nomad Commander', typetitle = 'Commander', xp = 8,
   shuttle = { ship = alpaca },
}
check(public_api.can_dismiss(commander, replacement),
   'public API accepts an eligible atomic replacement')
local mothership_pilot = {}
check(public_api.attach_mothership('nomad', mothership_pilot) == commander
   and commander.pilot == mothership_pilot,
   'public API attaches the commander to an external mothership')
public_api.release_mothership('nomad', mothership_pilot)
check(commander.pilot == nil, 'public API releases the external mothership')
check(public_api.replace_commander('nomad', replacement) == replacement,
   'public API atomically selects an eligible replacement')
check(#host.mem.companions == 1 and host.mem.companions[1] == replacement,
   'atomic replacement removes only the incumbent, even when names match')
check(public_api.get_commander('nomad') == replacement,
   'public API exposes the replacement after the atomic change')

local providers = runtime.registry.providers()
check(providers.startCommandDiscussion == 'management_discussions', 'providers are explicit')
check(runtime.callbacks.startCommandDiscussion == 'management_discussions', 'callback ownership is recorded')

for symbol in pairs(providers) do
   if host[symbol] ~= nil then
      check(runtime.callbacks[symbol] ~= nil,
         symbol .. ' leaked into the host environment without being a callback')
   end
end

for callback, provider in pairs(runtime.callbacks) do
   check(type(host[callback]) == 'function', callback .. ' callback was not installed')
   check(providers[callback] == provider, callback .. ' callback provider drifted')
end

local contract = require 'crewmates.module_contract'
local compile = loadstring or load
local ok, contract_error

assert(compile([[
local function nested_helper()
   return __contract_inherited_builtin()
end
__contract_inherited_reader = function()
   return nested_helper()
end
]]))()
local inherited_reader = contract.capture {
   name = 'contract.inherited_reader',
   exports = { '__contract_inherited_reader' },
}
local inherited_registry = contract.wire { inherited_reader }
inherited_globals.__contract_added_later = function() return 99 end
check(inherited_registry.module('contract.inherited_reader').__contract_inherited_reader() == 23,
   'inherited Naev builtins resolve through nested local helpers')

assert(compile('__contract_late_reader = function() return __contract_added_later() end'))()
local late_reader = contract.capture {
   name = 'contract.late_reader',
   exports = { '__contract_late_reader' },
}
local late_registry = contract.wire { late_reader }
ok, contract_error = pcall(late_registry.module('contract.late_reader').__contract_late_reader)
check(not ok, 'globals added to the inherited table after contract load stay hidden')

assert(compile('__contract_beta = function() return 7 end'))()
local beta = contract.capture {
   name = 'contract.beta',
   exports = { '__contract_beta' },
}
assert(compile('__contract_alpha = function() return __contract_beta() end'))()
local alpha = contract.capture {
   name = 'contract.alpha',
   exports = { '__contract_alpha' },
}
local isolated = contract.wire { beta, alpha }
ok, contract_error = pcall(isolated.module('contract.alpha').__contract_alpha)
check(not ok, 'undeclared dependencies must fail')
check(contract_error:find('without declaring dependency', 1, true) ~= nil,
   'undeclared dependencies must produce a useful error')

assert(compile('__contract_writer = function() __accidental_global = true end'))()
local writer = contract.capture {
   name = 'contract.writer',
   exports = { '__contract_writer' },
}
local guarded = contract.wire { writer }
ok, contract_error = pcall(guarded.module('contract.writer').__contract_writer)
check(not ok, 'accidental global writes must fail')
check(contract_error:find('attempted to create undeclared global', 1, true) ~= nil,
   'global write failures must identify the problem')

print(('ok - %d runtime contract assertions'):format(assertions))
