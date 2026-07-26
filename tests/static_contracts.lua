local files = {
   'scripts/crewmates/context.lua',
   'scripts/crewmates/content/random.lua',
   'scripts/crewmates/content/character.lua',
   'scripts/crewmates/memory.lua',
   'scripts/crewmates/conversation_runtime.lua',
   'scripts/crewmates/crew_factory.lua',
   'scripts/crewmates/crew_factory_officers.lua',
   'scripts/crewmates/integration.lua',
   'scripts/crewmates/crew_factory_npcs.lua',
   'scripts/crewmates/simulation.lua',
   'scripts/crewmates/management.lua',
   'scripts/crewmates/management_discussions.lua',
   'scripts/crewmates/management_ui.lua',
   'scripts/crewmates/shuttle.lua',
   'scripts/crewmates/missions/away.lua',
   'scripts/crewmates/abilities/engineers.lua',
}

local function read(path)
   local handle = assert(io.open(path, 'r'))
   local contents = handle:read('*a')
   handle:close()
   return contents
end

local modules = {}
local providers = {}

local away_source = read('scripts/crewmates/missions/away.lua')
assert(not away_source:find('cargo.name', 1, true),
   'cargoList entries expose Commodity objects as cargo.c')
assert(not away_source:find('v.name', 1, true),
   'cargoList entries expose Commodity objects as v.c')
assert(away_source:find('cargoAdd( cargo.c, cargo.q )', 1, true),
   'returning shuttles must transfer their Commodity objects')

local context_source = read('scripts/crewmates/context.lua')
assert(not context_source:find('snd/sounds/jingles/money', 1, true),
   'money sounds must use Naev helpers instead of asset paths')

local factory_source = read('scripts/crewmates/crew_factory.lua')
assert(not factory_source:find('spob.get(faction.get', 1, true),
   'backstory origins must use the nil-safe faction spob lookup')
assert(not factory_source:find('spob.get(', 1, true),
   'backstory generation must never construct nullable spob handles')

local runtime_source = read('scripts/crewmates/runtime.lua')
assert(runtime_source:find('shuttle_manager = commander', 1, true),
   'public command launch must persist loadouts on the registered commander')

local interface_source = read('scripts/crewmates/interface.lua')
assert(not interface_source:find("hook.input('hail_hook')", 1, true),
   'commander UI must not claim the global no-target hail input')

local conversation_source = read('scripts/crewmates/conversation_runtime.lua')
assert(not conversation_source:find('skipping speech', 1, true),
   'ambient crewmate speech must not be hard-disabled')
assert(not conversation_source:find('analysis.quesiton', 1, true),
   'conversation question classification must use analysis.question')
assert(not conversation_source:find('local liked, disliked = getTopics', 1, true),
   'getTopics returns one wrapper table, not two values')

local character_source = read('scripts/crewmates/content/character.lua')
assert(character_source:find('["disliked"] = NOTALK[character.name]', 1, true),
   "topic lookup must return the current crewmate's disliked-topic map")
assert(not character_source:find('merge_tables(memories, TOPICS[character.name])', 1, true),
   'topic lookup must not overwrite memories with generic topics')
assert(character_source:find('if character.skill then', 1, true),
   'synthetic conversation participants must not require a crew skill')

local memory_source = read('scripts/crewmates/memory.lua')
assert(memory_source:find('LOADED[character.name]', 1, true),
   'loaded-crewmate checks must use the name-keyed runtime cache')
assert(not memory_source:find('pick_one(topics.disliked)', 1, true),
   'disliked topics are a map and must be selected by key')

local context_source_for_roster = read('scripts/crewmates/context.lua')
assert(context_source_for_roster:find('worker.away and worker.away.ship', 1, true),
   'only crew physically away from the ship must be excluded from conversation')
local load_crewmate_body = assert(
   context_source_for_roster:match('function loadCrewmate%b()%s*(.-)%s*end%s*%-%- loads'),
   'loadCrewmate implementation must remain discoverable')
assert(load_crewmate_body:find('not cmate.away', 1, true),
   'duty-only selection must exclude every crewmate with an away record')

local hooks_source = read('scripts/crewmates/hooks.lua')
assert(hooks_source:find('crew_takeoff_hook = hook.load("takeoff")', 1, true),
   'loading a save must reconstruct takeoff state')
assert(hooks_source:find('hook.takeoff("takeoff")', 1, true),
   'actual takeoff events must retain their takeoff hook')

local simulation_source = read('scripts/crewmates/simulation.lua')
local recalculation_name = 'recalculate_ship_crew_state'
local takeoff_body = assert(
   simulation_source:match('function takeoff%b()%s*(.-)%s*end%s*function land'),
   'takeoff implementation must remain discoverable')
local fatigue_body = assert(
   simulation_source:match('function period_fatigue%b()%s*(.-)%s*end%s*return contract'),
   'period_fatigue implementation must remain discoverable')
assert(takeoff_body:find(recalculation_name .. '()', 1, true),
   'takeoff must rebuild crew-derived ship state')
assert(fatigue_body:find(recalculation_name .. '()', 1, true),
   'periodic fatigue must refresh crew-derived ship state')
assert(not fatigue_body:find('takeoff()', 1, true),
   'periodic fatigue must not invoke the takeoff lifecycle')
local reset_index = assert(simulation_source:find('intrinsicReset()', 1, true))
local sanitation_index = assert(simulation_source:find('local sanitation_officer', 1, true))
assert(reset_index < sanitation_index,
   'intrinsics must reset before sanitation and security bonuses are applied')


local management_ui_source = read('scripts/crewmates/management_ui.lua')
assert(not management_ui_source:find('edata.conversation.good_talker', 1, true),
   'bar dialogue must read inherited lines through getConversation')

local engineers_source = read('scripts/crewmates/abilities/engineers.lua')
assert(not engineers_source:find('math.max(100, engineer.xp + 0.01)', 1, true),
   'engineer experience gains must clamp to, not jump to, 100')
assert(not engineers_source:find('print("power engineer!")', 1, true),
   'frequent engineer polling must not emit unconditional debug output')

local guardian_source = read('ai/escort_guardian.lua')
assert(not guardian_source:find('ai.shoot()', 1, true)
   and guardian_source:find('ai.weapset( 1, true )', 1, true)
   and guardian_source:find('ai.weapset( 2, true )', 1, true),
   'guardian AI must fire through supported weapon-set controls')

for _file_index, path in ipairs(files) do
   local source = read(path)
   local capture = assert(source:match('return%s+contract%.capture%s*(%b{})'),
      path .. ' has no module contract')
   local name = assert(capture:match('name%s*=%s*"([^"]+)"'), path .. ' has no module name')
   local requires = {}
   local requires_block = capture:match('requires%s*=%s*(%b{})') or '{}'
   for dependency in requires_block:gmatch('"([^"]+)"') do
      requires[dependency] = true
   end
   local exports_block = assert(capture:match('exports%s*=%s*(%b{})'), path .. ' has no exports')
   local exports = {}
   for symbol in exports_block:gmatch('"([^"]+)"') do
      assert(not providers[symbol], symbol .. ' has multiple providers')
      providers[symbol] = name
      exports[symbol] = true
   end
   modules[path] = { name = name, requires = requires, exports = exports }
end

local checked = 0
for _file_index, path in ipairs(files) do
   local module = modules[path]
   local command = string.format(
      "luacheck %q --codes --no-color --formatter plain 2>&1",
      path
   )
   local output = assert(io.popen(command)):read('*a')

   for code, symbol in output:gmatch('%((W11[123])%).-\'([^\']+)\'') do
      local provider = providers[symbol]
      if code == 'W111' then
         assert(provider, string.format('%s creates undeclared global %s', module.name, symbol))
      end
      if provider and provider ~= module.name then
         assert(module.requires[provider], string.format(
            '%s uses %s from %s without declaring the dependency',
            module.name, symbol, provider
         ))
         checked = checked + 1
      end
   end
end

print(('ok - %d static cross-module references'):format(checked))
