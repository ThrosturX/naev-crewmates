-- Runtime boundary for the gradually modularized crewmates event.
--
-- Legacy domain files still use bare names internally.  Each file captures
-- those names into an explicit module contract.  Once every domain is loaded,
-- wire() gives its functions an environment containing only Naev globals, its
-- own exports, and exports from declared dependencies.  Internal symbols are
-- removed from the event chunk environment before the event begins running.

local contract = {}
local host_environment = getfenv and getfenv(1) or _ENV
local host_metatable = getmetatable(host_environment)
local original_inherited_index = host_metatable and host_metatable.__index
local inherited_values

if type(original_inherited_index) == "table" then
   inherited_values = {}
   for name, value in pairs(original_inherited_index) do
      inherited_values[name] = value
   end
end

local function inherited_value(name)
   if inherited_values then
      return inherited_values[name]
   end
   if type(original_inherited_index) == "function" then
      return original_inherited_index(host_environment, name)
   end
end

local function set_environment(func, environment)
   if setfenv then -- Lua 5.1 / LuaJIT (Naev)
      setfenv(func, environment)
      return
   end

   -- Lua 5.2+ keeps the chunk environment in an _ENV upvalue.
   local index = 1
   while true do
      local name = debug.getupvalue(func, index)
      if not name then
         return
      end
      if name == "_ENV" then
         debug.setupvalue(func, index, environment)
         return
      end
      index = index + 1
   end
end

local function bind_value(value, environment, seen, source)
   if type(value) == "function" then
      if seen[value] then
         return
      end
      local info = debug.getinfo(value, "S")
      if source and info and info.source ~= source then
         return
      end
      seen[value] = true
      set_environment(value, environment)

      -- Lua 5.1 gives each closure its own environment.  Rebind local helper
      -- closures from the same source file as well as the exported entrypoint.
      -- Do not descend into required libraries captured as upvalues.
      local helper_source = info and info.source or source
      local index = 1
      while true do
         local name, nested = debug.getupvalue(value, index)
         if not name then
            break
         end
         bind_value(nested, environment, seen, helper_source)
         index = index + 1
      end
      return
   end
   if type(value) ~= "table" or seen[value] then
      return
   end
   seen[value] = true
   for key, nested in pairs(value) do
      bind_value(key, environment, seen, source)
      bind_value(nested, environment, seen, source)
   end
end

function contract.capture(specification)
   assert(type(specification) == "table", "module contract must be a table")
   assert(type(specification.name) == "string", "module contract requires a name")
   specification.requires = specification.requires or {}
   specification.exports = specification.exports or {}
   specification.values = {}
   specification.host_environment = host_environment

   for _, name in ipairs(specification.exports) do
      specification.values[name] = rawget(specification.host_environment, name)
      rawset(specification.host_environment, name, nil)
   end

   return specification
end

function contract.wire(specifications)
   local modules = {}
   local providers = {}
   local slots = {}
   local host_environment

   for index, specification in ipairs(specifications) do
      assert(
         type(specification) == "table" and type(specification.name) == "string",
         string.format("invalid module contract at runtime index %d", index)
      )
      assert(not modules[specification.name], "duplicate module: " .. specification.name)
      if host_environment then
         assert(specification.host_environment == host_environment,
            "module contracts must share one host environment")
      else
         host_environment = specification.host_environment
      end
      modules[specification.name] = specification
      for _, symbol in ipairs(specification.exports) do
         assert(not providers[symbol], string.format(
            "symbol %s exported by both %s and %s",
            symbol, providers[symbol] or "?", specification.name
         ))
         providers[symbol] = specification.name
         slots[symbol] = specification.values[symbol]
      end
   end

   assert(host_environment, "at least one module contract is required")

   local base = {}
   for name, value in pairs(host_environment) do
      base[name] = value
   end

   local public_modules = {}
   for _, specification in ipairs(specifications) do
      local allowed = {}
      for _, symbol in ipairs(specification.exports) do
         allowed[symbol] = true
      end
      for _, dependency_name in ipairs(specification.requires) do
         local dependency = assert(
            modules[dependency_name],
            string.format("module %s requires unknown module %s", specification.name, dependency_name)
         )
         for _, symbol in ipairs(dependency.exports) do
            allowed[symbol] = true
         end
      end

      local environment = setmetatable({}, {
         __index = function(_, name)
            if allowed[name] then
               return slots[name]
            end
            if providers[name] then
               error(string.format(
                  "module %s used %s without declaring dependency on %s",
                  specification.name, name, providers[name]
               ), 2)
            end
            local value = base[name]
            if value ~= nil then
               return value
            end
            return inherited_value(name)
         end,
         __newindex = function(_, name, value)
            if allowed[name] then
               slots[name] = value
               return
            end
            if providers[name] then
               error(string.format(
                  "module %s mutated %s without declaring dependency on %s",
                  specification.name, name, providers[name]
               ), 2)
            end
            error(string.format(
               "module %s attempted to create undeclared global %s",
               specification.name, tostring(name)
            ), 2)
         end,
      })

      local seen = {}
      for _, symbol in ipairs(specification.exports) do
         bind_value(slots[symbol], environment, seen)
      end

      public_modules[specification.name] = setmetatable({}, {
         __index = function(_, name)
            if allowed[name] and providers[name] == specification.name then
               return slots[name]
            end
         end,
         __newindex = function()
            error("crewmates module APIs are read-only", 2)
         end,
      })
   end

   local registry = {}

   function registry.resolve(symbol)
      local provider = providers[symbol]
      if not provider then
         return nil
      end
      return slots[symbol], provider
   end

   function registry.module(name)
      return public_modules[name]
   end

   function registry.providers()
      local copy = {}
      for symbol, provider in pairs(providers) do
         copy[symbol] = provider
      end
      return copy
   end

   return registry, host_environment
end

return contract
