local interface = {}
local info_button

function interface.clear(mem)
   if info_button then
      player.infoButtonUnregister(info_button)
      info_button = nil
   end
   if mem.hail_hook then
      hook.rm(mem.hail_hook)
      mem.hail_hook = nil
   end
end

function interface.add(mem, start_command_discussion)
   interface.clear(mem)
   info_button = player.infoButtonRegister(_('Discuss Command'), start_command_discussion, 2, 'D')
end

return interface
