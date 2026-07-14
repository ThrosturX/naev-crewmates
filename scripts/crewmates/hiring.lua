local hiring = {}

-- A candidate can resolve several limits by replacing the same crewmate, but
-- hiring must never silently remove two incumbents to satisfy one offer.
function hiring.select_replacement(selected, incumbent, candidate, confirm)
   if selected == incumbent then
      return selected, true
   end
   if selected then
      return selected, false
   end
   if confirm(incumbent, candidate) then
      return incumbent, true
   end
   return nil, false
end

return hiring
