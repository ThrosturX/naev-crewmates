local lifecycle = {}

function lifecycle.disband(mem, crewmember, reason, player, logidstr)
   mem.ship_interior.dirt = mem.ship_interior.dirt
      + crewmember.xp * player.pilot():ship():size() * 0.1

   for index, crew in ipairs(mem.companions) do
      if crewmember == crew then
         if crewmember.hook then
            hook.rm(crewmember.hook.hook)
         end
         mem.companions[index] = mem.companions[#mem.companions]
         mem.companions[#mem.companions] = nil
         break
      end
   end

   shiplog.append(logidstr, reason)
end

function lifecycle.terminate(mem, npcs, crewmember, reason, player, logidstr)
   lifecycle.disband(mem, crewmember, reason, player, logidstr)
   if npcs and player.isLanded() then
      for id, data in pairs(npcs) do
         if crewmember == data then
            evt.npcRm(id)
            npcs[id] = nil
         end
      end
   end
end

return lifecycle
