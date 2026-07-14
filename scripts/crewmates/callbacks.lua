local callbacks = {}

callbacks.names = {
   "create", "fixhooks", "takeoff", "land", "enter", "period_fatigue",
   "crew_return_from_break",
   "speak_notify", "say_specific", "start_conversation", "crewmate_use_item",
   "terminate_crew_death", "startDiscussion",
   "startCommandDiscussion", "startPromotionProcess",
   "startManagement", "crewmate_barConversation",
   "approachCompanion", "approachGenericCrewmate", "approachEscortCompanion",
   "approachDemolitionMan", "hydroponics_farm", "sanitation_officer_cleaning",
   "therapist_officer", "morale_officer", "passenger_landing", "escort_landing",
   "mission_idle_return_to_player", "mission_away_landed", "mission_away_return",
   "shuttle_check_dock_distance", "away_mission", "smuggler_cargobay",
   "engineer_chief", "engineer_shield", "engineer_power", "engineer_armour",
   "player_boarding_c4", "detonate_c4",
   "joyride_mothership_spawned", "joyride_shuttle_returned", "joyride_ended",
   "external_commander_ready",
   "player_swaps_to_shuttle", "hail_hook", "commander_button",
   "commander_button_aux",
}

function callbacks.install(registry, host_environment)
   assert(type(host_environment) == "table", "callbacks require a host environment")
   local installed = {}
   for _, name in ipairs(callbacks.names) do
      local implementation, provider = registry.resolve(name)
      assert(type(implementation) == "function", "missing Naev callback: " .. name)
      local callback = implementation
      rawset(host_environment, name, function(...)
         return callback(...)
      end)
      installed[name] = provider
   end
   return installed
end

return callbacks
