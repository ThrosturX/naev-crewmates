local service = {}

local function contains(value, fragment)
   return type(value) == "string"
      and value:lower():find(fragment:lower(), 1, true) ~= nil
end

local function ship_name(value)
   if type(value) == "string" then
      return value
   end
   if value and type(value.nameRaw) == "function" then
      return value:nameRaw()
   end
end

function service.is_eligible(crewmember, requirement, commander_title)
   if type(crewmember) ~= "table" or crewmember.away then
      return false
   end
   if not contains(crewmember.typetitle, commander_title) then
      return false
   end
   local shuttle = requirement and requirement.shuttle
   return not shuttle
      or (crewmember.shuttle and ship_name(crewmember.shuttle.ship) == shuttle)
end

function service.find(mem, requirement, commander_title, excluded)
   for _, crewmember in ipairs(mem.companions or {}) do
      if crewmember ~= excluded
         and service.is_eligible(crewmember, requirement, commander_title) then
         return crewmember
      end
   end
end

function service.prepare(crewmember, requirement, ship_api)
   if requirement.shuttle then
      local current = crewmember.shuttle and ship_name(crewmember.shuttle.ship)
      if current ~= requirement.shuttle then
         crewmember.shuttle = { ship = ship_api.get(requirement.shuttle) }
      end
   end
   return crewmember
end

function service.ensure(mem, requirement, commander_title, create_commander, ship_api, select_commander)
   local relaxed = { minimum = requirement.minimum }
   local commander = select_commander and select_commander() or nil
   if not service.is_eligible(commander, relaxed, commander_title) then
      commander = service.find(mem, relaxed, commander_title)
   end
   local created = false
   if not commander then
      commander = create_commander()
      mem.companions[#mem.companions + 1] = commander
      created = true
   end
   service.prepare(commander, requirement, ship_api)
   if commander.shuttle then
      mem.ship_interior.shuttle = commander.shuttle
   end
   return commander, created
end

function service.can_dismiss(mem, requirements, crewmember, replacement, commander_title)
   for client, requirement in pairs(requirements) do
      if service.is_eligible(crewmember, requirement, commander_title) then
         local count = 0
         for _, current in ipairs(mem.companions or {}) do
            if current ~= crewmember
               and service.is_eligible(current, requirement, commander_title) then
               count = count + 1
            end
         end
         if replacement
            and replacement ~= crewmember
            and service.is_eligible(replacement, requirement, commander_title) then
            local already_present = false
            for _, current in ipairs(mem.companions or {}) do
               if current == replacement then
                  already_present = true
                  break
               end
            end
            if not already_present then
               count = count + 1
            end
         end
         if count < requirement.minimum then
            return false, client, requirement
         end
      end
   end
   return true
end

return service
