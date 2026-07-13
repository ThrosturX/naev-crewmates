local docking = {}

function docking.range(crewmate)
   local skill = 2 * (tonumber(crewmate.xp) or 0)
      + (tonumber(crewmate.satisfaction) or 0)
      + (tonumber(crewmate.bonus) or 0)
   return 350 + math.max(0, math.min(100, skill))
end

return docking
