local fmt = require "format"
local pir = require "common.pirate"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function createCrewmateNPCs()
	local fac = spob.cur():faction()

	if spob.cur():tags().nonpc then
		return
	end

	if fac == nil then
		return
	end

	local patrons = {
		_("Patron"),
		_("Bar Patron"),
		_("Ship Worker"),
		_("Dock Worker"),
		_("Avid Talker"),
		_("Civilian"),
		fmt.f(_("{faction} Civilian"), {faction = fac}),
		_("Worker"),
		_("Drunkard"),
		_("Anxious Person"),
		_("Shady Individual")
	}
	
	local presentable = {
		_("Attractive {gender}"),
		_("Presentable {gender}"),
		_("Eyecatching {gender}"),
		_("{gender} {typetitle}"),
		_("Obvious {skill}"),
	}
	
	
	-- the generic crew and passengers disguised as patrons
	for _i=1, rnd.rnd(5, 8) do
		if rnd.rnd(1, 5) == 3 then
			local crewmate = createGenericCrewmate()
			local id =
				evt.npcAdd(
				"approachGenericCrewmate",
				pick_one(patrons),
				crewmate.portrait,
				fmt.f(
					_(
						[[This person seems to be looking for work, but there are no obvious details as to what they can do.]]
					),
					crewmate
				),
				9
			)

			npcs[id] = crewmate
		end
		if rnd.rnd(1, 10) == 1 then
			local crewmate = createPassenger()
			local id =
				evt.npcAdd(
				"approachGenericCrewmate",
				fmt.f(_("{adjective} {patron}"), {adjective = pick_one(lang.getAll(lang.adjectives.violent)), patron = crewmate.skill}):gsub("^%l", string.upper),
				crewmate.portrait,
				fmt.f(
					_(
						[[This person seems to be looking for something, but there are no obvious details as to what.]]
					),
					crewmate
				),
				9
			)

			npcs[id] = crewmate
		end
	end
	

	-- the first officer, quite rare
	if rnd.rnd(1, 21) == 21 then
		local crewmate = createFirstOfficer()
		local id =
			evt.npcAdd(
			"approachGenericCrewmate",
						fmt.f(pick_one(presentable), crewmate),
			crewmate.portrait,
			[[This person seems to be ]] .. getBarSituation(crewmate) ..
				fmt.f(
				_([[, perhaps you should go talk to {article_object}.]]),
				crewmate
			),
			5
		)

		npcs[id] = crewmate
	end
	
	-- the morale officer or the random scientist
	if rnd.rnd(1, 8) == 7 then
		local crewmate = createMoraleOfficer()
		local id =
			evt.npcAdd(
			"approachGenericCrewmate",
			pick_one(patrons),
			crewmate.portrait,
			fmt.f(
				_(
					[[This person seems to be looking for work, but there are no obvious clues as to what they can do other than an extruding cheerfulness that can perhaps be described as jolly.]]
				),
				crewmate
			),
			9
		)

		npcs[id] = crewmate
	elseif rnd.rnd(1, 6) == 2 then
		local crewmate = createScienceFarmer()
		local id =
			evt.npcAdd(
			"approachGenericCrewmate",
			_("Scientist"),
			crewmate.portrait,
			fmt.f(
				_(
					[[This person walks, talks and looks like a scientist.]]
				),
				crewmate
			),
			7
		)

		npcs[id] = crewmate
	end
	
	-- the ship psychologist
	if rnd.rnd(1, 13) == 13 then
		local crewmate = createPsychologistManager()
		local id = 
			evt.npcAdd(
			"approachGenericCrewmate",
			fmt.f(pick_one(presentable), crewmate),
			crewmate.portrait,
			[[This person seems to be ]] .. getBarSituation(crewmate) ..
				fmt.f(
				_([[, perhaps you should go talk to {article_object}.]]),
				crewmate
			),
			6
		)
		
		npcs[id] = crewmate
	end
	
	-- the generic manager disguised as a patron
	if rnd.rnd(1, 13) == 7 then
		local crewmate = createGenericManager()
		local id =
			evt.npcAdd(
			"approachGenericCrewmate",
			pick_one(patrons),
			crewmate.portrait,
			fmt.f(
				_(
					[[This person seems to be looking for work, but there are no obvious clues as to what they can do.]]
				),
				crewmate
			),
			9
		)

		npcs[id] = crewmate
	end
	
	-- special pirate world spawns
	if pir.factionIsPirate(fac) then
		-- the smuggler
		if rnd.rnd(0,6) >= 5 and spob.cur():services().commodity then
			-- TODO: only if this place sells commodities
			local crewmate = createSmuggler()
			local id =
				evt.npcAdd(
				"approachGenericCrewmate",
				pick_one(patrons),
				crewmate.portrait,
				fmt.f(
					_(
						[[This person seems to be looking for work, but there are no obvious details as to what they can do.]]
					),
					crewmate
				),
				8
			)
			npcs[id] = crewmate
		elseif rnd.rnd(1, 5) == 2 then
			-- a pirate pilot, what are you doing here?
			local crewmate = createShuttlePilot(fac)
			local id =
				evt.npcAdd(
				"approachGenericCrewmate",
				pick_one(patrons),
				crewmate.portrait,
				fmt.f(
					_(
						[[This person seems to be looking for work with extruding confidence, looking poised to tell a story or seven.]]
					),
					crewmate
				),
				6
			)
			npcs[id] = crewmate
		else
			-- some extra security crew
			for _i=1, rnd.rnd(1, 6) do
				local crewmate = createGenericCrewmate()
				crewmate.skill = pick_one( {
					_("Security"),	-- promotable
					_("Pirate"),	-- custom limits
					-- specialists or other "happenstance" crew opportunities (one of each)
					_("Piracy Expert"),
					_("Pirate Negotiator"),
					_("Pirate Leader"),		-- secret officer
					_("Retired Pirate"),	-- possible secret officer
					_("Pirate Mechanic"),	-- 2 in 1 crew - bonus to maintenance (engineers)
					_("Pirate Janitor"),	-- 2 in 1 crew
					_("Junior Pirate"),		
				} )
				if
					string.find(crewmate.skill, _("Pira"))
					and crewmate.skill ~= _("Pirate")
				then
					crewmate.typetitle = _("Specialist")
				end
				-- special secret first officer pirate leader
				if
					crewmate.skill == _("Pirate Leader")
				then
					crewmate = createPirateOfficer(crewmate)
				end
				local id =
					evt.npcAdd(
					"approachGenericCrewmate",
					pick_one(patrons),
					crewmate.portrait,
					fmt.f(
						_(
							[[This person seems to be looking for work, by the looks of it, they're asking for trouble.]]
						),
						crewmate
					),
					9
				)

				npcs[id] = crewmate
			end
		end
	end
	
	-- the standard pilot spawn
	if rnd.rnd(0, 4) == 0 and (r == 0 or not pir.factionIsPirate(fac) ) then
		local crewmate = createShuttlePilot(fac)
		local id =
			evt.npcAdd(
			"approachGenericCrewmate",
			pick_one(patrons),
			crewmate.portrait,
			fmt.f(
				_(
					[[This person seems to be looking for work, but there are no obvious details as to what they can do other than a noticeable air of confidence.]]
				),
				crewmate
			),
			6
		)
		npcs[id] = crewmate
	end
	
	-- the special science crew and the companion
	local r = rnd.rnd(0, 6)
	-- the engineer, more than twice as likely on zalek worlds
	if r == 2 or (fac == faction.get("Za'lek") and r == 4) then
		local character = createEngineer()

		local id =
			evt.npcAdd(
			"approachGenericCrewmate",
			character.typetitle,
			character.portrait,
			fmt.f(
				_(
					[[This engineer seems to be looking for work.

		Name: {name}
		Post: {typetitle}
		Expertise: {skill}
]]
				),
				character
			),
			7
		)

		npcs[id] = character
	end
	
	-- zaleks get extra scientists
	if fac == faction.get("Za'lek") and r <= 3 then
		local character
		local approachFunc = "approachGenericCrewmate"
		if r == 1 then
			character = createExplosivesEngineer(fac)
			approachFunc = "approachDemolitionMan"
		elseif r == 3 then
			character = createEngineer(fac)
		else
			character = createScienceFarmer(fac)
		end
		local id =
			evt.npcAdd(
			approachFunc,
			character.typetitle,
			character.portrait,
			fmt.f(
				_(
					[[This scientist seems to be looking for work.

		Name: {name}
		Post: {typetitle}
		Expertise: {skill}
]]
				),
				character
			),
			7
		)
		npcs[id] = character
	end

	-- the companion escort, rare but less rare on criminal worlds
	if r == 4 and rnd.rnd(0, 1) == 1 or spob.cur():tags().criminal and r == 0 then
		local character = createEscortCompanion()
		character.faction = fac
		character.chatter = 0.5 + rnd.threesigma() * 0.1 -- how likely I am to talk at any given opportunity
		character.deposit = math.ceil(200e3 * character.xp + 35e3 * character.satisfaction)
		character.salary = 0 -- credits per cycle? sure.. credits per cycle.
		character.other_costs = "Luxury Goods" -- pay for 100 kg every time you land unless you have it on board

		local id =
			evt.npcAdd(
			"approachEscortCompanion",
			character.typetitle,
			character.portrait,
			fmt.f(
				_(
					[[This person seems charming and charismatic. You get the feeling that you're about to be pursuaded into some business. Perhaps you should strike up a conversation?

		Name: {name}
		]]
				),
				character
			),
			7
		)

		npcs[id] = character
	end
end

function getCrewSheet(crewmate)
	if not crewmate.last_paid then
		crewmate.last_paid = time.cur()
	end
	crewmate.salary_fmt = fmt.credits(crewmate.salary)
	local sheet = _([[
{typetitle}
{name},		{firstname}

Assignment:		{skill}
Experience:		{xp:.0f}
Salary 32p:		{salary_fmt}
]])
	
	if crewmate.away then
		sheet = fmt.f(_([[		CURRENT STATUS:		 AWAY
Mission: {mission}
Ship:	 {ship}
]]), crewmate.away) .. sheet
	end
	
	if crewmate.manager then
		if not string.find(crewmate.skill, _("Officer")) then
		sheet = fmt.f(_([[{type} Manager
			
	]]), crewmate.manager):upper() .. sheet
		end
		if crewmate.manager.skill then
			sheet = sheet .. fmt.f(_([[Other skills: {skill}
]]), crewmate.manager)
		end
	end
	if crewmate.shuttle then
		sheet = sheet .. fmt.f(_([[Shuttle:		{name}]]), { name = crewmate.shuttle.ship })
		if crewmate.shuttle.out then
			sheet = sheet .. _("\t[MISSING]")
		end
		sheet = sheet .. "\n"
	end

	sheet = sheet .. _([[Other costs:		{other_costs}
Last paycheck:		{last_paid}
]])

	
	return fmt.f(sheet, crewmate)
end

function getOfferText(edata)
	local approachtext = generateIntroduction(edata)

	local _credits, scredits = player.credits(2)
	local deposit = edata.deposit
	if not deposit then
		deposit = 0
	end
	local credentials = _([[
Name: {name}
Expertise: {skill}
]])

	local finances = _([[
Money: {credits}
Deposit: {deposit}
Salary: {salary}
Other costs: {other_costs}]])
	return (approachtext ..
		"\n\n" ..
			fmt.f(credentials, edata) ..
				"\n\n" ..
					fmt.f(
						finances,
						{
							credits = scredits,
							deposit = fmt.credits(deposit),
							salary = fmt.credits(edata.salary),
							other_costs = edata.other_costs
						}
					))
end

function firstOfficerPreflight( first_officer )
	local min_cadet_xp = 1
	local lindex = #mem.companions
	local findex = 1
--[[
	-- lazy sorting, just iterate through one pass and move "bad crew" further back
	-- while trying to grab good crew and move it to the front
	-- you should expect to get your officers and engineers at the front
	-- and the rookies/cadets at the back after a couple of passes
	-- this stuff assumes you have a first officer and a crew large enough to need organizing
	-- if you have a small crew or a huge ship, this is just a "routine checkup" that does nothing
--]]
	for ii, crewman in ipairs(mem.companions) do
		if crewman.typetitle == _("Crew") and ii < math.floor(#mem.companions * 0.88) then
			local swap = false
			if crewman.skill == _("Rookie") then
				swap = true
			elseif crewman.skill == _("Cadet") then
				if crewman.xp < min_cadet_xp then
					swap = true
				else
					min_cadet_xp = math.floor(crewman.xp)
				end
			end
			if string.find(crewman.skill, _("Janitor")) then
				-- try to find a spot for janitors (sanitations don't get moved around explicitly)
				local jindex = math.min(#mem.companions, math.max(findex + 3, math.floor(ii / 2)))
				mem.companions[ii] = mem.companions[jindex]
				mem.companions[jindex] = crewman
			elseif swap and ii < lindex then	-- move near the back but not in an "away" slot
				local rindex = rnd.rnd(ii, math.max(1, lindex - 1))
				mem.companions[ii] = mem.companions[rindex]
				mem.companions[rindex] = crewman
				print(fmt.f("swapped SWAP {loser} with {other} @ {ii}<->{ri}", {ri = rindex, ii = ii, loser = crewman.name, other = mem.companions[ii].name}))
			elseif crewman.away then -- move to the back into an "away" slot
				mem.companions[ii] = mem.companions[lindex]
				mem.companions[lindex] = crewman
				lindex = lindex - 1
				print(fmt.f("swapped AWAY {loser} with {other} @ {ii}", {ii = ii, loser = crewman.name, other = mem.companions[ii].name}))
			end
		elseif crewman == first_officer then
				-- give me slot 1 please
				mem.companions[ii] = mem.companions[1]
				mem.companions[1] = crewman
		elseif	-- make sure that engineers are on board, since they are pretty special
			string.find(crewman.typetitle, _("Engineer"))
			or string.find(crewman.skill, _("Chief"))
			or string.find(crewman.skill, _("Officer"))
		then	-- move this one to the front
			findex = math.min(#mem.companions, findex + 1)
			mem.companions[ii] = mem.companions[findex]
			mem.companions[findex] = crewman
		elseif string.find(crewman.typetitle, _("Sr.")) then
			-- the player promoted this crew member and wants him on the ship
			local sindex = math.min(#mem.companions, findex + 2)
			mem.companions[ii] = mem.companions[sindex]
			mem.companions[sindex] = crewman
		end
	end
end

return contract.capture {
	name = "crew_factory_npcs",
	requires = { "context", "content.random", "crew_factory", "crew_factory_officers" },
	exports = { "createCrewmateNPCs", "getCrewSheet", "getOfferText", "firstOfficerPreflight" },
}
