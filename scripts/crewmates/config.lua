local config = {}

config.crew_limits = {
   [_('Commander')] = 1,
   [_('Officer')] = 1,
   [_('Medical Officer')] = 0,
   [_('Science Officer')] = -1,
   [_('Engineer')] = 1,
   [_('Sr. Engineer')] = 1,
   [_('Scientist')] = 1,
   [_('Security')] = 2,
   [_('Pirate')] = -2,
   [_('Specialist')] = 5,
   [_('Rookie')] = 4,
   [_('Cadet')] = 6,
   [_('Ensign')] = 8,
   [_('Lieutenant')] = 1,
   [_('Sr. Lieutenant')] = 3,
   [_('Pilot')] = -1,
   [_('Passenger')] = 5,
}

config.prices = {
   equipment = 15,
}

config.hook_intervals = {
   engihull = 80,
   engishld = 90,
   engipowr = 135,
   engichief = 166,
   command = 20,
   morale = 120,
   psychotherapy = 120,
   sanitation = 30,
   hydroponics = 60,
   commandAux = 99,
}

return config
