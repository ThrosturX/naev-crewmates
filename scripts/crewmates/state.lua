local state = {}

state.VERSION = 2

local function ensure_table(container, key)
   if type(container[key]) ~= "table" then
      container[key] = {}
   end
   return container[key]
end

local function ship_name(value)
   if type(value) == "string" then
      return value
   end
   if value and type(value.nameRaw) == "function" then
      return value:nameRaw()
   end
end

local function migrate_shuttle(holder, ship_api)
   if type(holder) ~= "table" or not ship_api then
      return
   end
   if ship_name(holder.ship) == "Cargo Shuttle" then
      holder.ship = ship_api.get("Alpaca")
   end
end

function state.initialize(mem, ship_api)
   assert(type(mem) == "table", "crewmates state requires mem")

   mem.companions = ensure_table(mem, "companions")
   mem.costs = ensure_table(mem, "costs")
   mem.ship_interior = ensure_table(mem, "ship_interior")

   local interior = mem.ship_interior
   interior.dirt = tonumber(interior.dirt) or 0
   interior.dirt_accum = tonumber(interior.dirt_accum) or 0
   interior.bay_strength = tonumber(interior.bay_strength) or 0

   local version = tonumber(mem.state_version) or 0
   if version < state.VERSION then
      state.migrate(mem, version, ship_api)
   end
   return mem
end

function state.migrate(mem, from_version, ship_api)
   local version = tonumber(from_version) or 0
   if version < 1 then
      mem.companions = ensure_table(mem, "companions")
      mem.costs = ensure_table(mem, "costs")
      mem.ship_interior = ensure_table(mem, "ship_interior")
   end
   if version < 2 then
      migrate_shuttle(mem.ship_interior.shuttle, ship_api)
      for _, crewmate in ipairs(mem.companions) do
         migrate_shuttle(crewmate.shuttle, ship_api)
      end
   end
   mem.state_version = state.VERSION
   return mem
end

function state.reset_runtime_hooks(mem)
   mem.conversation_hook = nil
   mem.fatigue_hook = nil
   mem.hail_hook = nil
   mem.joyride_spawn_hook = nil
   mem.joyride_end_hook = nil
   mem.joyride_return_hook = nil
   mem.crewmates_joyride = nil
   mem.crewmates_joyride_client = nil
end

return state
