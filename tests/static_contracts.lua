local files = {
   'scripts/crewmates/context.lua',
   'scripts/crewmates/content/random.lua',
   'scripts/crewmates/content/character.lua',
   'scripts/crewmates/memory.lua',
   'scripts/crewmates/conversation_runtime.lua',
   'scripts/crewmates/crew_factory.lua',
   'scripts/crewmates/crew_factory_officers.lua',
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

for _, path in ipairs(files) do
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
for _, path in ipairs(files) do
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
