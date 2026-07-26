--[[

   Crewmate Handler Event

   This event runs constantly in the background and manages crewmates
   hired from the bar, including generating NPCs at the bar and managing
   crewmate conversation and behavior in space.

   TODO NOTES:
 
   - Missing tutorials and info about the following:
	* the crew wants stuff like food and water, so ideally you keep a few tons of food in your cargo
	* opening crates has hidden fees (restocking fruit)
	* salaries are paid when you land and eventually crew salaries
		synchronize if you don't land for many jumps
	* only the hired crew members that fit on the ship are "active" and usable
		-> this doesn't apply to officers and champions (aka crew that can do stuff)
	* a first officer can shuffle crew members (actually just moves
		rookies and low cadets near the back)
	* some types are incompatible (the characters will complain about it)
	* some types have limits (the characters will complain about it)
	* some types need bays to function (you can't have a guy launch a
		shark from a shark, but if you have 2 hyena bays already, sure...)
	* some crew refuse to work with others, but you can hire them in
		"the wrong order" to force them to work together
	* some crew have the same function as another but at a different price,
		and the salary is dependent on stats when hired, which are trainable,
		so it's actually a good idea to hire cheap crew and train it
	* a first officer acts like a normal manager at a bar, it's not until you're out
		in the lawlessness of space and jurisdiction of your own ship that you can
		finally do cool things. Same for the smuggler.
	* speaking of which -- the first officer can do some cool stuff
		that isn't explained anywhere like rename crew or throw out of airlock
	
	More TODO:
	- Promotion path from lieutenant to officer
	- ship_interior.facilities {} that can something like:
		- botanical	- produces 1 food every 30 periods or something
		- training	- converts crew satisfaction to xp?
		- some kind of research facilities, maybe gives upgrades to sensors or something
		- specialized facilities that consume a commodity to achieve some effect (e.g. ore + diamond = 100 hp armor)
			-> these ones would be meant for mining ships, or ships that can at least access materials easily
--]]
local fmt = require "format"
local pilotname = require "crewmates.pilotname"
local vntk = require "vntk"
local vn = require "vn"
local lmisn = require "lmisn"
local graphics = require "love.graphics"
local prng = require "prng"
local config = require "crewmates.config"
local state = require "crewmates.state"
local roster = require "crewmates.roster"
local hooks = require "crewmates.hooks"
local interface = require "crewmates.interface"
local contract = require "crewmates.module_contract"

npcs = nil
logidstr = "log_shipcompanion"

textbox_font = vn.textbox_font -- for resetting (I know it's shadowed somewhere I might pick it out later)


-- this is a good place for easter eggs
FAKE_CAPTAIN = {
	["name"] = player.name(),
	["article_subject"] = _("the captain"),
	["article_object"] = _("the captain"),
	["firstname"] = player.name(),
	["chatter"] = rnd.rnd(),
	-- need a minimal conversation table to be able to pass the fake captain around and create memories as if it was a real character
	["conversation"] = {
		["good_talker"] = { "{name} is doing a good job." },
		["bad_talker"] = { "{name} stands out from the bunch." },
		["topics_liked"] = { [tostring(player.pilot():ship())] = {_("She's a beauty, isn't she?") } },
		["topics_disliked"] = { _("salary"), _("credits") },
	},
	["satisfaction"] = 0,
	["xp"] = 0,
	["subject"] = nil, -- "who I'm going to talk to in a conversation that didn't get any argument"
	["article_of_thought"] = player.pilot():ship():name(),
}
SHIP_OFFICERS = {}
SHIP_ENGINEERS = {}
LOADED = {}		-- characters that have been "vitalized", maps name to true (indices would get stale)
mothership = nil
joyride_commander = nil
state.initialize(mem, ship)
state.reset_runtime_hooks(mem)

-- default crew limits
START_CREW_LIMITS = config.crew_limits
SHIP_CREW_LIMITS = {}

-- hooks for special ability crew (champions)
entries = {
	["demoman"] = function(speaker)
		return hook.board("player_boarding_c4", speaker)
	end,
	["escort"] = function(speaker)
		return hook.land("escort_landing", "land", speaker)
	end,
	["smuggler"] = function(speaker)
		return hook.info("smuggler_cargobay", "cargo", speaker)
	end,
	["engihull"] = function(speaker)
		return hook.timer(config.hook_intervals.engihull, "engineer_armour", speaker)
	end,
	["engishld"] = function(speaker)
		return hook.timer(config.hook_intervals.engishld, "engineer_shield", speaker)
	end,
	["engipowr"] = function(speaker)
		return hook.timer(config.hook_intervals.engipowr, "engineer_power", speaker)
	end,
	["engichief"] = function(chief)
		return hook.timer(config.hook_intervals.engichief, "engineer_chief", chief)
	end,
	["command"] = function(officer)
		return hook.timer(config.hook_intervals.command, "commander_button", officer)
	end,
	["morale"] = function(officer)
		return hook.timer(config.hook_intervals.morale, "morale_officer", officer)
	end,
	["psychotherapy"] = function(officer)
		return hook.timer(config.hook_intervals.psychotherapy, "therapist_officer", officer)
	end,
	["passenger"] = function(passenger)
		return hook.land("passenger_landing", "land", passenger)
	end,
	["sanitation"] = function(officer)
		return hook.timer(config.hook_intervals.sanitation, "sanitation_officer_cleaning", officer)
	end,
	["hydroponics"] = function(scientist)
		return hook.timer(config.hook_intervals.hydroponics, "hydroponics_farm", scientist)
	end,
	-- TODO HERE: Metallurgy and some other science stuff
	["commandAux"] = function(officer)
		return hook.timer(config.hook_intervals.commandAux, "commander_button_aux", officer)
	end,
}

-- prices of things we charge for that aren't commodities
prices = config.prices

-- gets any present officer, preferring the one currently commanding a joyride mothership
-- prefers officers with shuttles
function getCommander()
	if joyride_commander then
		return joyride_commander
	end
	local candidate
	for _i, worker in ipairs(mem.companions) do
		if
			not candidate
			and string.find(worker.skill, _("Officer"))
			and string.find(worker.typetitle, _("Command"))
			and not worker.away
		then
			candidate = worker -- could be this guy unless we find a better candidate
		end
		if	-- this is the preferred commander
			(
				string.find(worker.skill, _("First Officer"))
				or string.find(worker.skill, _("Pirate Leader"))
			)
			and not worker.away
		then
			return worker -- definitely this guy if we found him
		end
		
		-- it's probably this guy, has command management and owns a shuttle
		if
			worker.shuttle
			and string.find(worker.typetitle, _("Commander"))
			and worker.manager.type == _("Command")
			and not worker.away
		then
			candidate = worker
		end
		
		-- it's probably this guy if we didn't pick out a commander yet
		if	-- we haven't found a commander but we found an officer
			(not candidate or not string.find(candidate.typetitle, _("Commander")))
			and worker.pilot and worker.pilot:exists()
			and string.find(worker.skill, _("Officer"))
			and not worker.away
		then
			candidate = worker
		end
		
	end
	
	return candidate
end

-- transmits a message to the "internal ship comm" if it's open
function _comm(speaker, message)
	if mothership == player.ship() then
		pilot.comm(speaker, message)
	else
		-- ugh, we need to find the commander that's piloting our ship
		for _i, worker in ipairs(mem.companions) do
			-- it's probably this guy
			if worker.pilot and worker.manager	and worker.pilot:exists() then
				print(fmt.f("intercepted comm from {name}: <{msg}>", {name = speaker, msg = message } ))
				local name = worker.pilot:name()
				worker.pilot:rename(speaker)
				worker.pilot:comm(message)
				worker.pilot:rename(name)
				return
			end
		end
	end
end

function playMoney()
	lmisn.sfxMoney()
end

function shaderimage2canvas( shader, image, w, h, sx, sy )
   sx = sx or 1
   sy = sy or sx
   -- Render to image
   local newcanvas = graphics.newCanvas( w, h )
   local oldcanvas = graphics.getCanvas()
   local oldshader = graphics.getShader()
   graphics.setCanvas( newcanvas )
   graphics.clear( 0, 0, 0, 0 )
   graphics.setShader( shader )
   graphics.setColor( 1, 1, 1, 1 )
   image:draw( 0, 0, 0, sx, sy )
   graphics.setShader( oldshader )
   graphics.setCanvas( oldcanvas )

   return newcanvas
end

-- merges (overwrites) a template table t1 with data from t2
function merge_tables(t1, t2)
	for k, v in pairs(t2) do
		t1[k] = v
	end

	return t1
end


SHIP_CREW_LIMITS = merge_tables({}, START_CREW_LIMITS)

-- appends t2 to the back of t1
function append_table(t1, t2)
	for _i, v in ipairs(t2) do
		table.insert(t1, v)
	end

	return t1
end

-- creates a copy of t1 and t2 joined together
function join_tables(t1, t2)
	local copy = {}
	for _i, v in ipairs(t1) do
		table.insert(copy, v)
	end
	for _i, v in ipairs(t2) do
		table.insert(copy, v)
	end

	return copy
end

-- merges t2 and its subtables into t1 and its subtables
function full_merge(t1, t2)
	for k,v in pairs(t2) do
		if not t1[k] then t1[k] = {} end
		if type(v) == table then
			t1[k] = full_merge(t1[k], v)
		else
			table.insert(t1, v)
		end
	end
	
	return t1
end

-- pick a random item from the collection
function pick_one(target)
	local r = rnd.rnd(1, #target)
	return target[r]
end

-- for every item in target, roll a 6-die and discard if less than factor (or 3)
function pick_some(target, factor, rng)
	factor = factor or 3
	rng = rng or prng.new( rnd.rnd(0, 77777) )
	local some = {}
	for _i, thing in ipairs(target) do
		if rng:random(0, 6) >= factor then
			table.insert(some, thing)
		end
	end
	
	-- if we removed everything, we become savants instead
	if #some == 0 then
		return target
	end
	
	return some
end

-- pick a random key from a mapping
function pick_key(mapping)
	local keys = {}
	for key, _value in pairs(mapping) do
		table.insert(keys, key)
	end

	local chosen_key = pick_one(keys)

	return chosen_key
end

-- picks out a list nested in a table that uses keys instead of numeric indexing
-- used on the conversation object
-- e.g. in topic -> "faith"
-- or	 special -> "laugh"
function pick_map(maptable)
	-- as per example above, "pick the topic"
	local chosen_key = pick_key(maptable)
	-- pick out the list that we can choose from
	local chosen_value = maptable[chosen_key]
	return chosen_value
end

-- picks one element out of a list that is nested inside a table
-- used on the conversation object
-- e.g. in topic -> "faith" -> picks one of phrases
-- or	 special -> "laugh" -> picks one of laughters
function pick_from_map(maptable)
	-- pick one out of the chosen list
	local choices = pick_map(maptable)
	return pick_one(choices)
end

-- pick a random letter out of a string
function pick_str(str)
	local ii = rnd.rnd(1, str:len()) -- pick a random index from string length
	return string.sub(str, ii, ii) -- returns letter at ii
end

-- pick a random word out of a string
function pick_word(str)
	local words = {}
	for word in str:gmatch("%w+") do
		table.insert(words, word)
	end
	return pick_one(words)
end

-- sanitize a phrase before it gets compared with a lot of words
function sanitize_phrase(phrase)
	-- blacklist some very basic and common words for the random word picker
	local blacklist = {
		_("a"),
		_("is"),
		_("was"),
		_("I"),
		_("quite"),
		_("nice"),
		_("your"),
		_("that"),
		_("this"),
		_("my"),
		_("his"),
		_("her"),
		_("about"),
		_("to"),
		_("the"),
		_("their"),
		_("yes"),
		_("no")
	}
	local result
	for word in phrase:gmatch("%w+") do
		local keep = true
		for _i, banned in ipairs(blacklist) do
			if word == banned then
				keep = false
			end
		end
		if keep then
			if result then
				result = result .. " " .. word
			else
				result = word
			end
		end
	end

	if not result then result = "" end
	
	return result
end

-- returns something that looks like the subject
-- or a random word from the phrase
function extract_keyword(phrase)	
	-- let's just be lazy and find some articles without even checking the casing
	-- who knows how this gets lost in translation, but the idea is:
	-- find the subject of the phrase or an important key word
	local articles = {
		_("your"),
		_("that"),
		_("this"),
		_("my"),
		_("his"),
		_("her"),
		_("about"),
		_("to"),
		_("the"),
		_("their"),
	}

	for _, article in ipairs(articles) do
		local match = string.match(phrase, " " ..article .. " ([a-zA-Z]+)")
		if match then
			-- since we're being lazy and inefficient... we could check if it's an adjective and go one word further...
--			print("found match", match, phrase)
			return match
		end
	end
	
--	print("found no match in", phrase)

	return pick_word(sanitize_phrase(phrase))
end

-- parses a commodity from request
-- TODO: get better, search in nearby systems etc
function parseCommodity( request )
	-- right now we only understand standard commodities	
	if not request then return nil end
	local rlower = request:lower()
	for _i, standard in ipairs(commodity.getStandard()) do
		if string.find(rlower, standard:name():lower()) then
			return standard
		end
	end
	
	return nil -- nothing found
end

-- returns the outfit if it exists or nil
function getShuttleOutfit(requested)
	if not requested then return nil end
	requested = requested:lower()
	local candidate
	for _, oo in ipairs(outfit.getAll()) do
		if string.find(oo:nameRaw():lower(), requested) then
			if
				-- fit the one with the shorter name, so if the player types
				-- "Ion Cannon", don't try to fit a "Heavy Ion Cannon"
				not candidate
				or (
					oo:nameRaw():len() < candidate:nameRaw():len()
				)
			then
				candidate = oo
			end
		end
	end
	
	-- make sure we can allow the player to fit this (must own one)
	if candidate and player.outfitNum(candidate:name(), true) < 1 then
		return nil
	else -- we take one from the player's stock? but we already charge for it...
		-- player.outfitRm(candidate:name(), 1) -- let's not
	end
	
	return candidate
end

-- gives the crewmate a little personality trim
function pruneCrewMate( crewmate )
	-- clear preferences, we don't use these anymore!
	crewmate.preferences = nil
	if crewmate.manager then
		crewmate.manager.lines = nil
	end
	
	-- clear topics in case they linger
	crewmate.conversation.topics_liked = nil
	crewmate.conversation.topics_disliked = nil
	
	-- forget old habits
	if not crewmate.memories then
		crewmate.memories = {}
	end
	if crewmate.memories.fatigue then
		crewmate.memories.fatigue = pick_some(crewmate.memories.fatigue, 5)
	end
	-- clear away some thoughts
	if crewmate.conversation.sentiments then
		crewmate.conversation.sentiments = pick_some(crewmate.conversation.sentiments, 5)
		table.insert(crewmate.conversation.sentiments, _("I feel so refreshed."))
	end
	print(crewmate.name .. " got pruned.")
end

promotions = {
	[_("Rookie")] = _("Cadet"),
	[_("Cadet")] = _("Ensign"),
	[_("Ensign")] = _("Lieutenant"),
}

-- gets a "skill" promotion (not a title promotion like promoting to officer status)
function get_promotion( crewmate )
	if
		string.find(crewmate.skill, _("Security"))
		or string.find(crewmate.skill, _("Janitor"))
		or string.find(crewmate.skill, _("Sanitation"))
		or string.find(crewmate.skill, _("Pirate"))
	then -- these don't get automatically promoted
		return nil
	end
	local promotion
	if
		crewmate.xp >= 100
		and (
			crewmate.typetitle == _("Crew")
			or crewmate.typetitle == _("Pilot")
		)			
		and not string.find(crewmate.skill, _("Lieutenant"))
		and not string.find(crewmate.skill, _("Officer"))
		and not string.find(crewmate.skill, _("Chief"))
	then
		promotion = promotions[crewmate.skill] or _("Cadet")
	end
	
	return promotion
end

-- sends the officer (on the bridge) on a break
-- might not come back until the player lands though?
function crew_take_break(officer, command)
	local break_time
	if command and command:len() > 0 then
		break_time = command:match("%d+")
	end
	break_time = break_time or 48 * player.pilot():ship():size()
	
	officer.away = { mission = _("break") }
	
	hook.timer(break_time, "crew_return_from_break", officer)
	print("taking break: " .. officer.name)
end

function crew_return_from_break( crewman )
	print("back from break: " .. crewman.name)
	crewman.away = nil
end

-- remove the direct uplink to the commander on deck
function clearCommanderInterface()
	interface.clear(mem)
end

-- add a commander on deck, to the bridge and ready to communicate with the captain
function addCommanderInterface()
	interface.add(mem, startCommandDiscussion)
end

-- pun slightly intended, we shift crew members around when organizing roster so these guys are "on shift"...
SHIFT_DUTY = {}

function loadCrewmate(index)
	local cmate = mem.companions[index]
	if not cmate then
		return nil
	end
	getTopics(cmate)
	getConversation(cmate)
	LOADED[cmate.name] = true
	if not cmate.away and #SHIFT_DUTY < player.pilot():stats().crew / 2 then
		table.insert(SHIFT_DUTY, cmate)
	end
end

-- loads 5 crewmates onto "the shift", or picks a random loaded crewmate from the shift
function loadOnShift()
	if #mem.companions == 0 then
		return nil
	end

	local min_loads = 5
	local loads = 0
	if #SHIFT_DUTY < min_loads then
		for ii, _worker in ipairs(mem.companions) do
			if loads < min_loads then
				loadCrewmate(ii)
				loads = loads + 1
			end
		end
	end

	if #SHIFT_DUTY == 0 then
		return nil
	end

	return pick_one(SHIFT_DUTY)
end

-- checks what crewmates are actually on board and returns one of them or nil if none found
function getCrewmateOnboard( on_shift )
	if #mem.companions == 0 then
		return nil
	end

	if on_shift then
		return loadOnShift()
	end

	-- Keep physically absent mission crew at the back of the ordered roster.
	-- Crew on a break have an away record without a ship and remain aboard.
	local present = {}
	local off_ship = {}
	for _, worker in ipairs(mem.companions) do
		if worker.away and worker.away.ship then
			off_ship[#off_ship + 1] = worker
		else
			present[#present + 1] = worker
		end
	end
	if #off_ship > 0 then
		for index, worker in ipairs(present) do
			mem.companions[index] = worker
		end
		for index, worker in ipairs(off_ship) do
			mem.companions[#present + index] = worker
		end
	end

	local capacity = math.min(#present, player.pilot():stats()["crew"])
	if capacity <= 0 then
		return nil
	end

	local onboard = {}
	local loaded = {}
	for index = 1, capacity do
		local worker = mem.companions[index]
		local entry = { crew = worker, index = index }
		onboard[#onboard + 1] = entry
		if LOADED[worker.name] then
			loaded[#loaded + 1] = entry
		end
	end

	-- Prefer an already-vitalized crewmate, but load a present candidate when
	-- none of the eligible crew has been loaded yet.
	local pool = #loaded > 0 and loaded or onboard
	local selected = pick_one(pool)
	local candidate = selected.crew
	if not LOADED[candidate.name] then
		loadCrewmate(selected.index)
	else
		local already_on_shift = false
		for _, crew in ipairs(SHIFT_DUTY) do
			if crew == candidate then
				already_on_shift = true
				break
			end
		end
		if not already_on_shift and not candidate.away then
			table.insert(SHIFT_DUTY, candidate)
		end
	end

	return candidate
end

return contract.capture {
	name = "context",
	requires = { "content.character", "management_discussions" },
	exports = {
		"npcs", "logidstr", "textbox_font", "FAKE_CAPTAIN", "SHIP_OFFICERS",
		"SHIP_ENGINEERS", "LOADED", "mothership", "joyride_commander",
		"START_CREW_LIMITS", "SHIP_CREW_LIMITS", "entries", "prices",
		"getCommander", "_comm", "playMoney", "shaderimage2canvas",
		"merge_tables", "append_table", "join_tables", "full_merge",
		"pick_one", "pick_some", "pick_key", "pick_map", "pick_from_map",
		"pick_str", "pick_word", "sanitize_phrase", "extract_keyword",
		"parseCommodity", "getShuttleOutfit", "pruneCrewMate", "promotions",
		"get_promotion", "crew_take_break", "crew_return_from_break",
		"clearCommanderInterface", "addCommanderInterface", "SHIFT_DUTY",
		"loadCrewmate", "loadOnShift", "getCrewmateOnboard",
	},
}
