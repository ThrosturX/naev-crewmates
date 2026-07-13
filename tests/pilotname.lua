package.path = 'scripts/?.lua;scripts/?/init.lua;' .. package.path

local host = getfenv and getfenv(1) or _ENV
host._ = function(value) return value end
host.p_ = function(_context, value) return value end
host.rnd = {
   rnd = function(first, _last)
      if first ~= nil then return first end
      return 0.5
   end,
}

package.preload.format = function()
   return {
      f = function(text, values)
         return (text:gsub('{([%w_]+)}', function(key)
            return tostring(values[key])
         end))
      end,
   }
end
package.preload['pilotname.utility'] = function()
   return { roman_encode = tostring }
end
package.preload['pilotname.pirate'] = function()
   return function() return 'Corsair' end
end

local names = require 'crewmates.pilotname'
local lastname, firstname = names.human()
assert(type(lastname) == 'string' and lastname ~= '', 'human last name must be populated')
assert(type(firstname) == 'string' and firstname ~= '', 'human first name must be populated')
assert(type(names.generic()) == 'string', 'custom generic generator must be callable')
assert(names.pirate() == 'Corsair', 'upstream pirate generator must remain available')

print('ok - Crewmates pilot name generators')
