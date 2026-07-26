local fmt = require "format"
local vntk = require "vntk"
local vn = require "vn"
local portrait = require "portrait"
local love_shaders = require "love_shaders"
local graphics = require "love.graphics"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function startManagement(edata)
	if not edata then
		edata = FAKE_CAPTAIN.target or FAKE_CAPTAIN
	end
	if edata.away then
		vntk.msg(fmt.f(_([[{typetitle} {name}]]), edata), fmt.f(_([[{typetitle} {name} could not be summoned due to being on a ]]), edata) .. fmt.f(_([[{mission} in the {ship}.]]), edata.away))
		return
	end
	
	-- woah, we are a manager! lets do our manager thing
	local management = edata.manager
	local mlines = edata.manager.lines or getManagerLines( edata )

	-- if we can't afford our manager's services...
	if management.cost and player.credits() < management.cost then
		vntk.msg(
			fmt.f("{typetitle} {name}", edata),
			fmt.f(
				_(
					"You don't have the {credits} you owe me for previous management and assessment services. Maybe you should work on one problem at a time."
				),
				{credits = fmt.credits(management.cost)}
			)
		)
		return
	end
	
	local chat = { _("Chat"), "chat" }
	local summon = { _("Summon crew"), "summon" }
	local drinks = { _("Buy a round of drinks"), "drinks" }
	local dismiss = { _("Dismiss"), "end" }
	local upgrade_shuttle = { _("Shuttle Management"), "shuttle_management_intro" }
	
	local choices = {}
	if true then -- TODO: figure out if this character knows how to chat
		table.insert(choices, chat)
	end
	if management.type == _("Shuttle") then
		table.insert(choices, upgrade_shuttle)
	end

	-- see if this is an officer that wants to buy a shuttle
	local shuttle_candidate = nil
	
	if	-- control for what officers can buy shuttles (pilots can't own their own shuttles)
		(player.isLanded() and spob.cur():services().shipyard)	-- must have a shipyard
		and string.find(edata.typetitle, _("Commander"))		-- must be a commander (highest levels of officers)
		and (
			string.find(edata.skill, _("Officer"))				-- must be an officer (i.e. titled officer, mid-tier+)
			or string.find(edata.skill, _("Chief of Security")) -- or the security chief, he can have a shuttle too
		)
	then
		local sships = spob.cur():shipsSold()
		shuttle_candidate = pick_one(sships)
		-- if we picked an appropriate ship based on bay_strength:
		-- display it, otherwise, nevermind! dream on officer...
		if	player.credits() < shuttle_candidate:price() * 3			-- budget issue, officer is responsible
			or (edata.shuttle and edata.shuttle.ship == shuttle_candidate
					and not edata.shuttle.out)							-- already flying this
			or shuttle_candidate:size() > 3								-- too big for a private shuttle
			or shuttle_candidate:size() > math.floor(mem.ship_interior.bay_strength / 3)	-- doesn't fit in bays
			or shuttle_candidate:tags().bioship							-- can't fit these in space
		then
			print("candidate was", shuttle_candidate, shuttle_candidate:size())
			shuttle_candidate = nil
		end
	end
	if shuttle_candidate then
		local shuttle_label = fmt.f(_("Buy {ship} ({price})"), { ship = shuttle_candidate:name(), price = fmt.credits(shuttle_candidate:price()) })
		local buy_shuttle = {  shuttle_label, "buy_shuttle" }
		table.insert(choices, buy_shuttle)
	end
	
	-- if this manager has a usable or distributable special item
	if management.special then
		table.insert(choices, 
			{ management.special.label, "special" }
		)
	end
	
	-- buy the crew some drinks
	if management.cost > 0 then
		table.insert(choices, drinks)
	end

	-- summon the crew to the bar next time
	if not mem.summon_crew and management.cost > 0 then
		table.insert(choices, summon)
	end	
	
	-- always put the dismiss option last
	table.insert(choices, dismiss)

	-- default message in case we end up here without an appropriate management skill
	local message = _("How can I help you?")
	local textbox_font = vn.textbox_font
	local decoration -- something to get from an assessment

	if not string.find(edata.vncharacter, _("gfx")) then
		edata.vncharacter = portrait.getFullPath(edata.portrait)
	end
	
	local vn_params = {image = edata.vncharacter }
	if mothership and mothership ~= player.ship() then
		vn_params.shader = love_shaders.hologram()
	end
	
	-- open dialog part comes here
	vn.clear()
	vn.scene()
	print(fmt.f('{name} {portrait} {vncharacter} ', edata))
	print(fmt.f('params image {image}', vn_params))
	local escort = vn.newCharacter ( edata.name, vn_params )
	vn.transition()
	vn.label("start")
	
	-- figure out what kind of first message we want to give
	-- we are a personnel manager, let's give a personnel assessment
	vn.func( function()
		local key
		local troublemaker
		if string.find(management.type, _("Personnel")) then
			key, troublemaker = crewManagerAssessment()
			if not troublemaker then
				troublemaker = {}
			else -- I'm thinking about a "Cadet" or whatever
				edata.article_of_thought = troublemaker.skill
			end
			message = fmt.f(pick_one(mlines[key]), troublemaker)
		elseif string.find(management.type, _("Psych")) then
			if not decoration then	-- this is a very expensive assessment
				key, troublemaker, decoration = psychologicalAssessment()
				edata.article_of_thought = decoration -- this is on our mind now
			end
			if not troublemaker then
				message = fmt.f(_("I think the crew would appreciate it if you distributed some {article_of_thought}s."), edata)
			else
				message = fmt.f(pick_one(mlines[key]), troublemaker)
			end
		end
	end )
	-- maybe we are an unknown kind of manager, then nothing happens
	
	
	escort(function() return message end)
	vn.menu(function () return choices end) -- makes us jump to a label
	vn.done()
	-- talk with the escort about something
	vn.label("chat")
	local command
	-- TODO: call an approriate function?
	vn.func( function()
		message = _("I'm not sure how to help you.")
		local chatting = false
		local want_more = false
		-- we want to keep chatting as much as possible
		local spoken = tk.input(_("Management Discussion"), 0, 32, _("Say:"))
		if spoken then
			spoken = spoken:lower()
			-- for now, let's just do a basic personnel analysis in here to refactor later
			-- find a name from the input
			for _i, worker in ipairs(mem.companions) do
				if string.find(spoken, worker.name:lower()) 
				or string.find(spoken, worker.firstname:lower())
				then
					if string.find(spoken, _("sheet"))
						or string.find(spoken, _("info"))
						or string.find(spoken, _("detail"))
						or string.find(spoken, _("status"))
					then
						-- be a good manager and access the personnel files
						message = getCrewSheet(worker)
						vn.jump("crewsheet")
						return
					elseif string.find(management.type:lower(), _("psych")) then
						-- we can do psychological assessments about this person, let's do that
						worker.article_of_thought = findSuitableGift(worker) or _("credit chip")
						print(fmt.f("{name} wants a {article_of_thought}", worker))
						message = fmt.f(pick_one(mlines.specific), worker )
						if worker.typetitle == _("Passenger") then
							message = message .. "\n" .. fmt.f(pick_one(mlines.passenger), worker)
						end

						chatting = true
					else
						-- let's talk about this person
						message = fmt.f(pick_one(mlines.specific), worker)
						chatting = true
					end
				end
			end
			if
				string.find(spoken, _("salary"))
				and (
					( management.skill and string.find(management.skill, "payroll") )
					or string.find(management.type, _("Personnel"))
				)
			then
				chatting = true
				command = spoken
				vn.jump("salary")
				return
			elseif
				string.find(spoken, _("list"))
				and (
					string.find(management.type, _("Personnel"))
					or string.find(edata.skill, _("Officer"))
				)
			then
				chatting = true
				command = spoken
				vn.jump("list")
				return
			elseif not chatting then
				for _j, more in ipairs({
					_("more"),
					_("please"),
					_("what"),
					_("else"),
					_("anything"),
					_("crew"),
					_("doing"),
					_("satisf"),
					_("who"),
				}) do
					if string.find(spoken, more) then
						print(fmt.f("found {more}", {more=more}))
						vn.jump("start")
						want_more = true
						chatting = true
					end
				end
			end
		end
		vn.textbox_font = textbox_font

		if want_more then vn.jump("start") end
		if not spoken or not chatting then
			vn.jump("end")
		end
	end )
	
	
	-- reset the font before replying
	vn.func( function()
		vn.textbox_font = textbox_font
	end )
	escort( function() return message end )
	vn.jump("chat")
	vn.done()
	-- END SECTION CHAT
	
	-- player wants to find some crew types
	-- or find information about the crew
	vn.label("list")
	local response
	vn.func( function ()
		vn.textbox_font = graphics.newFont( _("fonts/D2CodingBold.ttf"), 15 )
		response = listCrewReport(command)
		if not string.find(response, "\n") then
			vn.textbox_font = textbox_font
			response = _("I know of no crew members matching that description.")
		end
	end )
	escort( function() return response end )
	
	vn.jump("chat")
	vn.done()
	-- player wants salary report
	vn.label("salary")
	local response
	vn.func( function ()
		vn.textbox_font = graphics.newFont( _("fonts/D2CodingBold.ttf"), 15 )
		response = salaryReport(command)
		if not string.find(response, "\n") then
			vn.textbox_font = textbox_font
			response = _("I know of no crew members matching that description.")
		end
	end )
	escort( function() return response end )

	vn.jump("chat")
	vn.done()
	
	-- BEGIN SECTION SHUTTLE MANAGER
	vn.label("shuttle_management_intro")
	escort( _([[So we're giving the old girl an overhaul?
Just tell me what you'd like me to change and I'll get everything ready for a refit job.
You'll be charged for the parts immediately, but you won't be charged for the work until we get to it.]]) )
	vn.label("shuttle_management")

	local shuttle_choices = {
		{ _("Change System"),  "sman_system" },
		{ _("Change Engines"), "sman_engine" },
		{ _("Change Hull"),    "sman_hull" },
		{ _("Add Outfit"),	   "sman_extra" },
		{ _("Nevermind"),	   "end" },
	}
	if player.isLanded() and spob.cur():services().shipyard then
		shuttle_choices = join_tables(
			{ { _("Replace Shuttle"), "sman_buy_shuttle"} },
			shuttle_choices
		)
	end
	vn.menu( shuttle_choices )
	vn.label("sman_buy_shuttle")
	if not edata.shuttle and mem.ship_interior.shuttle then
		escort( fmt.f(_([[Tired of the old {ship} are we? That's fine, I can get us a replacement at the shipyard here. What would you like?]]), mem.ship_interior.shuttle) )
	elseif edata.shuttle then
        -- in case it's borked
        print(edata.shuttle)
		escort( fmt.f(_([[Tired of my flying around in my {ship} are you? That's fine, I can get myself a replacement at the shipyard here. What do you want me to fly?]]), edata.shuttle) )
	else
		escort( _([[Wait a minute, do we even have a shuttle in there? Well, it's definitely time for a replacement.]]) )
	end
	local feedback
	vn.func( function()
		local desired_ship = tk.input(_("What shuttle should we buy?"), 4, 20, _("Ship name:"))
		local shuttle_candidate
		
		-- now we search for a ship matching this description
		for _, sship in ipairs(spob.cur():shipsSold()) do
			if 
				desired_ship
				and	string.find(sship:name():lower(), desired_ship:lower())
				and	( -- get the better matching ship in case there are variants
					not shuttle_candidate
					or shuttle_candidate:name():len() > sship:name():len()
				)
			then
				-- this is what the player wants
				shuttle_candidate = sship
			end
		end
		-- check if the player wanted a reset
		if
			string.find(desired_ship:lower(), _("reset"))
			or string.find(desired_ship:lower(), _("cargo shuttle"))
			or string.find(desired_ship:lower(), "alpaca")
		then
			shuttle_candidate = ship.get("Alpaca")
		end

		-- print( fmt.f("Shuttle Cardidate is {this} of size {size}", { this=shuttle_candidate, size=shuttle_candidate:size() } ) )
		
		-- find a reason to stop the player
		local reason
		if not desired_ship then
			vn.jump("end")
			return
		elseif not shuttle_candidate then
			message = _("I couldn't find anything matching that description in the shipyard... Why are you wasting my time?")
			vn.jump("say_end")
			return
		elseif player.credits() < shuttle_candidate:price() then -- budget issue, can't afford
			reason = _("I'll be laughed at for not having the credits. I need you to be able to authorize a payment of at least ") .. fmt.credits(shuttle_candidate:price()) .. _(" in order to buy a ") .. shuttle_candidate:name() .. (" here.")
		elseif
			( shuttle_candidate:size() > 2					  -- too big for a private shuttle
			or shuttle_candidate:size() > math.floor(mem.ship_interior.bay_strength / 3) -- doesn't fit in bays
			or shuttle_candidate:tags().bioship				-- no inspace refit
			) and shuttle_candidate:nameRaw() ~= "Alpaca"
		then
			reason = _("I'll be stuck with a ship without a hyperdrive, and I won't even be able to squeeze it into your fighter bays.")
		elseif	-- already have this on board and we aren't an officer pilot
			(
			mem.ship_interior.shuttle and mem.ship_interior.shuttle.ship == shuttle_candidate
			and not mem.ship_interior.shuttle.out
			) and not string.find(edata.skill, _("Officer"))
		then
			feedback = fmt.f(_("Well... it looks to me like we already have a {ship}, what's wrong with the old one? I guess I'll restore it to the default configuration for now."), { ship = shuttle_candidate } )
			vn.jump("sman_clear_outfits")
			return
		end
		
		-- check if we prevented the player from buying it
		if					
			reason
		then
			message = fmt.f(_("Well, I can tell you now that I'm not going to get that authorized, if I try to buy a {ship} now "), { ship = shuttle_candidate } ) .. reason
			shuttle_candidate = nil
			vn.jump("say_end")
			return
		end
		
		-- if we reach here, we definitely want to buy this ship
		local scost = shuttle_candidate:price()
		player.pay(-scost)
		-- who gets the shuttle?
		if	-- If I'm an officer myself or if I already have a shuttle
			(string.find(edata.skill, _("Officer")) or edata.shuttle)
			-- and this isn't like my shuttle, unless my shuttle is missing
			and (edata.shuttle.ship ~= shuttle_candidate or edata.shuttle.out) 
		then
			edata.shuttle = { ship = shuttle_candidate } 
		else
			-- we bought a ship shuttle, but nobody owns it yet
			mem.ship_interior.shuttle = { ship = shuttle_candidate }
			-- we probably have a commander that owns a shuttle, we need to throw out the old one
			-- if we don't have a commander, then this just becomes an auxiliary ship
			local commander = getCommander()
			if commander then
				commander.shuttle = mem.ship_interior.shuttle
			end
		end
		playMoney()
		shiplog.append(
			logidstr,
			fmt.f(
				_("Your shuttle manager {name} "),
				edata
			) .. fmt.f(_("bought a {shuttle} for the ship for {cost}."), {shuttle = shuttle_candidate, cost = fmt.credits(scost) } )
		)
		feedback = _("Excellent choice! I'll have the shipyard here modify one for shuttle usage right away. Don't forget to come back in a bit to reconfigure it if you want any other modifications.")
	end )
	
	-- deliberate fallthrough
	vn.label("sman_clear_outfits")
	escort( function () return feedback end)
	
	vn.func( function ()
		edata.manager.outfits = nil
	end )
	vn.jump("end")
	
	vn.label("sman_system")
	escort( _([[Alrighty then, let's see, what core system would you like? The Thalos 2202 is quite popular these days.]]) )
	
	vn.func( function ()
		local spoken = tk.input(_("New Core System"), 4, 64, _("System:"))
		local system = getShuttleOutfit(spoken)
		if system then
			edata.manager.system = system
			player.pay(-system:price()) -- NOTE we check if the player owned the system first, but didn't remove one
			playMoney()
			feedback = fmt.f(_("A {system} huh? I hope it fits!"), edata.manager)
		else
			feedback = _("That didn't quite make sense, we'll get it next time.")
		end
	end )
	escort( function () return feedback end )
	vn.jump("sman_extra")
	vn.done()
	
	vn.label("sman_engine")
	escort( _([[Alrighty then, what's next... What engines would you like? I'm a big fan of the Dart 150.]]) )
	vn.func( function ()
		local spoken = tk.input(_("New Core Engines"), 4, 64, _("Engines:"))
		local engine = getShuttleOutfit(spoken)
		if engine then
			edata.manager.engine = engine
			player.pay(-engine:price())
			playMoney()
			feedback = fmt.f(_("A {engine} huh? I hope that fits!"), edata.manager)
		else
			feedback = _("That didn't quite make sense, we'll get it later.")
		end
	end )
	escort( function () return feedback end )
	vn.jump("sman_extra")
	vn.done()
	
	vn.label("sman_hull")
	escort( _([[Well finally, last but not least -- what hull would you like? A small cargo hull of some kind perhaps?]]) )
	vn.func( function ()
		local spoken = tk.input(_("New Core Hull"), 3, 64, _("Hull:"))
		local hull = getShuttleOutfit(spoken)
		if hull then
			edata.manager.hull = hull
			player.pay(-hull:price())
			playMoney()
			feedback = fmt.f(_("A {hull} huh? I hope this fits!"), edata.manager)
		else
			feedback = _("That didn't quite make sense, we'll get it next time around.")
		end
	end )
	escort( function () return feedback end )
	vn.jump("sman_extra")
	vn.done()
	
	vn.label("sman_extra")
	escort( _("Do you want me to try to add some other outfit? Remember that this is a shuttle, weapons won't do me any good.") )
	vn.menu({
		{ _("Keep configuring core slots"), "shuttle_management" },
		{ _("Yes, add a specific outfit"),	"add_outfit" },
		{ _("No, let's finish up"),			"finish_inspection" },
		{ _("Nevermind, let's finish this later"), "end" },
	})
	vn.label("add_outfit")
	vn.func( function ()
		local spoken = tk.input(_("Extra outfit"), 0, 64, _("Extra outfit:"))
		-- TODO: check if spoken is a command
		if not spoken or spoken:len() < 3 then
			-- no feedback
			feedback = _("Uhh... what?")
			return
		end
		local chosen = getShuttleOutfit(spoken)
		if chosen ~= nil then
			edata.manager.preferred_outfit = chosen
			player.pay(-chosen:price())
			playMoney()
			feedback = fmt.f(_("{preferred_outfit} eh? I hope that fits!"), edata.manager)
		else
			feedback = _("That didn't quite make sense, we'll get it next time around.")
		end
	end )
	escort( function () return feedback end )
	-- deliberate fallthrough
	
	vn.label("finish_inspection")
	local passed = false
	vn.func( function() 
		-- sanity check, captain doesn't know better
		if not (
			edata.manager.system and edata.manager.engine and edata.manager.hull
		) then
			feedback = _("Something isn't right with the selected outfits, something's missing but I can't put my finger on it... I swear though, we must be forgetting something!")
			return
		end
		vn.jump("inspection_good")
	end)
	escort( function () return feedback end )
	vn.jump("sman_extra") -- need to pass inspection from inside func or leave to avoid looping back
	
	vn.label("inspection_good")
	escort( _("Alright, check back with me in a bit and I should be able to make any requested adjustments.") )
	vn.func( function () 
		local special = {}
		special.message = _("Shuttle Maintenance")
		special.feedback = pick_one(getConversation(edata).default_participation)
		special.price = math.ceil(math.max(20e3 + edata.salary, 23 * edata.salary) - edata.xp * edata.satisfaction)
		special.label = fmt.f(_("Shuttle Refit & Inspection"), {credits = fmt.credits(special.price) } )
		local target_shuttle = edata.shuttle or mem.ship_interior.shuttle
		special.choices = {
		{ fmt.f(_("Perform Refit for {credits}"), {credits = fmt.credits(special.price) } ), "special_yes" },
		{ _("Nevermind"), "end" }
		}
		special.message = fmt.f(_("I can perform that {ship} inspection, refit and maintenance now. Should I?"), {ship = target_shuttle.ship:name() })

		edata.manager.special = special
	end )
	vn.done()
	
	-- END SECTION SHUTTLE MANAGER
	
	-- if we have a special thing, enable the logic
	if management and management.special then
		-- a custom function defined in the character sheet
		vn.label("special")
		escort(management.special.message)
		if management.special.choices then
			vn.menu(management.special.choices)
		end
		
		-- we assume the player says yes or that there are no choices
		-- if the choice was no, player jumps
		
		vn.label("special_yes")
		escort(management.special.feedback)
		vn.func( function() 
			doSpecialManagementFunc(edata)
		end )
		
		vn.done()
	end
	
	vn.label("discard_special")
	-- throws out the special item, if there is one
	vn.func( function() 
		if edata.manager then
			mem.ship_interior.dirt = mem.ship_interior.dirt + 0.5 -- we aren't as clean as the officers
			-- earn a random amount of xp for using the item personally instead of discarding it
			edata.xp = edata.xp + rnd.sigma() + rnd.rnd()
			-- unhappy because we were told to discard something we brought on board
			edata.satisfaction = edata.satisfaction - 0.06
			-- anyone in the cargo bay enjoys the fruits of the discard
			-- and then the sanitation workers that go to the cargo bay (not janitorial)
			for ii, worker in ipairs(mem.companions) do
				if ii <= player.pilot():stats()["crew"] then
					if
						string.find(worker.skill, _("Cargo"))
						or string.find(worker.skill, _("Sani"))
					then
						worker.xp = worker.xp + 0.003
						worker.satisfaction =  worker.satisfaction + 0.1 * rnd.rnd()
						local sentiments = {
							_("I can't believe the captain wanted to throw these out. You want one?"),
							_("I can't believe the captain wanted to throw these out."),
							_("The captain wanted to throw these out. You want one?"),
							_("You want one of these?"),
							_("I grabbed these from the discard pile. You want one?"),
						}
						insert_sentiment(worker, pick_one(sentiments))
						
						-- if this crewmate actually likes this item, give one
						-- TODO: implement get_item from special wrapper
					end
				end
			end
			edata.manager.special = nil
		end
	end )
	vn.done()
	
	-- display a nice crew sheet
	vn.label("crewsheet")

	vn.func( function()
		vn.textbox_font = graphics.newFont( _("fonts/D2CodingBold.ttf"), 15 )
	end)

	escort( function () return message end )
	escort(_("Anything else?"))
	vn.func( function()
		vn.textbox_font = textbox_font
	end)
	vn.jump("chat")
	vn.done()
	
	vn.label("summon")
	-- let the player to summon the crew for credits
	escort(
		fmt.f(
			_(
				"Would you like to summon the crew to be available for discussion at the next bar? This will cost {credits}."
			),
			{credits = fmt.credits(management.cost)}
		)
	)
	vn.menu({
		{ _("Yes"), "do_summon" },
		{ _("No"), "end" },
	})
	vn.label("do_summon")
	vn.func( function () 
		mem.summon_crew = true
		player.pay(-management.cost)
		playMoney()
		shiplog.append(
			logidstr,
			fmt.f(
				_("You paid {credits} in crew management fees."),
				{
					credits = fmt.credits(management.cost)
				}
			)
		)
		
		-- don't let the player summon twice
		for index, choice in ipairs(choices) do
			if choice == summon then
				table.remove(choices, index)
			end
		end
	end )

	vn.jump("end")
	
	-- let the player buy drinks for the crew that is present
	-- the payer has to pay for as many drinks as there are people at the bar
	-- because well, otherwise the player should be distributing fruit or something
	-- the smuggler can do that (gets a crate for smuggling and can convert food into fruit crate)
	vn.label("drinks")
	local num_crew = #mem.companions
	if npcs and #npcs > 0 then
		num_crew = math.min(#npcs, num_crew)
	end
	local drinks_price = math.max(management.cost, management.cost * num_crew - (edata.satisfaction * management.cost * 0.1 * edata.xp))
	escort(
		fmt.f(
			_(
				"Would you like to buy everyone a round of drinks? This will cost {credits}."
			),
			{credits = fmt.credits(drinks_price)}
		)
	)
	vn.menu({
		{ _("Yes"), "do_drinks" },
		{ _("No"), "end" },
	})
	vn.label("do_drinks")
	vn.func( function () 
		player.pay(-drinks_price)
		-- everyone at the bar gets a decent chance to enjoy their drink and actually like it
		for _i, worker in ipairs(mem.companions) do
			-- make sure this npc is at the bar, find it in the loop
			if player.isLanded() and npcs then
				for _j, cdata in pairs(npcs) do
					-- buy everyone a drink, but not the person who bought the round
					if cdata == worker and cdata ~= edata then
						-- enjoyment can be good or bad but pushed up by the managers xp
						local enjoyment = rnd.rnd() + rnd.threesigma() + edata.xp * 0.06
						worker.satisfaction = math.min(10, worker.satisfaction + enjoyment * 0.1)
						if enjoyment >= 1.25 then
							worker.conversation.sentiment = _("I really enjoyed that drink.")
						elseif enjoyment < 0 then
							insert_sentiment(worker, _("That drink I didn't ask for was nasty."))
						elseif rnd.rnd() < worker.chatter then
							insert_sentiment(worker, _("It was nice of the captain to buy us all drinks."))
						end
						print(fmt.f("{name} evaluated a free drink at {enjoyment}", {name = worker.name, enjoyment=enjoyment}))
					elseif cdata == edata then
						-- buy my own drink, of course I like it
						edata.satisfaction = edata.satisfaction + 0.02
					end
				end
			else
				local enjoyment = rnd.rnd() + rnd.threesigma() + edata.xp * 0.06 + math.abs(worker.satisfaction) * rnd.rnd()
				worker.satisfaction = math.min(10, worker.satisfaction + enjoyment * 0.1)
				if enjoyment >= 1.82 then
					worker.conversation.sentiment = _("I really enjoyed that drink.")
					insert_sentiment(worker, _("It's nice to get fancy drinks while on duty."))
				elseif enjoyment < 0 then
					insert_sentiment(worker, _("That drink I didn't ask for was nasty."))
					insert_sentiment(worker, _("Why are we even getting those drinks while on duty?"))
				elseif rnd.rnd() < worker.chatter then
					insert_sentiment(worker, _("It was nice of the captain to get us all drinks."))
				end
			end
		end
		shiplog.append(
			logidstr,
			fmt.f(
				_("You paid {credits} to treat your crew."),
				{
					credits = fmt.credits(drinks_price)
				}
			)
		)

	end )
	vn.sfxBingo()
	vn.jump("end")
	
	-- buying a shuttle for an officer
	vn.label("buy_shuttle")
	vn.func( function()
		player.pay(-shuttle_candidate:price())
		edata.shuttle = { ship = shuttle_candidate }
		playMoney()
	end )
	escort(_("Nice, I'm sure it will come in handy."))
	vn.done()
	
	vn.label("say_end")
	escort( function () return message end )
	vn.done()
	-- say goodbye
	vn.label("end")
	vn.func( function ()
		vn.textbox_font = textbox_font
	end )
	escort(pick_one(getConversation(edata).default_participation))
	vn.done()
	vn.run()
	
end

-- starts a conversation with the companion
function startConversation(companion)
	local introduction
	-- what does the companion want to talk about
	-- if satisfaction is low, be negative and brief
	if companion.satisfaction < 0 then
		introduction = pick_one(getConversation(companion).unsatisfied)
	else
		-- if satisfaction is high, be positive and verbose (extra greeting, etc)
		local greeting =
			pick_one(
			{
				_("Hello, Captain."),
				_("Oh. Hi there.") -- default neutral
			}
		)
		-- use chatter variable to determine verbosity TODO
		introduction = greeting .. "\n\n" .. pick_one(getConversation(companion).satisfied)
	end

	if companion.conversation.sentiment then
		introduction = introduction .. " " .. companion.conversation.sentiment
	end

	return introduction
end

-- Provides the player with the option to fire the pilot or to
-- start a conversation or management discussion
-- you can also raise or lower the chatter by praising or scolding the crew
function crewmate_barConversation(edata, npc_id)
	local managing = ""
	if edata.manager then
		managing = edata.manager.type
	end
	if not edata.firstname then
		edata.firstname = "Mysterious"
	end -- generic dreadful nick, but better than "Gendrick"

	local praise_price = math.ceil(5 * edata.xp * edata.satisfaction)
	local scold_price = math.floor(20 * edata.xp + edata.satisfaction)

	local name_label = fmt.f("{firstname} {name}", edata)
	local fire_label = _("Fire")
	if edata.salary == 0 then
		fire_label = _("Expel")
	end
	local n, _s =
		tk.choice(
		name_label,
		startConversation(edata),
		fmt.f(_(" Discuss {managing}"), {managing = managing}),
		fmt.f(_("Give Praise ({credits})"), {credits = fmt.credits(praise_price)}),
		fmt.f(_("Reprimand ({credits})"), {credits = fmt.credits(scold_price)}),
		fmt.f(_("{fire_label} {typetitle}"), { fire_label = fire_label, typetitle = edata.typetitle } ),
		_("Do nothing")
	)
	if n == 1 then -- Manager stuff
		-- if we are a manager, do the manager thing, otherwise, say a random thing
		if edata.manager then
			startManagement(edata)
		else
			-- start a one on discussion with this crewmate
			startDiscussion(edata)
		end
	elseif n == 2 then -- praise
		-- some responses specific to the praise
		local responses = {
			_("Thanks!"),
			_("Yeah, okay."),
			fmt.f(_("Okay, {name}."), {name = player.name()}),
			fmt.f(_("Aright, {name}. Thanks for the feedback."), {name = player.name()}),
			_("Thank you.")
		}
		-- default responses
		responses = join_tables(responses, getConversation(edata).default_participation)
		-- add some interesting responses
		if edata.conversation.sentiment then
			table.insert(responses, edata.conversation.sentiment)
		end
		if edata.conversation.sentiments then
			responses = join_tables(responses, edata.conversation.sentiments)
		end
		-- reply to the captain
		vntk.msg(name_label, pick_one(responses))

		-- adjust the sentiment
		edata.conversation.sentiment =
			fmt.f(
			pick_one(getConversation(edata).good_talker),
			{name = player.name(), article_subject = _("the captain"), article_object = _("the captain"), firstname = player.name() }
		)

		-- adjust the chatter trying to increase it
		edata.chatter = math.max(edata.chatter, math.min(0.66, edata.chatter + 0.1 + 0.1 * rnd.threesigma()))
	elseif n == 3 then -- criticize
		-- responses specific to the criticism
		local responses = {
			_("Okay captain."),
			_("Yeah, okay."),
			fmt.f(_("Okay, {name}. I'm sorry to hear that."), {name = player.name()}),
			fmt.f(_("Aright, {name}. Thanks for the feedback."), {name = player.name()}),
			_("Sorry."),
			_("I'll try and do better next time."),
			_("I'll try and learn from the others."),
			_("I'm sorry sir."),
			_("I'll take a step back."),
			_("Whatever you say sir."),
			_("Oh, man. Good to know, I guess.")
		}
		-- default responses
		responses = join_tables(responses, getConversation(edata).default_participation)
		-- maybe let's just talk about violence
		local violence = getTopics(edata).liked.violence
		if violence then
			responses = join_tables(responses, violence)
		end
		-- reply to the captain
		vntk.msg(name_label, pick_one(responses))

		-- adjust the sentiment
		edata.conversation.sentiment =
			fmt.f(
			pick_one(getConversation(edata).bad_talker),
			FAKE_CAPTAIN
		)

		-- adjust the chatter trying to push it down
		edata.chatter = math.min(edata.chatter, math.max(0.16, edata.chatter - 0.1 - 0.1 * rnd.threesigma()))
	elseif n == 4 then
		local allowed, denial = can_terminate_crew(edata)
		if not allowed then
			vntk.msg(_("Required commander"), denial)
			return
		end
		if not vntk.yesno("", fmt.f(_("Are you sure you want to {fire_label} {name}? This cannot be undone."), { fire_label = fire_label:lower(), name = edata.name } )) then
			return
		end
		local liked = getTopics(edata).liked
		
		-- reply to the captain or storm off, depending on whether we know violence, have friends, or neither
		if liked.violence then
			-- talk about violence if possible
			vntk.msg(name_label, fmt.f(pick_one(liked.violence), edata))
		elseif liked.friend then
			-- remisince about a friend one last time before the captain
			vntk.msg(name_label, fmt.f(pick_one(liked.friend), edata))
		end
		
		local reason = fmt.f(_("You fired '{name}'."), edata)
		terminate_crew(edata, reason)

	end
end

-- Approaching hired pilot at the bar

return contract.capture {
	name = "management_ui",
	requires = {
		"context", "content.character", "memory", "crew_factory",
		"crew_factory_npcs", "management",
	},
	exports = { "startManagement", "startConversation", "crewmate_barConversation" },
}
