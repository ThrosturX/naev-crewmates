local shuttle_state = {}

local function persistent_shipvars(extra)
   local names = {
      bioship = true,
      bioship_init = true,
      bioshipexp = true,
      biostage = true,
   }
   local loaded, bioskills = pcall(require, "bioship.skills")
   if loaded and bioskills and bioskills.set then
      for _tree_name, tree in pairs(bioskills.set) do
         for skill_name in pairs(tree) do
            names["bio_" .. skill_name] = true
         end
      end
   end
   for _extra_index, name in ipairs(extra or {}) do
      names[name] = true
   end
   local result = {}
   for name in pairs(names) do
      result[#result + 1] = name
   end
   table.sort(result)
   return result
end

function shuttle_state.prepare_profile(profile, manager)
   profile.persist_virtual_state = true
   profile.shipvars = persistent_shipvars(profile.shipvars)
   profile.virtual_state = manager and manager.manager
      and manager.manager.virtual_state or nil
   return profile
end

function shuttle_state.record_return(manager, payload)
   if not payload or not payload.virtual_state
      or not manager or not manager.manager then return false end
   manager.manager.virtual_state = payload.virtual_state
   return true
end

return shuttle_state
