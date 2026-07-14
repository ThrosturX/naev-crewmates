local fmt = require "format"
local vntk = require "vntk"
local vn = require "vn"
local portrait = require "portrait"
local love_shaders = require "love_shaders"
local crew_lifecycle = require "crewmates.crew_lifecycle"
local roster = require "crewmates.roster"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function disband_crew(crewmember, reason)
	crew_lifecycle.disband(mem, crewmember, reason, player, logidstr)
end

function can_terminate_crew(crewmember, replacement)
	return canDismissRequiredCrew(crewmember, replacement)
end

-- delete the crew member permanently
function terminate_crew(crewmember, reason, options)
	options = options or {}
	if not options.force then
		local allowed, denial = can_terminate_crew(crewmember, options.replacement)
		if not allowed then
			return false, denial
		end
	end
	crew_lifecycle.terminate(mem, npcs, crewmember, reason, player, logidstr)
	return true
end

-- method to wrap terminate_crew for hooking death
function terminate_crew_death( dead, killer, args)
	print("terminate_crew_death " .. tostring(dead) .. tostring(killer) .. tostring(args.crewman.name))
	return terminate_crew(args.crewman, args.reason, { force = true })
end

-- generates a message that discusses some random interest of <crewmate>
function discussRandomTopic(crewmate)
	local my_topics = getTopics(crewmate)
	local topic = nil
	local last_topic = nil
	for ttt, _choices in pairs(my_topics.liked) do
		if not topic or rnd.rnd(0, 3) == 1 then
			topic = ttt
		end
		last_topic = ttt
	end
	local message
	if not topic then
		message = _("I got nothing to say to you.")
	else
		local choices = my_topics.liked[topic]
		message = pick_one(choices)
	end

	if not message then
		message = _("I don't know what to say.")
	end

	-- to make it more interesting, sometimes pick another thing to say as well
	if rnd.rnd(0, 2) == 0 then
		local sep = "\n"
		-- our last topic, which is probably going to be the one that's last in the list in this file that got chosen, will be preferred and more likely
		if rnd.rnd(0, 2) == 1 then
			last_topic = topic -- use the same topic again
			sep = " " -- don't always seperate with newline, it's the same topic for sure ihere so lets avoid it
		end
		local choices = my_topics.liked[last_topic]
		local other_message = pick_one(choices)
		-- don't say the exact same thing twice though
		if message ~= other_message then
			message = message .. sep .. other_message
		end
	end
	
	return fmt.f(message, crewmate)
end

-- starts a standard discussion with a crewmate (at the bar, unless the ship has a bridge UI where you can talk to your npcs)
-- this is definitely a place to be excessively wasteful and do computations we might not need if it increases the chance
-- of a more meaningful interaction. If we have to look every word typed by the player up in several tables, then that's what we'll do!
function startDiscussion(crewmate)
	if not crewmate then
		crewmate = FAKE_CAPTAIN.target or FAKE_CAPTAIN
		if crewmate == FAKE_CAPTAIN then
			crewmate.portrait = "unknown"
		end
	end
	if crewmate.away then
		vntk.msg(fmt.f(_([[{typetitle} {name}]]), crewmate), fmt.f(_([[{typetitle} {name} could not be summoned due to being on a ]]), crewmate) .. fmt.f(_([[{mission} in the {ship}.]]), crewmate.away))
		return
	end
	
	if not crewmate.portrait then
		print("CREWMATE HAS NO PORTRAIT", crewmate)
		print(crewmate.name)
		crewmate.portrait = "unknown"
	end
	
	local vn_params = { image = portrait.getFullPath(crewmate.portrait) }
	
	if mothership and mothership ~= player.ship() then
		vn_params.shader = love_shaders.hologram()
	end
	
	local name_label = fmt.f("{firstname} {name}", crewmate)
	vn.clear()
	vn.scene()
	local discusser = vn.newCharacter ( name_label, vn_params )
	vn.transition()
	local message
	local count = 0
	vn.label("start")
	vn.func( function() 
		-- just pick a random thing to say from our interests
		message = discussRandomTopic(crewmate)
	end )
	discusser( function () return message end )
	
	vn.label("reply")
	local title_choice = pick_one({
		_("What do you say back?"),
		_("Your response?"),
		_("Keep talking?"),
		_("Anything to add?"),
		
	})
	vn.func( function()
		local spoken = tk.input(_("Conversation"), 0, 64, title_choice)
		if spoken then
			local appreciation, understood = appreciate_spoken(spoken, crewmate)

			if not understood then
				-- we didn't even understand this, lets increase the chance of an appropriate response
				local responses = {
					_("Whatever."),
					_("Yeah, okay."),
					fmt.f(_("Okay, {name}."), {name = player.name()}),
					fmt.f(_("Aright, {name}."), {name = player.name()}),
					_("Sure."),
					_("Oh, really?"),
					_("Sorry?"),
					_("What?"),
					_("Huh?"),
					_("I'm a little hard of hearing."),
					_("Oh, sure."),
					_("I didn't quite catch that."),
					_("I'm afraid I don't really know what you're saying."),
					_("I'm afraid that I don't quite understand you."),
					_("I don't know."),
					_("Yeah... It is what it is."),
					_("Carpe diem!"),
					_("Let's check in with the others."),
					_("*sips drink*"),
					add_special(crewmate, "laugh"),
					add_special(crewmate),
					_("Sorry, are you talking to me?"),
					_("Sorry, can you repeat that?"),
					fmt.f(_("I'm sorry {name}, I wasn't listening."), {name = player.name()}),
					fmt.f(_("I'm sorry {name}, can you rephrase that?"), {name = player.name()}),
					_("Sometimes you just gotta... Yeah, I don't know, sorry, I wasn't really listening."),
					_("Sorry, I'm a bit distracted."),
					_(
						"Look, can we talk about something I'm actually knowledgable about? I feel like you're trying to set me up to look like a fool."
					),
					_("Yeah, I don't know much about that."),
					_("I don't know much about that."),
					_("I don't know anything about that."),
					_("I don't know anything about it."),
					_("I don't know what you're talking about."),
					_("I don't know what you're saying."),
					_("I'm not very knowledgable about those things."),
					_("I'm not very knowledgable about these things."),
					_("I'm not interested in that."),
					_("I never think about that."),
					_("What's gotten into you?"),
					_("Let's just grab a drink, shall we?"),
					_("How about we just forget about all this?"),
					_("You're not thinking of firing me, are you?"),
					_("What's going on? I'm so confused."),
					_("Sometimes I just don't understand you."),
					_("You can be difficult to understand sometimes.")
				}
		
				responses = join_tables(responses, appreciation)
				if crewmate.conversation.sentiments then
					-- a chance of changing the subject
					responses = join_tables(responses, crewmate.conversation.sentiments)
				else
					-- try to be a bit smarter than usual and enlist help from a function
					responses = join_tables(responses, generate_responses(spoken, crewmate))
				end

				if not spoken or spoken:len() == 0 then
					message = fmt.f(pick_one(responses), FAKE_CAPTAIN)
					vn.jump("end")
					return
				end
				
				-- finally, use our fancy analyzer to see if the player "scores" and can continue the conversation
				local response, detected = analyze_spoken(spoken, FAKE_CAPTAIN, crewmate)
				-- I don't know how many stack frames we can handle, but 10 sounds like a long conversation in case the player is trapped
				-- which I guess is kind of likely if the just keeps saying the same stuff
				if detected and (count < 10) then
					message = fmt.f(response, FAKE_CAPTAIN)
					count = count + 1
				-- count of 10 is very high, lets try 6
				elseif detected and count == 6 then
					message = fmt.f(response, FAKE_CAPTAIN)
					vn.jump("end")
					return
				else
					table.insert(responses, response)
					message = fmt.f(pick_one(responses), FAKE_CAPTAIN)
					-- we're not sure how to answer, so we are dismissive here
					vn.jump("end")
					return
				end
			else -- understood and "appreciated"
				message = fmt.f(pick_one(appreciation), FAKE_CAPTAIN)
			end
		else -- not spoken
			vn.jump("end")
		end
	end )
	
	discusser( function () return message end )
	vn.jump("start")
	
	vn.label("end")
	discusser(pick_one(getConversation(crewmate).default_participation))
	vn.done()
	vn.run()
end

-- this is the place to put custom management jobs, (one-off tasks)
function doSpecialManagementFunc(edata)
	local special = edata.manager.special
	
	if special.price then -- we have to charge for it
		player.pay(-special.price)
		playMoney()
		-- we charged the player, we earn xp
		edata.xp = edata.xp + 0.01
	end
	
	-- if we have a goodie crate
	if special.crate then
		-- distribute some fruit or something, everyone is a bit happier
		for _i, crewmate in ipairs(mem.companions) do
			-- simulate consuming one item now
			local enjoyment = evaluate_item_haste(crewmate, special.crate.fruit)
			if enjoyment > 0.75 then
				insert_sentiment(crewmate, fmt.f(_("That was a nice {fruit}."), special.crate))
			end
			crewmate.satisfaction = crewmate.satisfaction + enjoyment
				
			if	-- the crew member might take another one for later
				special.crate.comm
				and (not crewmate.item or enjoyment > 0.56)
			then
					give_item(crewmate, special.crate.fruit)
			end
		end
		-- if this is a lucky crate with a commodity, there's more fruit to pass around
		if special.crate.comm then
			player.pilot():cargoAdd(special.crate.comm, 1)

		end
		-- no reusing crates
		edata.manager.special = nil
	end
	-- TODO: other stuff
	
	if edata.manager.type == _("Shuttle") then
		print("we shuttle man")
		-- we are a shuttle manager, so we manage the shuttle "owned" by the ship
		-- unless we have our own shuttle
		local shuttle = edata.shuttle or mem.ship_interior.shuttle
		-- if we don't have a fitting, create one now
		local pppp = pilot.add(shuttle.ship, edata.faction)
		if edata.manager.outfits then
			-- perform a full refit
			pppp:outfitRm("all")
			-- add the favorite outfit
			if edata.manager.preferred_outfit then
				local fits = pppp:outfitAdd(edata.manager.preferred_outfit)
				print("adding favored:	" .. tostring(edata.manager.preferred_outfit))
				if not fits then print(" doesn't fit! " ) end
				-- don't keep adding these
				edata.manager.preferred_outfit = nil
			end
			-- add the old outfits
			for _j, o in ipairs(edata.manager.outfits) do
				local installed = pppp:outfitAdd(o)
				print("installing old outfit:  " .. tostring(o))
				if not installed then
					print("old outfit NOT installed:  " .. tostring(o))
				end
			end
		else
			edata.manager.outfits = {}
		end
		
		pppp:outfitRm("cores")
		
		-- try to fit these core modules
		if edata.manager.system then
			print("adding score " .. tostring(edata.manager.system))
			pppp:outfitAdd(edata.manager.system)
		end
		
		if edata.manager.engine then
		print("adding ecore " .. tostring(edata.manager.engine))
			pppp:outfitAdd(edata.manager.engine)
		end
		
		if edata.manager.hull then
			print("adding dcore " .. tostring(edata.manager.hull))
			pppp:outfitAdd(edata.manager.hull)
		end
		
		if pppp:spaceworthy() then		
			-- save the fitting, it's good
			edata.manager.outfits = {}
			print("final")
			for j, o in ipairs(pppp:outfitsList()) do
				edata.manager.outfits[#edata.manager.outfits + 1] = o:nameRaw()
				print(o)
			end
			print("saved a spaceworthy fitting")
		else
			edata.sentiment = _("I wonder if the captain will notice that I couldn't fit the shuttle to the requested specifications.")
			edata.satisfaction = edata.satisfaction - 0.08
			print("saved a garbage fitting:")
			for j, o in ipairs(pppp:outfitsList()) do
				print(o)
			end
			local _, reason = pppp:spaceworthy()
			print(reason)
		end
		pppp:rm()
		
		-- we did the thing
		edata.manager.special = nil
	end
	
	-- whatever we did, we probably made a small mess on the side
	mem.ship_interior.dirt = mem.ship_interior.dirt + 0.01
end

-- an officer (or maybe smuggler) converts a ton of food into a fruit crate
-- or if a requested argument was supplied, tries to construct that instead
function convertFoodToFruit(officer, requested)

	local create_custom = false
	local commodity_required = nil
	--[[ "cost" -- what is this variable? read on:
	Additional multiplier to a price constant (the item's string length)
	determines the "weight" of each character in the word of this kind for the price
	so for instance, all fruit costs the same, but "special items, requires water"
	will cost 75 credits per character in the item name, so "synthetic snakeskin applicator"
	would cost $2250 + the standard rate (starts at 200, otherwise 100 per crew member
	but reduced with a good officer).
	Additionally, if the cost is greater than or equal to 5, we label the discard button as "decorating"
	but anything that gets decorated or discarded is picked up by crew members that fancy it
	whether it's decorations or in the trash :) but at least we don't decorate ship with fruit or clothes
	--]]
	local cost = 1
	if requested then
		-- actually well thought out gifts, very expensive because requires effort
		for _i, item in ipairs(lang.nouns.gifts) do
			if
				not create_custom
				and string.find(requested, item)
			then
				create_custom = item
				cost = 375
			end
		end
	
		-- special items, requires water
		for _i, item in ipairs(lang.nouns.objects.random) do
			if
				not create_custom
				and string.find(requested, item)
			then
				create_custom = item
				commodity_required = "Water"
				cost = 75
			end
		end
	
		-- free items (cost only the payment of using the crate)
		for _i, item in ipairs(join_tables(lang.nouns.objects.items, lang.nouns.objects.tools)) do
			if
				not create_custom
				and string.find(requested, item)
			then
				create_custom = item
				cost = 5
			end
		end
		
		-- TODO: use textiles commodity when one exists
		for _i, item in ipairs(lang.nouns.objects.clothes) do
			if
				not create_custom
				and string.find(requested, item)
			then
				create_custom = item
				cost = 3
			end
		end
		
		-- requires luxury goods
		for _i, item in ipairs(lang.nouns.objects.accessories) do
			if
				not create_custom
				and string.find(requested, item)
			then
				create_custom = item
				commodity_required = "Luxury Goods"
				cost = 6
			end
		end

		
		-- requires food
		for _i, item in ipairs(join_tables(
				lang.getAll(lang.nouns.actors.animals),
				lang.getAll(lang.nouns.food)
			)
		) do
			if
				not create_custom
				and string.find(requested, item)
			then
				create_custom = item
				commodity_required = "Food"
				cost = 0
			end
		end

		if create_custom then
			-- first we check if our thing wants a noun descriptor
			-- (e.g. asked for "lion statue")
			-- because we can't create actors, but we can create actor items
			-- like animal book or warrior sword (or warrior's salad)
			
			local add = " "
			-- quick sanity check, if our thing is a food, we don't call it a lion banana, but a lion's banana
			-- this small detail makes the dialog seem much more realistic
			for _i, food in ipairs(lang.getAll(lang.nouns.food)) do
				if string.find(food, create_custom) then
					add = "'s "
				end
			end
			local all_actors = lang.getAll(lang.nouns.actors)
			local replacement
			for _i, actor in ipairs(all_actors) do
				if not string.find(create_custom, actor) and string.find(requested, actor) and (not replacement or actor:len() > replacement.want:len()) then
					replacement = { want = actor, find = create_custom, paste = actor .. add .. create_custom }
				end
			end
		
			-- now we check if we have to adorn the item with an adjective that isn't a part of the item name
			local all_adjectives = lang.getAll(lang.adjectives)
			table.sort(all_adjectives, function(a,b) return #a>#b end)
			for _i, adjective in ipairs(all_adjectives) do
				local bad_match = adjective:match(create_custom)
				if bad_match then
					-- special case like "ornamental peas"
					-- we don't want "ornamental ornaments"
					local new_noun
					for _i, cnoun in ipairs(join_tables(lang.getAll(lang.nouns.objects), lang.getAll(lang.nouns.food))) do
						if requested:find(cnoun) and not adjective:find(cnoun) then
							new_noun = cnoun
						end
					end
					if new_noun then
						create_custom = create_custom:gsub("%f[%a]" .. bad_match .. "%f[%A]", new_noun)
					end -- else sad
				end
				if not string.find(create_custom, adjective) and string.find(requested, adjective) then
					create_custom = adjective .. " " .. create_custom
					-- each adornment incurrs an additional cost
					cost = cost + 3
					if replacement and string.find(adjective, replacement.want) then
						-- we can't add this replacement, because of things like "ant" in "elegant"
						replacement = nil
					end
				end
			end
			
			-- now check if we want to do the replacement
			if replacement then
				create_custom = create_custom:gsub("%f[%a]" .. replacement.find .. "%f[%A]", replacement.paste)
				-- noun adornment incurrs an additional cost multiplier
				cost = cost * 2
			end
			
			-- finally... update the required commodity
			-- TODO: this is a placeholder
			if string.find(create_custom, "gold") then
				commodity_required = "Gold"
			end
		end
	end
	
	-- if we are capable of crafting the custom item, craft it, otherwise move on
	-- creating a custom item will throw out the old one!
	if create_custom
		and (
			not commodity_required
			or player.pilot():cargoHas(commodity_required) > 0
		)
	then
		if commodity_required then
			player.pilot():cargoRm(commodity_required, 1)
		end
		officer.manager.special = {}
		 -- TODO: Better conversation lines here, would do a lot for immersion
		officer.manager.special.feedback = pick_one(getConversation(officer).default_participation)
		
		-- Note: throwing out / decorating is the same thing, but the player doesn't know that
		-- also, the officer will pocket the first crafted thing before discarding/decorating
		-- so there is some hidden officer's greed, but you can bypass that by decorating more
		local discard_label = { _("Get rid of them"), "discard_special" }
		local alternate_use = pick_one({
			_("discard them."),
			_("take one for myself and throw out the rest."),
			_("get rid of them."),
			_("discard them. I might keep one for myself."),
			_("throw them out."),
			_("throw them away."),
			_("give them to the senior staff."),
			_("give some to the janitors."),
			fmt.f(_("give them to one of the {skill}s. They'll know what to do."), getCrewmateOnboard()),
			fmt.f(_("delegate the issue to {skill} {name}, {article_subject} seems to know a lot about "), getCrewmateOnboard()) .. create_custom .. "s.",
			fmt.f(_("have {firstname} figure out what to do with them."), getCrewmateOnboard()),
			_([["Misplace" them in the cargo bay.]]),
		})
		if cost >= 5 then
			discard_label = {
				fmt.f(
					_("Decorate {ship} with {item}s"), { ship = player.pilot():name(), item = create_custom }
				) , "discard_special"
			}
			alternate_use = _("use them to decorate the ship.")
		end
		
		officer.manager.special.choices = {
			{ _("Distribute among crew"), "special_yes" },
				discard_label, 
			{ _("Nevermind"), "end" }
		}
		
		-- we're specifically acquiring this item, so we pay up-front
		local price = math.max(200, 100 * #mem.companions - 50 * officer.bonus) + create_custom:len() * cost
		player.pay(-price)
		-- we still have to pay for distribution
		officer.manager.special.price = officer.manager.cost * 0.25
		local crate = {}
		crate.fruit = create_custom
		crate.origin = system.cur()
		officer.manager.special.crate = crate
		officer.manager.special.label = fmt.f(_("Distribute {fruit}s"), crate )
		-- we already crafted the item when we display this message
		officer.manager.special.message = _("You ") .. pick_one({
			_("commanded"),
			_("asked"),
			_("requested of"),
			_("ordered"),
			_("reminded"),
			_("demanded of"),
			_("expected of"),
			
		}) .. fmt.f(_(" me to procure some {fruit}s earlier. I can distribute them now to the crew if you'd like, or "), crate) .. alternate_use
		return true
	end
	
	-- we have something already, don't waste it now
	if officer.manager.special then return false end
	
	
	-- at this point it's safe to say we weren't ordered to craft anything that we can currently craft
	-- if we didn't have any fruit, see if we can convert a ton of food
	if player.pilot():cargoHas("Food") > 0 then
		player.pilot():cargoRm("Food", 1)
		officer.manager.special = {}
		officer.manager.special.feedback = pick_one(getConversation(officer).default_participation)
		officer.manager.special.choices = {
		{ _("Distribute among crew"), "special_yes" },
		{ _("Throw those out"), "discard_special" },
		{ _("Nevermind"), "end" }
		}
		officer.manager.special.price = math.max(200, 100 * #mem.companions - 50 * officer.bonus)
		local crate = {}
		crate.fruit = lang.getRandomFruit()
		-- 10% chance of converting the food into water instead of consuming it all
		if rnd.rnd(0, 10) == 0 then
			crate.comm = "Water"
		end
		crate.origin = system.cur()
		officer.manager.special.crate = crate
		officer.manager.special.label = fmt.f(_("Distribute {fruit}s"), crate )
		-- we already created the food now, so it's in the pantry and not the cargo bay
		officer.manager.special.message = fmt.f(_("I can distribute the {fruit}s from the foodstores in storage. Should I?"), crate)
		return true
	end
	
	return false
end

-- only search crew skill
function findCrewWithSkill ( skill, count_away )
	for _i, crew in ipairs(mem.companions) do
		if string.find(crew.skill:lower(), skill:lower()) and (count_away or not crew.away) then
			return crew
		end
	end
	
	return nil
end

-- only search crew title
function findCrewWithTitle(typetitle, count_away)
	return roster.find_with_title(mem, typetitle, count_away)
end

-- search managers, prioritize commanders
function findManagerOfType(mtype, count_away)
	return roster.find_manager(mem, mtype, count_away, _("Commander"))
end

-- currently just used to find shuttle managers and pilots
function findCrewOfType(typetitle, count_away)
	return roster.find_type(mem, typetitle, count_away, _("Commander"), _("Pilot"))
end

function listCrewReport( command )
	local response = ""
	for _i, worker in ipairs(mem.companions) do
		if 
			string.find(command, worker.typetitle:lower())
			or string.find(command, worker.skill:lower())
			or string.find(command, _("all"))
			or string.find(command, _("staff"))
		then
			response = response .. fmt.f("{xp: 4.0f} | {typetitle:17s} | {skill:18s} {name:16s},\t{firstname: 9s} \n", worker)
		else
		-- do a deeper search of this crew member, like if the player typed "list managers" or "list officer", we want all managers or crew with officer in the manager title
			local found = false
			for word in command:gmatch("%w+") do
				if
					not found and (
						string.find(worker.typetitle:lower(), word)
						or string.find(worker.skill:lower(), word)
					)
					and word ~= "list" -- the command
				then
					found = true
				elseif worker.manager and (
					string.find(worker.manager.type:lower(), word)
					or string.find(command, _("manager"))
					or (worker.manager.skill and string.find(worker.manager.skill:lower(), word))
					)
				then
					found = true
				end
			end
			if found then
				response = response .. fmt.f("{xp: 4.0f} | {typetitle:17s} | {skill:18s} {name:16s},\t{firstname: 9s} \n", worker)
			end
		end
	end
	
	return response
end

function salaryReport( command )
	local response = ""
	for _i, worker in ipairs(mem.companions) do
		if
			string.find(command, worker.typetitle:lower())
			or string.find(command, worker.skill:lower())
			or string.find(command, _("all"))
			or string.find(command, _("staff"))
		then
			response = response .. fmt.f("{xp: 4.0f} | {typetitle:17s} | {skill:18s} {name:16s},\t", worker) .. fmt.credits(worker.salary) .. "\n"
		else
		-- do a deeper search of this crew member, like if the player typed "salary managers" or "salary officer" or "salary medical", we want all managers or crew with officer in the manager title or medical anywhere
			local found = false
			for word in command:gmatch("%w+") do
				if not found and (
					string.find(worker.typetitle:lower(), word)
					or string.find(worker.skill:lower(), word)
					)
				then
					found = true
				elseif worker.manager and (
					string.find(worker.manager.type:lower(), word)
					or string.find(command, _("manager"))
					or (worker.manager.skill and string.find(worker.manager.skill:lower(), word))
					)
				then
					found = true
				end
			end
			if found then
				response = response .. fmt.f("{xp: 4.0f} | {typetitle:17s} | {skill:18s} {name:16s},\t", worker) .. fmt.credits(worker.salary) .. "\n"				end
		end
	end
	
	return response
end

-- returns whether or not the chosen shuttle can exit and dock with the player ship
function check_shuttle(chosen_shuttle)
	if chosen_shuttle.ship:size() <= math.floor(mem.ship_interior.bay_strength / 3) then
		return true
	end
	if chosen_shuttle.ship:nameRaw() == "Alpaca" and mem.ship_interior.bay_strength > 0 then
		return true
	end
	return false
end

-- NOTE: Any officer that can do a command discussion is going to have a shuttle bay requirement
-- if you don't have any bay_strength on the ship, those features should be disabled
-- (e.g. buy <commodity> from nearby spob or "command the ship while I take the shark for a quick spin")

return contract.capture {
	name = "management",
	requires = {
		"context", "content.character", "memory", "conversation_runtime",
		"integration",
	},
	exports = {
		"disband_crew", "can_terminate_crew", "terminate_crew", "terminate_crew_death",
		"discussRandomTopic", "startDiscussion", "doSpecialManagementFunc",
		"convertFoodToFruit", "findCrewWithSkill", "findCrewWithTitle",
		"findManagerOfType", "findCrewOfType", "listCrewReport", "salaryReport",
		"check_shuttle",
	},
}
