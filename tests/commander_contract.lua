package.path = 'scripts/?.lua;scripts/?/init.lua;' .. package.path

local service = require 'crewmates.commander_service'
local alpaca = { nameRaw = function() return 'Alpaca' end }
local ship_api = { get = function(name)
   assert(name == 'Alpaca', 'the contract must request its guaranteed shuttle')
   return alpaca
end }
local requirement = { minimum = 1, shuttle = 'Alpaca' }
local mem = { companions = {}, ship_interior = {} }
local created = 0
local commander = service.ensure(mem, requirement, 'Commander', function()
   created = created + 1
   return { name = 'Casey', typetitle = 'Commander', shuttle = { ship = 'Hyena' } }
end, ship_api)

assert(created == 1 and mem.companions[1] == commander,
   'ensuring must create a missing commander')
assert(commander.shuttle.ship == alpaca and mem.ship_interior.shuttle == commander.shuttle,
   'ensuring must report the commander Alpaca as the shared shuttle')

local requirements = { nomad = requirement }
local allowed, client = service.can_dismiss(
   mem, requirements, commander, nil, 'Commander')
assert(not allowed and client == 'nomad',
   'the last required commander must be protected')

local replacement = {
   name = 'Morgan', typetitle = 'Commander', shuttle = { ship = alpaca },
}
allowed = service.can_dismiss(
   mem, requirements, commander, replacement, 'Commander')
assert(allowed, 'an eligible atomic replacement must permit dismissal')

mem.companions[#mem.companions + 1] = replacement
allowed = service.can_dismiss(
   mem, requirements, commander, replacement, 'Commander')
assert(allowed, 'a selected replacement already in the roster must count once')

replacement.away = true
allowed = service.can_dismiss(
   mem, requirements, commander, replacement, 'Commander')
assert(not allowed, 'an away commander cannot satisfy mothership control')

print('ok - public commander contract')
