-- Crewmates owns its human and generic name generators.  Naev's pilotname
-- loader no longer exports plugin-provided generators, so compose the API
-- explicitly instead of mutating Naev's shared module table.

return {
   human = require "pilotname.human",
   generic = require "pilotname.generic",
   pirate = require "pilotname.pirate",
}
