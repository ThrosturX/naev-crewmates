local roster = {}

local function available(crew, count_away)
   return count_away or not crew.away
end

function roster.find_with_title(mem, title, count_away)
   for _, crew in ipairs(mem.companions) do
      if string.find(crew.typetitle:lower(), title:lower())
         and available(crew, count_away) then
         return crew
      end
   end
end

function roster.find_manager(mem, manager_type, count_away, commander_title)
   local candidate
   for _, crew in ipairs(mem.companions) do
      if crew.manager
         and string.find(crew.manager.type:lower(), manager_type:lower())
         and available(crew, count_away) then
         if string.find(crew.typetitle, commander_title) then
            return crew
         end
         candidate = crew
      end
   end
   return candidate
end

function roster.find_type(mem, title, count_away, commander_title, shuttle_title)
   for _, crew in ipairs(mem.companions) do
      if crew.typetitle:lower() == title:lower() and available(crew, count_away) then
         return crew
      end
   end

   if string.find(title, shuttle_title) then
      local manager = roster.find_manager(mem, shuttle_title, count_away, commander_title)
      return manager or roster.find_with_title(mem, commander_title)
   end
end

local function outfit_bay_strength(player)
   local bay_strength = 0
   for _, outfit in ipairs(player.pilot():outfitsList()) do
      -- External carrier plugins can install a passive structural bay instead
      -- of a launchable fighter bay. This tag expresses the same maximum Naev
      -- ship size in Crewmates' existing three-strength-points-per-size scale.
      if outfit:tags().crewmates_bay_size_2 then
         bay_strength = bay_strength + 6
      elseif string.find(outfit:nameRaw(), "Bay") then
         bay_strength = bay_strength + 2
      elseif string.find(outfit:nameRaw(), "Dock") then
         bay_strength = bay_strength + 1
      end
   end
   return bay_strength
end

function roster.ensure_bay_strength(mem, player)
   mem.ship_interior.bay_strength = math.max(
      mem.ship_interior.bay_strength or 0,
      outfit_bay_strength(player)
   )
end

function roster.calculate_bay_strength(mem, cargo_workers, player)
   local bay_strength = outfit_bay_strength(player)

   if bay_strength > 0 then
      mem.ship_interior.bay_strength = bay_strength + math.min(3.75, 0.34 * cargo_workers)
   else
      mem.ship_interior.bay_strength = 0
   end
end

return roster
