local hooks = {}

function hooks.create(mem)
   if not mem.crew_land_hook then
      mem.crew_land_hook = hook.land("land")
   end
   if not mem.crew_load_hook then
      mem.crew_load_hook = hook.load("land")
   end
   if not mem.crew_takeoff_hook then
      mem.crew_takeoff_hook = hook.load("takeoff")
   end
   if not mem.crew_enter_hook then
      mem.crew_enter_hook = hook.enter("enter")
   end
   if not mem.joyride_spawn_hook then
      mem.joyride_spawn_hook = hook.custom(
         "joyride_mothership_spawned", "joyride_mothership_spawned")
   end
   if not mem.joyride_end_hook then
      mem.joyride_end_hook = hook.custom("joyride_ended", "joyride_ended")
   end
   hook.takeoff("takeoff")
end

function hooks.repair(mem)
   hook.rm(mem.crew_land_hook)
   hook.rm(mem.crew_load_hook)
   hook.rm(mem.crew_takeoff_hook)
   hook.rm(mem.crew_enter_hook)
   hook.rm(mem.joyride_spawn_hook)
   hook.rm(mem.joyride_end_hook)

   mem.crew_enter_hook = hook.enter("enter")
   mem.crew_land_hook = hook.land("land")
   mem.crew_load_hook = hook.load("land")
   mem.crew_takeoff_hook = hook.load("takeoff")
   mem.joyride_spawn_hook = hook.custom(
      "joyride_mothership_spawned", "joyride_mothership_spawned")
   mem.joyride_end_hook = hook.custom("joyride_ended", "joyride_ended")
end

return hooks
