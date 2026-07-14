local der = require "common.derelict"
local fmt = require "format"
local pilotname = require "crewmates.pilotname"
local vntk = require "vntk"
local vn = require "vn"
local portrait = require "portrait"
local love_shaders = require "love_shaders"
local graphics = require "love.graphics"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function startCommandDiscussion()
	-- if there's an open dialog, close it
	player.commClose()
	local officer = SHIP_OFFICERS[_('First Officer')]
	if not officer then
		local officer_type = pick_key(SHIP_OFFICERS)
		officer = officer_type and SHIP_OFFICERS[officer_type]
	end
	if not officer or officer and officer.away then
		officer = getCommander()
	end
	if not officer then
		vntk.msg(_("No one on the bridge"), _("There's nobody on the bridge right now to talk to. Hopefully someone will come by soon."))
		clearCommanderInterface()
		print("WARN: No officer available in startCommandDiscussion")
		return
	end	
	-- woah, we are an officer! lets do our officer/manager thing
	local management = officer.manager
	local mlines = getManagerLines( officer )

	-- if we can't afford our officer's services...
	if management.cost and player.credits() < management.cost then
		vntk.msg(
			fmt.f("{typetitle} {name}", officer),
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
	local drinks = { _("Motivate crew"), "drinks" }
	local dismiss = { _("Dismiss"), "end" }
	
	local choices = {}
	if true then -- TODO: figure out if this character knows how to chat
		table.insert(choices, chat)
	end

	-- if we have something special to use
	if management.special then
		table.insert(choices, 
			{ management.special.label, "special" }
		)
	elseif mem.ship_interior.dirt_accum > 0 or mem.ship_interior.dirt > player.pilot():ship():size() then
		table.insert(choices,
			{ _("Clean ship"), "clean" }
		)
	end
		
	-- summon the crew to the bar on the next spob
	if not mem.summon_crew and management.cost > 0 then
		table.insert(choices, summon)
	end	
	
	-- motivate the crew
	if management.cost > 0 then
		table.insert(choices, drinks)
	end
	
	-- always put the dismiss option last
	table.insert(choices, dismiss)

	-- default message in case we end up here without an appropriate management skill
	local message = fmt.f(_("Greetings {captain}. What can I do for you?"), {captain = pick_one({
		_("captain"),
		_("Captain"),
		player.name(),
		_("captain ") .. player.name(),
		_("Captain ") .. player.name(),
	})})
	
	local vn_params = { image = portrait.getFullPath(officer.portrait) }
	if mothership and mothership ~= player.ship() then
		vn_params.shader = love_shaders.hologram()
	end
	
	officer.vncharacter = portrait.getFullPath(officer.portrait)
	local textbox_font = vn.textbox_font
	-- open dialog part comes here
	vn.clear()
	vn.scene()
	local escort = vn.newCharacter ( fmt.f(_("{skill} {name}"), officer), vn_params )
	vn.transition()
	vn.label("start")
	-- give a command assessment
	vn.func( function() 
		vn.textbox_font = textbox_font
		local key, troublemaker = commandAssessment()
		if not troublemaker then
			troublemaker = {}
		end
		if mlines[key] then
			message = fmt.f(pick_one(mlines[key]), troublemaker)
		else
			message = _("Oh hey, what's up?")
		end
	end )
	-- maybe we are an unknown kind of manager, then nothing happens

	escort(function() return message end)
	vn.menu(function () return choices end) -- makes us jump to a label
	vn.done()
	-- talk with the officer about something they know about
	vn.label("chat")
	-- monster func, just fold this and move on
	local command
	vn.func( function()
		message = _("I'm not sure how to help you.")
		local chatting = false
		local wmore = false
		-- we want to keep chatting as much as possible
		local spoken = tk.input(_("Bridge Command"), 0, 64, _("Say:"))
		if spoken then
			spoken = spoken:lower()
			-- for now, let's just do a basic personnel analysis in here to refactor later (with management logic)
			-- find a name from the input
			for _i, worker in ipairs(mem.companions) do
				if string.find(spoken, worker.name:lower()) 
				or string.find(spoken, worker.firstname:lower())
				then
					chatting = true
					-- this worker is the subject
					if string.find(spoken, "rename") then
						-- the captain wants to rename this person
						local new_name = tk.input(worker.name, 3, 16, _("New Name:"))
						if new_name then
							worker.name = new_name
							message = fmt.f(_("Alright, {article_subject} will now be known as {name}."), worker)
							-- worker's xp and satisfaction is slightly affected by this
							worker.satisfaction = worker.satisfaction + rnd.sigma()
							worker.xp = worker.xp + rnd.sigma() * 0.01
							insert_sentiment(worker, fmt.f(_("{typetitle} {name} gave me a new name."), officer))
							insert_sentiment(worker, fmt.f(_("{name} didn't like my name."), FAKE_CAPTAIN))
							insert_sentiment(worker, fmt.f(_("{firstname} didn't like my name."), FAKE_CAPTAIN))
							insert_sentiment(worker, fmt.f(_("Well, {article_subject} didn't like my name."), FAKE_CAPTAIN))
						else -- the captain canceled the renaming process, stop talking now
							vn.jump("say_end")
						end
					elseif string.find(spoken, "renick") then
						-- the captain wants to give this person a new nickname
						-- like renaming, but generates a random new first name instead of setting a specific last name
						-- just so that you can't force a crewmates friends to call him an expletive, 
						-- even though you can totally name him that as a proper last name if you want
						local _last, new_name = pilotname.human()
						if new_name then
							worker.firstname = new_name
							message = fmt.f(_("Alright, {article_subject} will now be known as {firstname}."), worker)
							-- worker's xp and satisfaction is slightly affected by this
							worker.satisfaction = worker.satisfaction + rnd.sigma()
							worker.xp = worker.xp + rnd.sigma() * 0.01
							insert_sentiment(worker, fmt.f(_("{typetitle} {name} gave me a new nickname."), officer))
							insert_sentiment(worker, fmt.f(_("{name} didn't like the first name assigned to me at birth."), FAKE_CAPTAIN))
							insert_sentiment(worker, fmt.f(_("{firstname} didn't like my nickname."), FAKE_CAPTAIN))
							insert_sentiment(worker, fmt.f(_("Well, {article_subject} didn't really like my name."), FAKE_CAPTAIN))
						end
					elseif string.find(spoken, _("sheet"))
						or string.find(spoken, _("info"))
						or string.find(spoken, _("detail"))
					then
						-- be a perfect commander and access the personnel files
						message = getCrewSheet(worker)
						vn.jump("crewsheet")
					-- don't fire myself, I'm not that valiant
					elseif worker ~= officer and (
						string.find(spoken, _("fire"))
						or string.find(spoken, _("airlock"))
						)
					then
						local allowed, denial = can_terminate_crew(worker)
						if not allowed then
							message = denial
							vn.jump("say_end")
						else
							local sacrificed_xp = math.max(1, worker.xp - worker.satisfaction) * rnd.rnd()
							-- the captain wants to throw this person out of the airlock
							terminate_crew(worker, fmt.f(_("You ordered {title} {officer} to throw {worker} out of the airlock in {system}."), { officer = officer.name, title = officer.typetitle, worker = worker.name, system = system.cur() }))
							-- recalculate crew roster using takeoff logic
							takeoff()
							der.sfxUnboard()
							-- everyone should get some xp or something for witnessing the sacrifice
							for _j, witness in ipairs(mem.companions) do
								local xp_bonus = rnd.rnd() + rnd.sigma() * 0.05 + sacrificed_xp * rnd.rnd()
								witness.xp = math.min(99, witness.xp + xp_bonus)
								-- TODO: create sacrifice memory :)
							end
							local executioner = getCrewmateOnboard() or officer
							executioner.xp = executioner.xp + 2
							executioner.satisfaction = executioner.satisfaction - 1
							vn.jump("end")
						end
					elseif string.find(spoken, _("commend")) then
						-- the captain wants to boost this person's xp and satisfaction
						player.pay(-management.cost)
						playMoney()
						-- motivational boost
						worker.satisfaction = worker.satisfaction + 0.77 + rnd.rnd()
						-- small pay bump
						worker.salary = math.ceil(worker.salary * 1.01) + 3
						-- small xp gain chance
						worker.xp = math.min(99, worker.xp + 0.1 * (rnd.rnd() + rnd.sigma()))
						insert_sentiment(worker, fmt.f(_("{typetitle} {name} said I'm doing a good job!"), officer))
						insert_sentiment(worker, fmt.f(_("{skill} {name} said I'm doing a good job!"), officer))
						-- give the worker a symbolic gift of some kind
						local gift_options = append_table(
							-- construct a base table of appropriate gifts of types and descriptors
							{
								fmt.f("{nice} {item}", { nice = pick_one(lang.adjectives.positive.nice), item = pick_one(lang.nouns.objects.items) } ),
								fmt.f("{nice} {item}", { nice = pick_one(lang.adjectives.positive.nice), item = pick_one(lang.nouns.objects.clothes) } ),
								fmt.f("{item}", { item = pick_one(lang.nouns.objects.accessories) } ),
								fmt.f(_("{item} repair manual"), { item = pick_one(lang.nouns.objects.spaceship_parts) } ),
								fmt.f(_("{item} troubleshooting guide"), { item = pick_one(lang.nouns.objects.spaceship_parts) } ),
								fmt.f(_("{item} diagnostics & analysis system"), { item = pick_one(lang.nouns.objects.spaceship_parts) } ),
								fmt.f("{adjective} {item}", { adjective = pick_one(lang.adjectives.size.small), item = pick_one(lang.getAll(lang.nouns.objects)) } ),
								fmt.f(_("{adjective} {item} figurine"), {
									adjective = pick_one(join_tables(lang.adjectives.positive.magical, lang.adjectives.violent)),
									item = pick_one(lang.getAll(lang.nouns.actors.people))
								} ),
								fmt.f(_("{nice} {adjective} {item} figurine"), { nice = pick_one(lang.adjectives.positive.nice), adjective = pick_one(lang.getAll(lang.adjectives)), item = pick_one(lang.getAll(lang.nouns.actors.people)) } ),
								fmt.f("{nice} {item}", { nice = pick_one(lang.adjectives.colors), item = pick_one(lang.nouns.objects.items) } ),
								fmt.f("{nice} {item}", { nice = pick_one(lang.adjectives.colors), item = pick_one(lang.nouns.objects.clothes) } ),
							},
							-- add custom stylized choices of what we would consider nice gifts
							lang.nouns.gifts
						)
						give_item(worker, pick_one(gift_options))
						-- remember that we got this nice gift
						local sentiment = fmt.f(_("The captain gave me a {item}!"), worker)
						create_memory(worker, "specific", { topic = player.name(), specific = string.gsub(sentiment, "!", ".") } )
						insert_sentiment(worker, sentiment)
						-- tell the captain what we got the worker so that the player enjoys the worker mentioning it
						message = fmt.f(_("Good idea. I'll get {article_object} a {item} as well."), worker)
						-- we have a job to do, go do it, captain can bother us when we are done
						vn.jump("say_end")
					elseif string.find(spoken, _("summon")) then
						command = worker
						vn.jump("summon_single")
						return
					elseif string.find(spoken, _("promote")) then
						command = worker
						vn.jump("promote_worker")
						return
					else
					-- let's talk about this person
						message = fmt.f(pick_one(mlines.specific), worker)
					end

				end
			end
			if not chatting then
				-- TODO: check if the captain wants to hire new staff
				if string.find(spoken, _("rename to")) then
					-- the captain wants te rename me :'(
					officer.name = spoken:sub( 11, #spoken):gsub("^%l", string.upper)
				end
				-- special missions

				-- show me a list of crew that match spoken (typetitle or skill)
				if string.find(spoken, _("list")) then
					chatting = true
					command = spoken
					vn.jump("list")
					return
				elseif
					string.find(spoken, _("salary"))
					and officer.manager.skill == "payroll"
				then
					chatting = true
					command = spoken
					vn.jump("salary")
					return
				elseif
					string.find(spoken, _("cargo"))
					or string.find(spoken, _("sell"))
					or string.find(spoken, _("trade"))
				then
					chatting = true
					command = spoken
					vn.jump("mission_sell")
					return
				elseif
					string.find(spoken, _("buy"))
					or string.find(spoken, _("procure"))
					or string.find(spoken, _("purchase"))
				then
					-- only if we find something we can use here
					local comm = parseCommodity(spoken)
					if
						comm
					then
						command = (spoken:match("%d+") or 4 * player.pilot():ship():size()) .. " " .. comm:name():lower()  
						chatting = true
						vn.jump("mission_buy")
						return
					end
				elseif
					string.find(spoken, _("let me fly"))
					or string.find(spoken, _("fly shuttle"))
					or string.find(spoken, _("joyride"))
				then
					chatting = true
					vn.jump("mission_shuttle")
				elseif string.find(spoken, _("summon pilot")) then
					command = findCrewOfType(_("Pilot"))
					-- summon another pilot, not ourselves
					if command and command ~= officer then
						vn.jump("summon_single")
						return
					end
				elseif string.find(spoken, _("take a break")) then
					crew_take_break(officer, command)
					message = _("Thanks! I appreciate the time for myself.")
					vn.jump("say_end")
					return
				elseif
					string.find(spoken, _("engage"))
					or string.find(spoken, _("attack"))
				then
					message = _("Give me a moment...")
					vn.jump("mission_engage")
					return
				end
				
				-- assume that if we want to buy a commodity, acquire/procure etc are already handled
				-- do we need to restock something?
				for _j, restock in ipairs(join_tables(lang.nouns.food.fruit, {
					_("get me"),
					_("give me"),
					_("find me"),
					_("craft"),
					_("create"),
					_("procure"),
					_("acquire"),
					_("restock"),
					_("fruit"),
					_("crate"),
					_("food"),
					_("hungry"),
				})) do
					if string.find(spoken, restock) then
						if convertFoodToFruit(officer, spoken) then
							insert_sentiment(officer, fmt.f(_("{name} seems to like bananas."), FAKE_CAPTAIN))
							insert_sentiment(officer, fmt.f(_("{name} seems to love mangoes."), FAKE_CAPTAIN))
							insert_sentiment(officer, fmt.f(_("{name} seems to really love strawberries."), FAKE_CAPTAIN))
							insert_sentiment(officer, _("So that's why there are never any strawberries..."))
							-- we're done with this conversation, we have a task!
							message = fmt.f(_("Good idea, I will procure some {fruit}s soon. Give me a moment."), officer.manager.special.crate)
							vn.jump("say_end")
							return
						else -- we couldn't create a fruit crate from the food
							message = _("I'm sorry, there's nothing I can do right now.")
							insert_sentiment(officer, fmt.f(_("{firstname} won't be happy that I couldn't restock the fruit."), FAKE_CAPTAIN))
							insert_sentiment(officer, _("We need more food in the cargo bay to keep the crew happy."))
						end
					end
				end
				
				-- last ditch, keep chatting?
				for _j, more in ipairs({
					_("more"),
					_("please"),
					_("what"),
					_("why"),
					_("how"),
					_("else"),
					_("anything"),
					_("doing"),
					_("satisf"),
					_("who"),
					_("help"), -- this is what you're really paying for with the officer
				}) do
					if string.find(spoken, more) then
--						print(fmt.f("found {more}", {more=more}))
						vn.jump("start")
						wmore = true
						chatting = true
						insert_sentiment(officer, fmt.f(_("{name} sure likes to chat."), FAKE_CAPTAIN))
					end
				end
			end
		end
		vn.textbox_font = textbox_font
		if wmore then vn.jump("start") end
		if not spoken or not chatting then
			vn.jump("end")
		end
	end )
	escort( function() return message end )
	vn.jump("chat")
	vn.done()
	
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
			doSpecialManagementFunc(officer)
		end )
		
		vn.done()
	end
	
	vn.label("discard_special")
	-- discards the special item, if there is one
	vn.func( function()
		-- when an officer discards something, some waste is left behind
		-- but the officer earns or loses some experience, favoring gains
		-- but since it's an officer, discarded items become decorations to be enjoyed

		officer.xp = officer.xp + 0.1 * (rnd.sigma() + rnd.rnd())

		local item
		if officer.manager.special and officer.manager.special.crate and officer.manager.special.crate.fruit then
			item = officer.manager.special.crate.fruit
		end
		-- I'm an officer, I'll take this item for myself if I like it
		if item and not officer.item and evaluate_item_haste(officer, item) > 0.6 then
			give_item(officer, item)
		else -- we had to discard something, make the dirt happen
			mem.ship_interior.dirt = mem.ship_interior.dirt + officer.xp * 0.06
			mem.ship_interior.decoration = item
		end
		
		-- clear the payload
		officer.manager.special = nil
	end )
	escort(_("Consider it done."))
	vn.done()
	
	vn.label("summon")
	-- let the player to summon the crew for credits
	escort(
		fmt.f(
			_(
				"Would you like to summon the crew to be available for discussion at the next bar? It will cost {credits} to persuade everyone."
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
	escort(
			_(
				"Would you like your officer to try to motivate the crew?"
			)
	)
	vn.menu({
		{ _("Yes"), "do_drinks" },
		{ _("No"), "end" },
	})
	vn.label("do_drinks")
	vn.func( function () 
		-- instead of paying for drinks, the commander pays with xp
		local siphoned_xp = math.max(0, officer.xp * 0.086)
		officer.xp = officer.xp - siphoned_xp
		-- everyone at the bar gets a decent chance to enjoy their drink and actually like it
		for _i, worker in ipairs(mem.companions) do

			-- buy everyone a drink, but not the person who bought the round
			if worker ~= officer then
				local enjoyment = rnd.sigma() + siphoned_xp - rnd.rnd()
				worker.satisfaction = math.min(10, worker.satisfaction + enjoyment * 0.1)
				if enjoyment >= 1.25 then
					local touches = {
						_("I really enjoyed that motivational speech."),
						_("I was touched by that motivational speech."),
						_("I believed in that motivational speech."),
						_("That motivational speech was powerful."),
						fmt.f(_("I trust {skill} {name}. Listen to {article_object}."), officer),
						fmt.f(_("I trust the {skill} because {article_subject} always gives such good advice."), officer),
						fmt.f(_("I trust {skill} {name}."), officer),
						-- TODO HERE: Create a random memory? !!
					}
					worker.conversation.sentiment = pick_one(touches)
				elseif enjoyment < 0 then
					insert_sentiment(worker, _("That motivational meeting was a waste of time."))
				elseif rnd.rnd() < worker.chatter then
					insert_sentiment(worker, _("It's nice to get some attention from the officers sometimes."))
				end
				print(fmt.f("{name} evaluated motivation at {enjoyment}", {name = worker.name, enjoyment=enjoyment}))
			elseif worker == officer then
				-- if I motivated the crew, I feel great
				officer.satisfaction = officer.satisfaction + 0.01 * siphoned_xp
			end

		end
		shiplog.append(
			logidstr,
			fmt.f(
				_("Your commander {name} tried to motivate your crew."),
				officer
			)
		)

	end )
	vn.sfxBingo()
	vn.jump("end")
	
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

	-- oh dear, we want to promote a lieutenant to a lieutenant commander (a titled officer)
	-- so now we have to figure out what the hell we can promote him to
	-- but we are just the commander, we think that this person can be promoted
	-- so lets just defer this to a promotion discussion with the crewmate
	-- that would get the promotion options before the vn starts
	vn.label("promote_worker")
	vn.func( function()
		hook.timer(rnd.rnd(3, 9), "startPromotionProcess", command)
		message = fmt.f(_("I will summon {article_object} promptly."), command)
	end )
	escort(function () return message end )
	vn.done()
	
	-- summon a single crewmate for a conversation on the bridge
	vn.label("summon_single")
	vn.func( function()
		vn.textbox_font = textbox_font
		if command.away and command.away.ship then -- on an away mission
			message = fmt.f(_("{notify} {mission}?"), {
				notify = fmt.f(_("It looks like {firstname} isn't on board. Didn't we send {article_object} on a "), command),
				mission = fmt.f(_("{mission} in the {ship}?"), command.away)
			})
		elseif command.away then -- probably on a break
			message = fmt.f(_("{notify} {mission}?"), {
				notify = fmt.f(_("It looks like {skill} {name} isn't available. Didn't we send {article_object} on a "), command),
				mission = fmt.f(_("{mission}"), command.away)
			})
		else
			if mothership and mothership ~= player:ship() then
				FAKE_CAPTAIN.target = command
				if command.manager then
					hook.timer(0, "startManagement", command, "bar")
				else
					hook.timer(0, "startDiscussion", command, "bar")
				end
			elseif command.manager then
				hook.timer(rnd.rnd(12, 16), "startManagement", command)
			else
				hook.timer(rnd.rnd(2, 6), "startDiscussion", command)
			end
			message = fmt.f(_("You should expect {article_object} to arrive shortly."), command)
		
		end
	end )
	escort(function () return message end )
	vn.done()
	
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
	
	-- the player wants to leave the commander in charge of the ship and
	-- take a joyride in the shuttle
	vn.label("mission_shuttle")
	
	vn.func( function ()
		-- check if we actually have access to a shuttle
		local shuttle = officer.shuttle or mem.ship_interior.shuttle
		-- check the bay strength first
		if not check_shuttle(shuttle) then
			response = fmt.f(_("The {name} isn't spaceworthy because it wouldn't fit in the docking bays. We need a bigger ship, more fighter bays or a smaller shuttle ship."), { name = shuttle.ship:name() } )
			return
		end
		-- we need a chosen pilot because we need a shuttle manager to save the fitting when we get back
		-- but we PREFER the regular pilot, because we like to send the promoted pilot in his own shuttle
		local chosen_shuttle_manager = findCrewOfType( _("Pilot") ) or findManagerOfType( _("Shuttle") )
		-- well if we are a shuttle manager (we are the pilot and you're about to fly my shuttle)
		-- then lets have the right shuttle manager... ourselves! Same for chief of security, if you change his fittings
		if
			officer.manager.type == _("Shuttle")
			or string.find(officer.skill, _("Chief of Security"))
		then
			chosen_shuttle_manager = officer
		end
		if chosen_shuttle_manager and not shuttle.out and chosen_shuttle_manager ~= officer then
			response = fmt.f(_([[Of course, I'll get {skill} {name} to prep the shuttle for you.
You can trust my capable hands with the ship once you're out.]]), chosen_shuttle_manager)
		elseif mothership ~= player.ship() then
			response = fmt.f(_("I can't find the {name}... Wait a minute, aren't you hailing me from it right now?"), { name = shuttle.ship:name() } )
			return
		elseif shuttle.out then
			response = fmt.f(_("I can't find the {name}. There's no shuttle."), { name = shuttle.ship:name() } )
			return
		else
			-- no extra pilot, but we are a pilot (commander)
			response = fmt.f(_([[Of course, I'll go and prep the shuttle for you.
You can trust my capable hands with the ship while you're gone.]]), officer)
		end
		-- good to go!
		-- we are using this shuttle (but not if the player is joyriding, he needs to put that one back
		mem.ship_interior.shuttle = shuttle
		-- this is the mission payload
		local payload = {
			commander = officer,
			shuttle_manager = chosen_shuttle_manager
		}
		-- start the mission
		hook.timer(6 + 0.1 * (100 - officer.xp), "player_swaps_to_shuttle", payload)
	end )
	
	escort ( function () return response end )
		
	vn.done()
	
	-- these two are super refactorable...
	-- player wants to sell some cargo remotely	
	vn.label("mission_sell")
	vn.func( function ()	-- prioritize promoted pilots here because they have their own shuttles
		local chosen_pilot = findManagerOfType( _("Shuttle") ) or findCrewOfType( _("Pilot") )
		local chosen_shuttle = chosen_pilot.shuttle or officer.shuttle
		if chosen_shuttle.out and officer.shuttle and not officer.shuttle.out then
			-- we probably chose the pilot's shuttle and it's out, weirdly?
			chosen_shuttle = officer.shuttle
		end
		
		-- check the bay strength first
		if not check_shuttle(chosen_shuttle) then
			response = fmt.f(_("The {name} isn't spaceworthy because it wouldn't fit in the docking bays. We need a bigger ship, more fighter bays or a smaller shuttle ship."), { name = chosen_shuttle.ship:name() } )
			return
		end

		-- we found a pilot to fly the shuttle and they have a shuttle (ours or theirs)
		if chosen_pilot and not chosen_shuttle.out and chosen_pilot ~= officer then
			response = fmt.f(_("Of course, I'll get {skill} {name} on it."), chosen_pilot)
		elseif chosen_shuttle.out then
			response = fmt.f(_("I can't find the {name}. There's no shuttle."), { name = chosen_shuttle.ship:name() } )
			return
		else
			-- the shuttle is here, let the first officer fly it (risk it for the biscuit)
			response = _("I couldn't find a pilot for the shuttle, I'm going myself.")
			chosen_pilot = officer
			clearCommanderInterface() -- the active officer leaves the bridge, another might come soon
		end

		local pcmd
		if parseCommodity(command) then
			pcmd = command
		end
			print("Command is", pcmd, command)
		-- this is the mission payload
		local payload = { -- away missions use the pilot shuttle on a Lt. Commander
			shuttle = chosen_pilot.shuttle or chosen_shuttle,
			crewsheet = chosen_pilot,
			mission = { mission = _("Trade Mission"), ship = chosen_shuttle.ship, directive = "sell", target = pcmd },
		}

		-- start the mission
		hook.timer(3 + 0.1 * (100 - officer.xp), "away_mission", payload)
	end )
	escort( function () return response end )
	vn.done()

	-- player wants to purchase commodities remotely	
	vn.label("mission_buy")
	vn.func( function ()
		local chosen_pilot = findManagerOfType( _("Shuttle") ) or  findCrewOfType( _("Pilot") )
		local chosen_shuttle = chosen_pilot.shuttle or officer.shuttle
		if chosen_shuttle.out and officer.shuttle and not officer.shuttle.out then
			-- we probably chose the pilot's shuttle and it's out, weirdly?
			chosen_shuttle = officer.shuttle
		end
		-- check the bay strength first
		if not check_shuttle(chosen_shuttle) then
			response = fmt.f(_("The {name} isn't spaceworthy because it wouldn't fit in the docking bays. We need a bigger ship, more fighter bays or a smaller shuttle ship."), { name = chosen_shuttle.ship:name() } )
			return
		end
	
		if chosen_pilot and not chosen_shuttle.out and chosen_pilot ~= officer then
			response = fmt.f(_("Of course, I'll get {skill} {name} on it."), chosen_pilot)
		elseif chosen_shuttle.out then
			response = fmt.f(_("I can't find the {name}. There's no shuttle."), { name = chosen_shuttle.ship:name() } )
			return
		else
			-- the shuttle is here, let the first officer fly it (risk it for the biscuit)
			response = _("I couldn't find a pilot for the shuttle, I'm going myself.")
			chosen_pilot = officer
			clearCommanderInterface() -- the active officer leaves the bridge, another might come soon
		end

		-- this is the mission payload
		local payload = {
			shuttle = chosen_shuttle,
			crewsheet = chosen_pilot,
			mission = { mission = _("Trade Mission"), ship = chosen_shuttle.ship, directive = "buy", target = command },
		}
		-- start the mission
		hook.timer(3 + 0.1 * (100 - officer.xp), "away_mission", payload)
	end )
	escort( function () return response end )
	vn.done()
	
	-- try to send the chief of security out to engage the active target
	vn.label("mission_engage")
	vn.func( function()


		local attacker = findCrewWithSkill(_("Chief of Security"))
		if not attacker then -- aww, no chief, look for an officer
			attacker = findCrewWithSkill(_("Security Officer"))
		end
		if not attacker then -- oh boy, looks like it's up to ME!
			attacker = officer
		end
		
		-- recruit a shuttle manager to prepare the shuttle and aggressively search for any usable auxiliary ship
		local shuttle_manager = findCrewWithSkill(_("Chief of Security")) or findManagerOfType( _("Shuttle") ) or  findCrewOfType( _("Pilot") )
		local chosen_shuttle = shuttle_manager.shuttle or officer.shuttle or mem.ship_interior.shuttle
		if not chosen_shuttle and not attacker.shuttle then
			response = _([[I wish I could help you, but I can't find a suitable auxiliary ship for that.]])
			return
		end

		-- check if we can undock this auxiliary ship
		if chosen_shuttle.ship:size() > math.floor(mem.ship_interior.bay_strength / 3) then
			response = fmt.f(_("The {name} isn't spaceworthy because it wouldn't fit in the docking bays. We need a bigger ship, more fighter bays or a smaller auxiliary ship."), { name = chosen_shuttle.ship:name() } )
			return
		end
		
		-- this is the mission payload
		local payload = { -- if the attacker has is own shuttle, use it, otherwise use the one we found
			shuttle = attacker.shuttle or chosen_shuttle,
			crewsheet = attacker,
			mission = { mission = "Active Combat", ship = chosen_shuttle.ship, directive = "engage", target = player.pilot():target() },
		}

		response = fmt.f(
			_([[Fair enough, the {ship} is being prepped as we speak. It's going to be a legendary {attacker} mission, or at least I hope so.]]),
			{
				ship = payload.shuttle.ship,
				attacker = pick_one({ attacker.skill, attacker.typetitle, attacker.name, player.ship() }),
			}
		)
		
		-- start the mission
		hook.timer(6 + 0.1 * (100 - officer.xp), "away_mission", payload)
	end )
	escort( function () return response end )
	vn.done()
	
	-- the ship is getting dirty and needs to be cleaned
	-- the player really wants to clean it
	vn.label("clean")
	vn.func( function ()
		player.pay(-management.cost)
		playMoney()
		-- figure out how well it gets cleaned
		-- summon all the non-senior staff for cleaning
		local sponge = 2 -- we get 2 from the officer
		for _i, worker in ipairs(mem.companions) do
			if
				string.find(worker.skill, _("Sanitation"))
				or string.find(worker.skill, (_("Janitor")))
			then
				-- all janitors get "motivated" regardless of satisfaction
				-- but the more experienced ones are much better
				sponge = sponge + worker.xp * 0.05 + rnd.rnd()
			elseif worker.skill == _("Cadet") then
				sponge = sponge + 0.5
			elseif worker.skill == _("Rookie") then
				sponge = sponge + 0.3 +  rnd.sigma()
			elseif worker.skill == _("Lieutenant") then
				sponge = sponge + 0.66
			end
		end

		-- cleaning isn't the same every time, and never perfect
		mem.ship_interior.dirt = math.max(
			mem.ship_interior.dirt - sponge,
			(sponge + mem.ship_interior.dirt) / (sponge * sponge)
		)
		
		print("cleaned ship to", mem.ship_interior.dirt)
		print("deteriation was", mem.ship_interior.dirt_accum)
		-- as a bonus, we re-calculate the dirt deteriation here
		takeoff()	
		print("deteriation is", mem.ship_interior.dirt_accum)
	end )
	
	vn.done()
	
	-- like end, but says the stored message
	vn.label("say_end")
	escort( function () return message end)
	vn.done()
	
	-- say goodbye
	vn.label("end")
	vn.func( function ()
		vn.textbox_font = textbox_font
	end )
	escort(pick_one(getConversation(officer).default_participation))
	vn.done()
	vn.run()
end

-- the player summoned a crew for promotion
-- the worker might not even be eligible for promotion
function startPromotionProcess( worker )
	-- ok we need to figure out what this worker can be promoted to
	-- for now lets keep it simple and just check if some canned options are taken
	local available_officers = {
		_("Sanitation"),
		_("Bridge"),
	}

	local keep	-- some types can always follow a path
	if worker.manager and worker.manager.type == _("Science") then
		-- if this is a scientist, let him promote to science officer
		available_officers = {}
		keep = _("Science")
	elseif worker.manager and worker.manager.type == _("Shuttle") then
		-- pilot can only become a 2nd, 3rd or unnumbered officer
		available_officers = { _("Second"), _("Third") }
		keep = pick_one( { _("Navigation"), _("Helm") } )
	elseif worker.typetitle == _("Engineer") then
		available_officers = { _("Chief Engineer") }
		keep = _("Engineer")
	elseif string.find(worker.skill,  _("Security")) then
		available_officers = { _("Chief of Security") }
		keep = _("Security")
	end
	
	for _n, other in ipairs(mem.companions) do
		if other.manager or string.find(other.skill, _("Officer")) then
			for ii, label in ipairs(available_officers) do
				if string.find(other.skill, label) then
					print(fmt.f("striking {label}", {label=label}))
					table.remove(available_officers, ii)
				end
			end
		end
	end

	if keep then
		table.insert(available_officers, keep)
	elseif #available_officers == 0 then
		-- some default name labels for redundant bridge officers
		table.insert(available_officers, _("Bridge"))
		table.insert(available_officers, _("Assistant"))
		table.insert(available_officers, _("Junior"))
	end
	
	local choices = {}
	local promotion
	if
		#available_officers > 0
		and worker.xp >= 98.5 -- to allow engineers to be promoted
		and (	-- types that can be promoted
			string.find(worker.skill, _("Lieutenant"))
			or string.find(worker.skill, _("Sanitation"))
			or string.find(worker.skill, _("Security"))
			or string.find(worker.typetitle, _("Engineer"))
		)
	then
		promotion = pick_one(available_officers)
		local choice_item = { fmt.f(_("Promote to {promotion} Officer"), { promotion = promotion } ), "promote" }
		table.insert(choices, choice_item)
	end

	-- cancel promotion (only choice if no options)
	table.insert(choices, { _("Nevermind"),  "end" })
	
	local message = fmt.f(_("Hey Captain {name}, what's up?"), FAKE_CAPTAIN)
	
	local vn_params = {image = worker.vncharacter }
	if mothership and mothership ~= player.ship() then
		vn_params.shader = love_shaders.hologram()
	end
	
	worker.vncharacter = portrait.getFullPath(worker.portrait)
	vn.clear()
	vn.scene()
	local escort = vn.newCharacter ( worker.name, vn_params )
	vn.transition()
	vn.label("start")
	vn.textbox_font = textbox_font

	escort(function() return message end)
	vn.menu(function () return choices end) -- makes us jump to a label

	vn.label("promote")
	vn.func( function()
		-- we assume promotion is not nil here!
		worker = promoteToOfficer(worker, promotion)
		message = fmt.f( pick_one({
		_("Wow! I can't believe that I'm a {typetitle} now! This has made my cycle -- truly!"),
		_("Wow, thanks! I can't believe that I'm a {skill} now! This has made my cycle -- truly!"),
		_("{typetitle} {skill} {firstname} {name}... I love it!!"),
		_("{typetitle} {skill} {name}... I love it!"),
		_("{typetitle} {name}... I love it!"),
		_("{skill} {name}... I love it!"),
		_("{typetitle} {firstname}, the {skill} on duty... That's me now!"),
		})
		, worker)
	end )
	vn.jump("say_end")
	vn.done()
	
	-- like end, but says the stored message
	vn.label("say_end")
	escort( function () return message end)
	vn.done()
	vn.label("end")
		vn.func( function ()
		vn.textbox_font = textbox_font
	end )
	escort(pick_one(getConversation(worker).default_participation))
	vn.done()
	vn.run()
end

-- TODO: fix this up so that you can open up a dialog and ask things
-- "How can I help you" -> choices -> default choices + open dialog
-- open dialog handler needs to somehow work generally
-- starts a managementarial discussion

return contract.capture {
	name = "management_discussions",
	requires = {
		"context", "content.character", "memory", "crew_factory",
		"crew_factory_officers", "crew_factory_npcs", "simulation", "management",
	},
	exports = { "startCommandDiscussion", "startPromotionProcess" },
}
