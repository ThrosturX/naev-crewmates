local fmt = require "format"
local lang = require "language.language"
local state = require "crewmates.state"
local hooks = require "crewmates.hooks"
local roster = require "crewmates.roster"
local contract = require "crewmates.module_contract"

function calculateBayStrength(cargo_workers)
	roster.calculate_bay_strength(mem, cargo_workers, player)
end
	
function create()
	state.initialize(mem, ship)
	shiplog.create(logidstr, _("Ship Companions"), _("Ship Companions"))
	npcs = {}
	hooks.create(mem)
	if player.isLanded() then
		hook.safe("land")
	end
end

function fixhooks()
	hooks.repair(mem)
end

-- Rebuild all ship state derived from the current crew roster. This deliberately
-- excludes event lifecycle work such as hook repair and preflight callbacks.
local function recalculate_ship_crew_state()
	local officers = {}		-- crew that unlock abilities/crew
	local champions = {}	-- crew with special skills
	champions.engineers = {}
	local workers = {}		-- general supporting crew
	workers.general = 0		-- bonus to various tasks
	workers.security = 0	-- something to do with defense when boarded?
	workers.pirates = 0		-- like security, but pirates
	workers.cargo = 0		-- increases smuggler's ship size (and bay strength as well)
	workers.maintenance = 0	-- gives engineer bonus
	workers.janitorial = 0	-- keeps ship clean
	local pirate_leader
	local max_crew = player.pilot():stats()["crew"]
	-- count crew types and record champions
	-- note that we only count the first hired crews that can fit
	-- just in case the player was in a large ship with a large crew
	-- but swapped into something small with less crew space
	for ii, crewmate in ipairs(mem.companions) do
		if ii <= max_crew then
			if crewmate.skill == _("Cargo Bay") then
				workers.cargo = workers.cargo + math.max(0.66, math.min(1.87, crewmate.xp * crewmate.satisfaction))
			elseif
				crewmate.skill == _("Maintenance")
				or string.find(crewmate.skill, _("Mechanic"))
			then
				workers.maintenance = workers.maintenance + math.max(0.66, math.min(1.87, crewmate.xp * crewmate.satisfaction))
			elseif
				string.find(crewmate.skill, _("Sanitation"))
				or string.find(crewmate.skill, (_("Janitor")))
			then
				-- janitors can be extremely effective or extremely ineffective
				workers.janitorial = workers.janitorial + math.max(0.25, math.min(3.75, crewmate.xp * crewmate.satisfaction))
			elseif	 -- if we look like a pirate, we're coming with security crew
				string.find(crewmate.skill, _("Security"))
				or string.find(crewmate.skill, _("Pira"))
			then
				-- security crew count as much as they can contribute to boarding
				workers.security = workers.security + math.max(0.2, math.abs(crewmate.xp * 0.08 + crewmate.satisfaction * 0.02))
				-- security crew makes a big mess, especially when inexperienced
				workers.janitorial = math.max(0, workers.janitorial - 0.01 * (136 - crewmate.xp))
			-- assign "generality" usefulness based on rank if unspecialized
			elseif string.find(crewmate.typetitle, _("Passenger")) then
				-- passengers try to help, but are mostly useless
				workers.general = workers.general + 0.02
				workers.janitorial = workers.janitorial + 0.03
			elseif string.find(crewmate.skill, _("Rookie")) then
				workers.general = workers.general + 0.12
				-- we don't have any skills, so we clean as well
				workers.janitorial = workers.janitorial + 0.1
			elseif string.find(crewmate.skill, _("Cadet")) then
				workers.general = workers.general + 0.25
				workers.janitorial = workers.janitorial + 0.02
			elseif string.find(crewmate.skill, _("Ensign")) then
				workers.general = workers.general + 1
				workers.janitorial = workers.janitorial + 0.06
			elseif string.find(crewmate.skill, _("Lieutenant")) then
				workers.general = workers.general + 0.5
				-- we are responsible lieutenants and like to keep things clean
				workers.janitorial = workers.janitorial + 0.2
			end
		end

		-- find pirates
		if string.find(crewmate.skill, _("Pira")) then
			workers.pirates = workers.pirates + 1
			if
				string.find(crewmate.skill, _("Leader"))
				or string.find(crewmate.skill, _("Janitor"))
			then
				-- this is a pirate leader, he cleans up after his dirty crew, or makes things worse!
				workers.janitorial = workers.janitorial + crewmate.xp * 0.02 * crewmate.satisfaction
				if not pirate_leader or crewmate.xp > pirate_leader.xp then
					pirate_leader = crewmate
				end
			end
		end
		
		-- find officers (can own shuttles)
		if string.find(crewmate.skill, _("Officer"))
			or string.find(crewmate.typetitle, _("Chief"))
			or string.find(crewmate.typetitle, _("Commander"))
		then
			officers[crewmate.skill] = crewmate
		end
		-- record champions
		if crewmate.typetitle == _("Engineer") then
			if string.find(crewmate.skill, "Explosive") then
				champions.demoman = ii
			else
				table.insert(champions.engineers, crewmate)
			end
		elseif string.find(crewmate.typetitle, _("Scien")) then
			champions.scientist = ii
		elseif crewmate.typetitle == _("Pilot") then
			champions.pilot = crewmate -- not sure about this yet
		elseif crewmate.typetitle == _("Smuggler") then
			champions.smuggler = ii
		elseif crewmate.typetitle == _("Companion") then
			champions.escort = ii
		end
		crewmate.bonus = 0
	end
	
	-- assign bonuses
	-- smugglers benefit from cargo bay workers
	if champions.smuggler then
		mem.companions[champions.smuggler].bonus = workers.cargo
	end
	-- engineers benefit from maintenance workers
	for _i, engineer in ipairs(champions.engineers) do
		engineer.bonus = workers.maintenance
	end
	SHIP_ENGINEERS = champions.engineers
	-- one scientist benefits from general workers
	if champions.scientist then
		mem.companions[champions.scientist].bonus = workers.general * 0.2
	end
	
	-- we have a pirate leader or at least someone who cleans up after them, give some bonuses here
	if pirate_leader then
		-- if the leader is stronger than the janitor (in case of 2)
		if pirate_leader.skill:find(_("Leader")) then
			workers.security = workers.security * 1 + 0.01 * pirate_leader.xp + pirate_leader.satisfaction * 0.1
		else	-- give cleaning bonus instead
			workers.janitorial = workers.janitorial * 1 + 0.01 * pirate_leader.xp + pirate_leader.satisfaction * 0.1
		end
	end
	
	-- Clear the previous takeoff's plugin contributions before applying current
	-- officer bonuses. Resetting after sanitation erased its crew-space bonus.
	player.pilot():intrinsicReset()

	local sanitation_officer = officers[_("Sanitation Officer")]
	if sanitation_officer then
		-- strength from xp is shared with the subordinates (and the last term is the officer himself)
		workers.janitorial = workers.janitorial * 1 + 0.01 * sanitation_officer.xp + sanitation_officer.satisfaction * 0.1			-- also enlists and trains some regular crew
		workers.janitorial = workers.janitorial + 0.06 * workers.general
		-- janitorial officer can organize janitorial crew into bunks
		player.pilot():intrinsicSet("crew", math.floor(0.03 * sanitation_officer.xp * workers.janitorial))
	end
	
	-- A chief security officer acts as a multiplier for workers.security based on xp
	local security_officer = officers[_("Chief Security Officer")]
	if security_officer then
		-- strength from xp is shared with the subordinates (and the last term is the officer himself)
		workers.security = workers.security * 1 + 0.01 * security_officer.xp + security_officer.satisfaction * 0.1
		-- also enlists and trains some regular crew
		workers.security = workers.security + 0.06 * workers.general
		-- security officer can organize security crew into bunks
		player.pilot():intrinsicSet("crew", math.floor(0.03 * security_officer.xp * workers.security))
	end
	
	-- loot mod affected by security crew
	player.pilot():intrinsicSet("loot_mod", workers.security)
	
	-- calculate bay strength in case we have a shuttle crew
	calculateBayStrength( workers.cargo )
	
	print("effective bay strength: " .. tostring(mem.ship_interior.bay_strength))
	SHIP_OFFICERS = officers
	local limits = merge_tables({}, START_CREW_LIMITS)
--	print("limit calculation")
	-- calculate limits based on officers
	for otype, officer in pairs(officers) do
		-- find limit in title, like "Chief of Science", or "Chief Engineer" or "Science Officer" I guess
		for limited, limit in pairs(limits) do
			if string.find(otype, limited) then
				limits[limited] = limits[limited] + 1
			end
		end	
		
		if string.find(otype, _("Science Officer")) then
			-- clamp science officers at 3
			if limits[limited] then
				limits[limited] = math.min(3, limits[limited])
			end
		end

		if string.find(otype, _("First Officer")) then
			-- unlock first officer abilities
			-- earn 2 of every limited type
			for limited, limit in pairs(limits) do
				limits[limited] = limits[limited] + 2
			end
			-- custom maximums for first officer
			limits[_("Rookie")] = 6
			limits[_("Cadet")] = 12
			limits[_("Ensign")] = 8
			limits[_("Lieutenant")] = 6
			limits[_("Passenger")] = 8
			limits[_("First Officer")] = 1 -- keep this at 1
			-- ship uses the first officer's shuttle
			mem.ship_interior.shuttle = officer.shuttle
		end
	end
	
	if pirate_leader then
		limits[_("Pirate")] = 16	-- I don't know what "lots of pirates" means, but I reckon 16 is a good starting amount, for more you'd need to promote security crew to officers
	end
	SHIP_CREW_LIMITS = limits
	
	for k , v in pairs(SHIP_CREW_LIMITS) do
		print(fmt.f("Limit {k:16s} is\t{v}", {k=k, v=v}))
	end

	-- calculate ship cleanliness deteriation
	-- we need about 16% of the crew to be cleaning up on average
	-- general duty workers contribute 10% as much as a janitor regardless of satisfaction
	-- but janitors' effectiveness heavily depends on satisfaction
	-- so if you hire a lot of general duty workers, you can offset unhappy janitors a bit
	local janitors_needed =  math.ceil(math.min(#mem.companions * 0.168 + 0.75, max_crew * 0.16))
	local effective_janitors = math.ceil(0.01 + workers.janitorial + (0.5 * workers.general))
	if effective_janitors < janitors_needed then
		-- ship is going to get dirtier
		mem.ship_interior.dirt_accum = ((janitors_needed * 2) / (workers.janitorial + 1 + janitors_needed))
		mem.ship_interior.dirt = math.max(#mem.companions, mem.ship_interior.dirt)
	else -- try to clean the ship up a bit, keep things tidy
		mem.ship_interior.dirt_accum = -0.1 * effective_janitors - 0.33 * workers.janitorial
		mem.ship_interior.dirt = math.min(#mem.companions, mem.ship_interior.dirt)
	end
	print(fmt.f("There are {ej:.2f}/{need} effective janitors and ", { ej = effective_janitors, need = janitors_needed }) .. fmt.f("dirt is at {dirt:.1f} (accum at {dirt_accum:.2f})", mem.ship_interior ))
end

-- calculate any bonuses that we might want to calculate
function takeoff()
	mem.last_system = system.cur()
	if mem.crewmates_joyride then
		return
	end
	print("regular takeoff")
	fixhooks()
	mothership = player.ship()

	-- END QUICKFIX SECTION

	-- start by checking if we want to alter our crew before assembling the roster
	-- shuffle crew if necessary
	local first_officer = SHIP_OFFICERS[_("First Officer")]
	if first_officer then
		firstOfficerPreflight( first_officer )
	end

	recalculate_ship_crew_state()
end

function land()
	hooks.refresh_external_commander(mem)
	seedQaFixture(mem)
	if mem.crewmates_joyride then
		return
	end
	-- we are landed in our mothership
	if mem.fatigue_hook then
		-- not getting fatigued now
		hook.rm(mem.fatigue_hook)
		mem.fatigue_hook = nil
        print("reset mothership")
		mothership = player.ship()
	end
	
	
	clearCommanderInterface()
	npcs = {}
	local paid = {}
	local payroll
	local loads = 0
	for i, edata in ipairs(mem.companions) do
		-- create stuff if we have to now so that we don't have to do it in space
		if loads < 3 and not LOADED[edata.name] then
			loadCrewmate(i)
			loads = loads + 1
		end
		-- natural satisfaction adjustment gravitates towards zero and adds
		-- a little bit of randomness based on how smooth the landing was or whatever
		local sss = math.max(-10, math.min(10, edata.satisfaction))
		edata.satisfaction = math.floor(10 * (sss - (sss / 12))) / 10 + 0.01 * rnd.threesigma()
		
		-- incurr any necessary commodity costs if we have the possibility to "restock"
		if edata.other_costs then
			-- see if this is a commodity we can buy here
			local available_comms = spob.cur():commoditiesSold()
			for _i, ccom in ipairs(available_comms) do
				local name = ccom:name()
				-- don't pay for things we have on board, as a bonus
				if name == edata.other_costs and not player.pilot():cargoHas(name) then
					-- make the player pay the cost of 1/10th of a ton, which should be enough to last until we land again
					local price = math.ceil(ccom:priceAt(spob.cur()) / 10)
					player.pay(-price)
					-- do some bookkkeeping in case we have a manager
					local prev_paid = paid[name]
					if prev_paid == nil then
						prev_paid = 0
					end
					paid[name] = prev_paid + price
				end
			end
		end

		-- dock any missing smuggler shuttles
		if edata.shuttle and string.find(edata.skill, _("Smuggler")) then
			edata.shuttle = { } 
		end
		
		if edata.away and not edata.away.ship then
			-- come back from break
			edata.away = nil
		end
		
		-- if we don't have a manager that called us, some crew doesn't go to the bar
		-- chance of being elsewhere depends on xp and crew size
		local elsewhere_chance =
			(#mem.companions - edata.satisfaction) / (edata.xp + #mem.companions + math.abs(edata.satisfaction))
		if edata.manager then
			if edata.manager.type ~= _("Science") then
				elsewhere_chance = 0
			end
			if edata.manager.skill == "payroll" then
				payroll = edata
			end
		end -- don't let managers go on holiday unless they are scientists
		if
			mem.summon_crew
			or rnd.rnd() > elsewhere_chance
			or (edata.manager and edata.manager.type ~= _("Science"))
		then
			-- add the npc and figure out what he's doing
			local doing = getBarSituation(edata) .. "."
			local description =
				fmt.f(_("This is {typetitle} {firstname} {name}, designation {skill}. It seems that {article_subject} is "), edata) ..
				doing
			-- put ship crew at the bottom unless it's important management crew
			local priority = 10
			if edata.manager then
				priority = 6
			end
			local id = evt.npcAdd("approachCompanion", edata.name, edata.portrait, description, priority)
			npcs[id] = edata
		end
	end

	-- if we just summoned the crew, don't do it again next time
	mem.summon_crew = nil

	if #mem.companions <= 0 then
		evt.save(false)
	end

	-- Ignore on uninhabited and planets without bars
	local pnt = spob.cur()
	local services = pnt:services()
	local flags = pnt:flags()
	if not services.inhabited or not services.bar or flags.nomissionspawn then
		return
	end

	
	-- if we didn't pay salaries yet, do it now
	-- also: captain makes mistakes: paid = salary - salary * (rnd.twosigma() + rnd.rnd())
	-- and underpaid crew becomes unhappy and retain a memory (cap'n bad at maths) and get a sentiment (cap'n underpaid me)

	-- the captain pays salaries (incorrectly unless someone is working on payroll)
	for _i, crewmate in ipairs(mem.companions) do
		if crewmate.salary > 0 then
			-- estimate an incorrect salary but allow captain's interactions with crew to affect it
			local estimated = crewmate.salary + crewmate.salary * (rnd.twosigma() + rnd.rnd() + rnd.rnd()) + FAKE_CAPTAIN.xp * FAKE_CAPTAIN.satisfaction
			if payroll then -- fix the captain's mistakes and earn xp
				estimated = crewmate.salary
				payroll.xp = math.min(100, payroll.xp + 0.01)
			end

			if not crewmate.last_paid then
				crewmate.last_paid = time.cur()
			else
				local dt = time.cur() - crewmate.last_paid
				if dt > time.new(0, 15, 0) then
					if estimated < crewmate.salary then
						-- the crewmate is unhappy and loses experience
						-- (gets demotivated, hopefully we get it back with the paycheck)
						create_memory(crewmate, "underpaid")
						crewmate.satisfaction = crewmate.satisfaction - 0.01
						crewmate.xp = math.max(0, crewmate.xp - 0.5)
						insert_sentiment(crewmate, _("The captain miscalculated my salary."))
					else
						-- random salary happiness bonus
						crewmate.satisfaction = crewmate.satisfaction + rnd.rnd()
						-- did this paycheck come with a promotion?
						-- we can get promoted to lieutenant at most here
						local promotion = get_promotion(crewmate)
						if promotion then
							crewmate.skill = promotion
							crewmate.xp = 1 -- reset xp so we don't get double promotion!
						end
					end
					local salary_resolution = time.new(0, 32, 0)
					local multiplier = dt:tonumber() / salary_resolution:tonumber()
					local calculated = estimated * multiplier
					local ttpaid = paid[crewmate.typetitle] or 0
					paid[crewmate.typetitle] = ttpaid + calculated -- bookkkeeping
					player.pay(-calculated)	-- player pays the crewmate
					crewmate.last_paid = time.cur()
					--[[ we got paid, earn a random amount of experience
						and some experience based on our mood strength
						this makes negative nancies better at earning XP and
						positive patties much better at earning XP
						but the more salary you get, the less experience you gain from satisfaction
						and so in a way we treat [0-1] as depression to stable with 1 as stable and 
						anything else as a positive or negative mood ranging from mild to mania
						but this makes sure that TROUBLEMAKERS and PROMISING crew stand out a bit more
						and pushes "boring", stable crew to earn xp more slowly as you would expect IRL (not ambitious)
					--]]
					crewmate.xp = crewmate.xp + rnd.rnd() + math.abs(
						math.max(-3, crewmate.satisfaction * rnd.rnd())
					) / (math.max(1, calculated))
				end
			end
		end
	end
	
	print("paid salaries")

	-- pay for any other incurred costs
	for item, cost in pairs(mem.costs) do
		player.pay(-cost)
		paid[item] = cost
		mem.costs[item] = 0
	end

	-- if we have a manager, give him the data here
	-- could be used to figure out what crew is dead weight etc
	-- so the conversation/dialog uses the paid table as a base
	for _i, crewmate in ipairs(mem.companions) do
		if crewmate.manager then
			-- check if the manager has the finance skill
			if crewmate.manager.skill == "finance" then
				crewmate.manager.paid = paid
			end
		-- check for some other skills / data
		end
	end

	
	local total_paid = 0
	for _item, ppaid in pairs(paid) do
		total_paid = total_paid + ppaid
	end
	if total_paid > 0 then
		shiplog.append(
			logidstr,
			fmt.f(
				_("You paid {credits} in crew salaries and other costs."),
				{
					credits = fmt.credits(total_paid)
				}
			)
		)
	end

	-- Create NPCs for pilots you can hire.
	createCrewmateNPCs()
end

function enter()
	-- if escorts are disabled, our companions are sleeping
	if var.peek("hired_escorts_disabled") then
		return
	end
	mem.last_system = system.cur()
	if mem.crewmates_joyride then
		return
	end
	mothership = player.ship()
	joyride_commander = nil
	
	if #mem.companions == 0 then
		return
	end

	-- start a conversation
	hook.rm(mem.conversation_hook)
	mem.conversation_hook = hook.timer(rnd.rnd(10, 30), "start_conversation")

	local loads = 0
	for i, companion in ipairs(mem.companions) do
		-- reset any hooks
		register_hook_crewmate(companion)
		-- load unloaded crew
		if loads < 3 and not LOADED[companion.name] then
			loads = loads + 1
			loadCrewmate(i)
		end
	end

	-- set the fatigue hook
	hook.rm(mem.fatigue_hook)
	mem.fatigue_hook = hook.date(time.new(0, 2, 0), "period_fatigue", nil)
end

function register_hook_crewmate( crewmate )
	if crewmate.hook and crewmate.hook.func then
		-- remove old hook
		if crewmate.hook.hook then
			hook.rm(crewmate.hook.hook)
			crewmate.hook.hook = nil
		end
		-- register new hook
		crewmate.hook.hook = entries[crewmate.hook.func](crewmate)
	end
end

-- TODO: this should take a batch of crewmembers, to make it seem like they are on shifts
-- a period passes in space and the crew feels fatigued
-- dirt accumulates in the ship
-- and maybe some science project progress is updated
function period_fatigue()
	-- check if its safe to update the mothership and recalculate values
	if mem.ship_interior.shuttle and not mem.ship_interior.shuttle.out then
		recalculate_ship_crew_state()
		mothership = player.ship()
	end
	-- calculate natural dirt accumulation
	mem.ship_interior.dirt = math.max(0, mem.ship_interior.dirt + mem.ship_interior.dirt_accum)
--	print("dirt is and grows by", mem.ship_interior.dirt, mem.ship_interior.dirt_accum)
	
	-- only one crewmate can get hysteria per period
	local hysteria = false
	local travel_memories = 0
	-- calculate how each crew member is affected by the time that passed
	for _i, companion in ipairs(pick_some(SHIFT_DUTY, 4)) do
		-- calculate ship atmosphere interaction
		-- how occupied this worker was on this pass (busy or restless)
		local occupation = 0
		-- do I think that this area is dirty?
		if mem.ship_interior.decoration then
			occupation = 1
			-- there are nice decorations here, don't notice any dirt
			if not companion.item and rnd.rnd(0, 6) == 0 then
				-- I can take this item and put it on my person to use next period
				occupation = occupation + 1
				if evaluate_item_haste(companion, mem.ship_interior.decoration) > 0.25 then
					-- I want this item and I think I'll take one
					companion.item = mem.ship_interior.decoration
					companion.xp = companion.xp + 0.01 -- I showed initiative and took something I wanted
					occupation = occupation * 2
					if rnd.rnd(0, #mem.companions * 3) < mem.ship_interior.decoration:len() then
						-- I took the last item
						mem.ship_interior.decoration = nil
						occupation = occupation * 2
					end
				end
			end
		elseif mem.ship_interior.dirt > 4 * rnd.rnd() * player.pilot():ship():size() then
			companion.satisfaction = companion.satisfaction - 0.003 * mem.ship_interior.dirt
			occupation = occupation + 1
			if mem.ship_interior.dirt > 64 * rnd.rnd() + companion.chatter then
				-- TODO: generate "it's dirty here" speeches
				insert_sentiment(companion, _("This ship is filthy."))
				occupation = occupation + 3
			end
		end
		
		-- do I have an item that will make me happy?
		if companion.item then
			-- use this item soon
			hook.timer(rnd.rnd(3, 196), "crewmate_use_item", companion)
			occupation = occupation + 2
			companion.satisfaction = companion.satisfaction + 0.06 -- having expectations
		-- are we out of food and water?
		elseif rnd.rnd(0, 3) == 0 and not (player.pilot():cargoHas("Food") or player.pilot():cargoHas("Water")) then
			insert_sentiment(companion, _("I'm getting hungry."))
			insert_sentiment(companion, _("I'm so thirsty."))
			companion.satisfaction = companion.satisfaction - 0.05
			occupation = occupation + companion.satisfaction
		end

		-- calculate fatigue and hysteria chances
		
		-- every experience point will give the crewmate 1% chance to resist fatigue
		-- every satisfaction point will contribute another 1% positively or negatively
		if rnd.rnd(0, 100 - occupation) > companion.xp + companion.satisfaction then
			companion.satisfaction = companion.satisfaction - 0.01
			-- if we are a big chatter we might express ourselves about this later
			if rnd.rnd() < companion.chatter then
				local last_sentiment = companion.conversation.sentiment
				companion.conversation.sentiment = pick_one(getConversation(companion).fatigue)
				-- if it's the same sentiment, blurt it out soon
				-- with some resistance provided by chatter and xp
				-- but no resistance if we are unhappy
				if
					companion.conversation.sentiment == last_sentiment 
					and companion.satisfaction + 0.01 * companion.xp <	companion.chatter * rnd.rnd()
				then
					hook.timer(7 + rnd.rnd(3, 25), "say_specific", {me = companion, message = last_sentiment})
					companion.conversation.sentiment = nil
				end
			end
		elseif rnd.threesigma() > 2.66 and not hysteria and LOADED[companion.name] then
			-- we get a mild case of space hysteria that affects us more the more experienced we are
			companion.satisfaction = companion.satisfaction - companion.xp / (companion.xp + 6)
			print(fmt.f("{name} has hysteria.", companion))
			-- give this crewmate an aptly timed personality trim
			pruneCrewMate( companion )

			-- ramble at some victim (could be ourselves, especially on small crews)
			local victim = getCrewmateOnboard()

			-- start rambling about something
			local ramblings

			if rnd.rnd(0, 1) == 0 and travel_memories < 1 then
				-- we get lucky, we realize we're just tired, but we're still going to ramble
				ramblings = pick_one(getConversation(companion).fatigue)
				-- create a random memory about this scary place
				create_memory(companion)
			else
				-- decide how to ramble
				if rnd.rnd(0, 1) == 0 then
					-- we'll call the victim bad company for no reason
					ramblings = fmt.f(pick_one(getConversation(companion).bad_talker), victim)
				else -- oh we're really gonna ramble
					if rnd.rnd(0, 1) == 0 then
						-- we'll pick anything from our special choices and just say that
						ramblings = add_special(companion)
					else -- be a little more incoherent than usual
						ramblings = add_special(companion) .. " " .. lang.getMadeUpName() .. " " .. add_special(companion)
					end
					-- just in case we got no specials for some reason
					if ramblings:len() == 0 or rnd.threesigma() > 2 then
						ramblings = fmt.f(_("This voyage is driving me {made_up} crazy."), {made_up = lang.getMadeUpName()})
					end
				end
				-- experience melancholia too because we later learn how incoherent we were
				companion.satisfaction = companion.satisfaction - 1
				-- at this point, it's safe to say one of the crewmates is experiencing hysteria, don't add any more
				hysteria = true
				-- create a random memory but supplying some completely incorrect parameters
				local params = {
					system = lang.getMadeUpName(),
					target = lang.getMadeUpName(),
					credits = fmt.credits(-rnd.rnd(3e3, 7e4)),
					armour = rnd.rnd(44, 132),
					ship = getRandomShip()
				}
				create_memory(companion, "hysteria", params)
			end

			-- set the sentiment so that we'll tell it to someone
			companion.conversation.sentiment = ramblings
			-- start talking to the victim (remember, could be ourselves, and we could start a conversation with ourselves)
			speak(companion, victim)
		elseif rnd.rnd(0, 27) == 0 and travel_memories < 1 and not hysteria then -- control for creating random travel memories
			create_memory(companion)
		end
	end

	-- does the decorative item lose its charm?
	--if math.abs(rnd.threesigma()) > 2.7 then -- TODO depercate in steps by adding "bad" adjectives like "old", "worn"
	if mem.ship_interior.decoration then
		if not mem.ship_interior.decoration_locked and rnd.twosigma() > 1.75 then
			-- this item becomes dated or nasty
			local picked = pick_one(join_tables(lang.getAll(lang.adjectives.negative.dated), lang.getAll(lang.adjectives.negative.nasty)))
			mem.ship_interior.decoration_locked = pick_one(lang.getAll(lang.adjectives.negative.smelly))
			-- so we now get something "smelly old apple" or "pungent rotten banana"
			mem.ship_interior.decoration = mem.ship_interior.decoration_locked .. " " .. picked .. " " .. mem.ship_interior.decoration
		end
		-- this was the last one, notice how unlikely it is to take the last negatively adorned item
		if rnd.rnd(0, mem.ship_interior.decoration:len()) < 1 then
			mem.ship_interior.decoration = nil
			mem.ship_interior.decoration_locked = nil
		end
	end
	
	local next_fatigue = rnd.rnd(7500, 9950)
	-- set the next period fatigue timer
	hook.rm(mem.fatigue_hook)
	mem.fatigue_hook = hook.date(time.new(0, 1, next_fatigue), "period_fatigue", nil)
end

return contract.capture {
	name = "simulation",
	requires = {
		"context", "content.random", "content.character", "memory",
		"conversation_runtime", "crew_factory_npcs", "qa_fixture",
	},
	exports = {
		"calculateBayStrength", "create", "fixhooks", "takeoff", "land", "enter",
		"register_hook_crewmate", "period_fatigue",
	},
}

-- remove the crewmember from the ship
