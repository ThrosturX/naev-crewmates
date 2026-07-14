local der = require "common.derelict"
local fmt = require "format"
local vntk = require "vntk"
local vn = require "vn"
local lang = require "language.language"
local contract = require "crewmates.module_contract"
local docking = require "crewmates.docking"
local hiring = require "crewmates.hiring"

local function select_replacement(selected, incumbent, candidate)
	return hiring.select_replacement(selected, incumbent, candidate, function(current, replacement)
		return vntk.yesno(
			_("Replace crew member?"),
			fmt.f(
				_("Your crew already includes {current_skill} {current_title} {current_name}. Replace {current_name} with {candidate_skill} {candidate_title} {candidate_name}?"),
				{
					current_skill = current.skill,
					current_title = current.typetitle,
					current_name = current.name,
					candidate_skill = replacement.skill,
					candidate_title = replacement.typetitle,
					candidate_name = replacement.name,
				}
			)
		)
	end)
end

local function enlist_crew(incumbent, candidate)
	mem.companions[#mem.companions + 1] = candidate
	if not incumbent then
		return true
	end
	local replaced, denial = terminate_crew(
		incumbent,
		fmt.f(
			_("You replaced '{old_name}' with '{new_name}'."),
			{ old_name = incumbent.name, new_name = candidate.name }
		),
		{ replacement = candidate }
	)
	if replaced then
		return true
	end
	for index, crewmember in ipairs(mem.companions) do
		if crewmember == candidate then
			table.remove(mem.companions, index)
			break
		end
	end
	return false, denial
end

function approachCompanion(npc_id)
	local edata = npcs[npc_id]
	if edata == nil then
		evt.npcRm(npc_id)
		return
	end

	crewmate_barConversation(edata, npc_id)
end

-- TODO: approach first officer function

-- Approaching a completely generic crewmate
function approachGenericCrewmate(npc_id)
	local pdata = npcs[npc_id]
	local replacement
	if pdata == nil then
		evt.npcRm(npc_id)
		return
	end

	if not vntk.yesno("", getOfferText(pdata)) then
		return -- Player rejected offer
	end

	if pdata.deposit > 0 and pdata.deposit > player.credits() then
		vntk.msg(_("Insufficient funds"), _("You don't have enough credits to pay for this person's deposit."))
		return
	end

	-- check if this ship has this kind of manager (doesn't apply to scientists)
	if pdata.manager and not string.find(pdata.manager.type:lower(), _("Science"):lower()) then
		for _i, pers in ipairs(mem.companions) do
			if
				pers ~= replacement
				and pers.manager
				and pers.manager.type == pdata.manager.type
				and not string.find(pers.skill, _("Officer"))
				and not string.find(pers.manager.type, _("Command"))
			then
				local allowed
				replacement, allowed = select_replacement(replacement, pers, pdata)
				if not allowed then
					vntk.msg(
						_("No thanks"),
						_("You look like you're already fairly well staffed. I'll find another ship that needs me.")
					)
					return
				end
			end
		end
	end
	
	if pdata.shuttle then
		for _i, pers in ipairs(mem.companions) do
			-- if we have a shuttle, we won't join unless we are an officer and the ship doesn't have a smuggler
			if
				pers ~= replacement
				and pers.shuttle
				and (not string.find(pdata.skill, _("Officer")) or pers.skill == _("Smuggler"))	-- 2. but not the officer crew
				and not (pdata.skill == _("Smuggler") and pers.skill == _("Pirate Leader"))		-- 1. let the smuggler join pirate crew
			then
				local allowed
				replacement, allowed = select_replacement(replacement, pers, pdata)
				if not allowed then
					vntk.msg(
						_("No thanks"),
						_("It looks like you already have someone else calling dibs on any spare space in your docking bays. I don't want to step on anyone's feet.")
					)
					return
				end
			end
		end
		-- check if the ship has a shuttle that we can use
		-- otherwise, we would have brought our own with us
		if mem.ship_interior.shuttle and not mem.ship_interior.shuttle.out then
			pdata.shuttle = mem.ship_interior.shuttle
		end
	end

	-- check if this crew member has a typetitle that is limited
	for ttt, lll in pairs(SHIP_CREW_LIMITS) do
		local count = 0
		local counted = {}
	
		print(fmt.f("HIRE Limit {k:16s} is\t{v}", {k=ttt, v=lll}))
		
		if ttt == pdata.typetitle or ttt == pdata.skill then
			for _i, crewmate in ipairs(mem.companions) do
				if
					crewmate ~= replacement
					and (crewmate.typetitle == ttt or crewmate.skill == ttt)
				then
					-- check if it's the same skill of same type (not allowed unless we are "Crew")
					if
						crewmate.skill == pdata.skill
						and string.find(crewmate.typetitle, ttt)
						and crewmate.typetitle ~= _("Crew") -- don't count regular crew against other types
						and not (crewmate.manager and crewmate.manager.type == _("Science")) -- don't count scientists either
					then
						print("found opposing crewmate " .. crewmate.name)
						local allowed
						replacement, allowed = select_replacement(replacement, crewmate, pdata)
						if not allowed then
							vntk.msg(
								_("No thanks"),
								fmt.f(_("How many {skill} {typetitle}s do you think you need? If you think you need more than just the one, then I don't think I want to be anywhere near your ship."), pdata )
							)
							return
						end
					end
					-- only count same skills or same titles
					if crewmate ~= replacement and ((
							crewmate.skill == ttt
							and pdata.skill == ttt
						) or (
							crewmate.typetitle == ttt
							and pdata.typetitle == ttt
						))
					then
						print("counting opposing crewmate " .. crewmate.name .. " as a " .. ttt)
						count = count + 1
						counted[#counted + 1] = crewmate
					end
				end
			end
			-- check if we reached the limit of types
			if lll <= 0 then -- we aren't allowed to have any of this type
				pdata.chosentitle = ttt
				vntk.msg(
					_("No thanks"),
					fmt.f(_("It doesn't really look like you have any use for a {chosentitle}. I don't want to be dead weight, I'll find another ship."), pdata )
				)
				return
			end
			if count >= lll then
				local allowed = false
				if count - 1 < lll then
					replacement, allowed = select_replacement(replacement, counted[1], pdata)
				end
				if not allowed then
					pdata.chosentitle = ttt
					pdata.limit = lll
					vntk.msg(
						_("No thanks"),
						fmt.f(_("How many {chosentitle}s do you think you need? If you think you need more than {limit}, then I don't think I want to be anywhere near your ship."), pdata )
					)
					return
				end
			end
		end
	end


	local next_index = #mem.companions + 1
	
	if next_index * 0.96 >= getMaxCrew() and pdata.typetitle == "Crew" then
		local params = {
			["start"] = pick_one({
				_("Oh hey,"),
				_("Well,"),
				_("Actually, upon closer inspection")
			}),
			["reason"] = pick_one({
				_("it kind of looks like your ship has too much crew on it already."),
				_("I don't know if you have the facilities for another crew member."),
				_("I think it would be better if I joined a different ship.")
			}),
			["excuse"] = pick_one({
				_("I can tell you're only trying to be polite, but there's obviously no room for me on your ship."),
				_("I'm sure I'll find something else."),
				_("It's not you or your ship, I just can't work with so many people.")
			}),
			["bye"] = pick_one({
				_("Later."),
				_("I'll see you around."),
				_("Catch you later."),
				_("Sorry.")
			})
		}
		vntk.msg(_("No thanks"), fmt.f(_("{start} {reason} {excuse} {bye}"), params))
		return
	end
		
	local enlisted, denial = enlist_crew(replacement, pdata)
	if not enlisted then
		vntk.msg(_("Required commander"), denial)
		return
	end

	if pdata.deposit and pdata.deposit > 0 then
		player.pay(-pdata.deposit, true)
		playMoney()
	else
		-- TODO HERE: Play a sound
	end
	
	if pdata.fmt_reward and pdata.destination then
		vntk.msg(fmt.f(_("{typetitle} embarks"), pdata), fmt.f(_("You signal the passenger to get on your ship. {firstname} {name} heads towards your ship and mentions that {article_subject} would pay you {fmt_reward} if you would be so kind as to drop {article_object} off at {destination}."), pdata ))
	else
		vntk.msg(fmt.f(_("{typetitle} hired"), pdata), fmt.f(_("You pay the {skill} {typetitle}, who heads towards your ship to begin a new life."), pdata ))
	end
	evt.npcRm(npc_id)
	npcs[npc_id] = nil
	local id =
		evt.npcAdd(
		"approachCompanion",
		pdata.name,
		pdata.portrait,
		fmt.f(_("{name} is a member of your crew."), pdata),
		9
	)
	npcs[id] = pdata
	evt.save(true)

	local edata = pdata
	shiplog.create(logidstr, _("Ship Companions"), _("Ship Companions"))
	shiplog.append(logidstr, fmt.f(_("You hired '{name}' to join your crew."), edata))
	-- hiring a crew member usually means a little bit of a mess initially
	mem.ship_interior.dirt = mem.ship_interior.dirt + edata.xp * edata.satisfaction * 0.1
end

-- Approaching unhired companion escort at the bar
function approachEscortCompanion(npc_id)
	local pdata = npcs[npc_id]
	local replacement
	if pdata == nil then
		evt.npcRm(npc_id)
		return
	end

	if not vntk.yesno("", getOfferText(pdata)) then
		return -- Player rejected offer
	end

	if pdata.deposit and pdata.deposit > player.credits() then
		vntk.msg(_("Insufficient funds"), _("You don't have enough credits to pay for this person's deposit."))
		return
	end

	-- this can be generalized to an attribute like unique
	-- check if this ship has an escort
	for _i, pers in ipairs(mem.companions) do
		if pers.skill == "Escort" then
			local allowed
			replacement, allowed = select_replacement(replacement, pers, pdata)
			if not allowed then
				vntk.msg(
					_("No thanks"),
					_(
						"You already have an escort on your ship. I need my space. I need my privacy. I need my customers. I'll find another ship."
					)
				)
				return
			end
		end
	end

	local enlisted, denial = enlist_crew(replacement, pdata)
	if not enlisted then
		vntk.msg(_("Required commander"), denial)
		return
	end

	if pdata.deposit then
		player.pay(-pdata.deposit, true)
	end
	
	evt.npcRm(npc_id)
	npcs[npc_id] = nil
	local id =
		evt.npcAdd(
		"approachCompanion",
		pdata.name,
		pdata.portrait,
		fmt.f(_("{name} lives on your ship with the crew."), pdata),
		8
	)
	npcs[id] = pdata
	evt.save(true)

	local edata = pdata
	shiplog.create(logidstr, _("Ship Companions"), _("Ship Companions"))
	shiplog.append(logidstr, fmt.f(_("You allowed '{name}' to live on your ship with your crew."), edata))
	-- the companion likes luxury and will do a little bit of initial cleaning
	mem.ship_interior.dirt = math.max(0, mem.ship_interior.dirt - edata.xp * edata.satisfaction - player.pilot():ship():size())
end

-- Approaching unhired demo man at the bar
function approachDemolitionMan(npc_id)
	local pdata = npcs[npc_id]
	local replacement
	if pdata == nil then
		evt.npcRm(npc_id)
		return
	end

	if not vntk.yesno("", getOfferText(pdata)) then
		return -- Player rejected offer
	end

	if pdata.deposit and pdata.deposit > player.credits() then
		vntk.msg(_("Insufficient funds"), _("You don't have enough credits to pay for this person's deposit."))
		return
	end

	for _i, pers in ipairs(mem.companions) do
		if pers.skill == _("Demolition") then
			local allowed
			replacement, allowed = select_replacement(replacement, pers, pdata)
			if not allowed then
				vntk.msg(
					_("No thanks"),
					_(
						"There's no room for two pyromaniacs on one ship. I'll save you the trouble and get out of your hair."
					)
				)
				return
			end
		end
	end

	-- check if this crew member has a typetitle that is limited
	local count = 0
	local limit = SHIP_CREW_LIMITS[_("Engineer")] or 1
	for _i, crewmate in ipairs(mem.companions) do
		if crewmate ~= replacement and crewmate.typetitle == _("Engineer") then
			count = count + 1
			if count >= limit then
				local allowed
				replacement, allowed = select_replacement(replacement, crewmate, pdata)
				if not allowed then
					pdata.limit = limit
					vntk.msg(
						_("No thanks"),
						fmt.f(_("How many {typetitle}s do you think you need? If you think you need more than {limit}, then I don't think I want to be anywhere near your ship."), pdata )
					)
					return
				end
			end
		end
	end
	
	local enlisted, denial = enlist_crew(replacement, pdata)
	if not enlisted then
		vntk.msg(_("Required commander"), denial)
		return
	end

	if pdata.deposit then
		player.pay(-pdata.deposit, true)
		playMoney()
	end

	vntk.msg(fmt.f(_("{typetitle} hired"), pdata), fmt.f(_("You pay the {skill} {typetitle}, who heads towards your ship to begin a new life of violent adventure."), pdata ))

	
	evt.npcRm(npc_id)
	npcs[npc_id] = nil
	local id = evt.npcAdd("approachCompanion", pdata.name, pdata.portrait, _("This is one of your crewmates."), 8)
	npcs[id] = pdata
	evt.save(true)

	local edata = pdata
	shiplog.create(logidstr, _("Ship Companions"), _("Ship Companions"))
	shiplog.append(logidstr, fmt.f(_("You hired '{name}' to join your crew."), edata))
	-- hiring this guy in this condition (the special hiring function, not generic engineer one)
	-- means you hire him while he's really dirty, so he contaminates the ship
	mem.ship_interior.dirt = mem.ship_interior.dirt + edata.xp * edata.satisfaction + player.pilot():ship():size()
end

-- a science officer manages a hydroponics farm
-- the hook runs when the scientist checks the lab and if
-- the farm is ready to convert: ~10 water becomes 1-6 food
function hydroponics_farm( scientist )
	-- if this scientist is an officer, gain bonus just for existing
	if string.find(scientist.typetitle, _("Officer")) then
		scientist.bonus = math.min(scientist.bonus + 1, 100)
	end

	-- if scientist hasn't started or if his project is ready
	if not scientist.ready or scientist.ready < time.cur() then
		local water_needed = math.max(1, (12 - scientist.satisfaction * 0.1 - scientist.xp * 0.08))
		local water_has = player.pilot():cargoHas("Water")
		-- we have enough water to create food
		if water_has > water_needed then
			-- we won't be ready to do this again for a while
			scientist.ready = time.cur() + time.new( 0, 256 - scientist.xp - scientist.bonus, 20 - scientist.satisfaction)
			
			player.pilot():cargoRm("Water", water_needed)
			player.pilot():cargoAdd("Food", math.max(1, scientist.xp * 0.06))
			-- report to the captain
			hook.timer(60 - scientist.satisfaction * 3, "speak_notify", scientist)
			-- get a free fruit crate from the "last harvest" (but also the first "harvest")
			local crate = {}
			crate.fruit = lang.getRandomFruit()
			crate.origin = system.cur()			
			scientist.manager.special = {}
			scientist.manager.special.label = fmt.f(_("Distribute {fruit}s"), crate )
			scientist.manager.special.message = fmt.f(_("I packed a crate of {fruit}s from the hydroponics farm back in {origin}. What do you want me to do with the all the {fruit}s?"), crate)
			scientist.manager.special.feedback = pick_one(getConversation(scientist).default_participation)
			scientist.manager.special.choices = {
				{ _("Distribute among crew"), "special_yes" },
				{ _("Nothing"), "end" }
			}
			scientist.manager.special.crate = crate
			scientist.manager.special.price = 0
		else -- check again in 2 periods
			scientist.ready = time.cur() + time.new( 0, 2, 0 )
		end
	end
	if scientist.hook and scientist.hook.hook then
			hook.rm(scientist.hook.hook)
	end
	scientist.hook.hook = hook.date(scientist.ready, "hydroponics_farm", scientist)
end

-- sanitation officer kicks the cleaning team to do some spring cleaning
function sanitation_officer_cleaning( officer )
	if officer.hook and officer.hook.hook then
		hook.rm(officer.hook.hook)
	end
	
	-- the officer cleans the ship excessively and leave things as pristine as possible
	local clean_strength = math.max(1, 1 - mem.ship_interior.dirt_accum)
	mem.ship_interior.dirt = math.max(-3, mem.ship_interior.dirt - clean_strength)
	
	-- officer schedules another round
	local next_round = math.max(280, 600 - officer.xp * officer.satisfaction)
	officer.hook.hook = hook.timer(next_round, "sanitation_officer_cleaning", officer)
end

-- medical officer (therapist) finds sad crew and does something about it
function therapist_officer( officer )
	if officer.hook and officer.hook.hook then
		hook.rm(officer.hook.hook)
	end
	local limit = math.ceil(officer.xp)
	local done = 0
	for _i, worker in ipairs(pick_some(mem.companions)) do
		if done > limit then
			-- too tired to work more for now
			break
		end
		-- regular psychotherapy
		if worker.satisfaction < -1 then
			local sss = math.max(-6, worker.satisfaction)
			worker.satisfaction = math.floor(10 * (sss - (sss / 12))) / 10 + 0.01 * rnd.rnd()
			done = done + 1
			officer.xp = officer.xp + 0.01
			officer.satisfaction = officer.satisfaction + 0.01
		elseif worker.satisfaction < 2 and rnd.rnd() < worker.chatter then
			-- here for a checkup
			worker.satisfaction = worker.satisfaction + 0.04
			officer.satisfaction = officer.satisfaction - 0.01
			officer.xp = officer.xp + 0.004
			done = done + 1
		end
		-- give this worker a little personality trim
		if rnd.rnd(0, 7) == 7 then
			pruneCrewMate(worker)
		end
	end
	
	if officer.satisfaction >= 3 then
		-- grab someone for some one on one
		local patient = getCrewmateOnboard()
		patient.satisfaction = patient.satisfaction + 0.2
		officer.xp = officer.xp + 0.06
		-- give him complementary fruit?
		if rnd.rnd(0, 100) < officer.xp then
			give_item( patient, lang.getRandomFruit() )
		end
	end
	
	-- officer schedules another round
	local next_round = math.max(280, 600 - officer.xp * officer.satisfaction)
	officer.hook.hook = hook.timer(next_round, "therapist_officer", officer)
end

-- the morale officer does his job
function morale_officer( officer )
	if officer.hook and officer.hook.hook then
		hook.rm(officer.hook.hook)
	end
	
	-- officer refreshes decorations
	if mem.ship_interior.decoration_locked or not mem.ship_interior.decoration then
		local new_decoration = pick_one({
			fmt.f("{item}", { item = pick_one(lang.nouns.objects.accessories) } ),
			fmt.f(_("{item} repair manual"), { item = pick_one(lang.nouns.objects.spaceship_parts) } ),
			fmt.f(_("{item} troubleshooting guide"), { item = pick_one(lang.nouns.objects.spaceship_parts) } ),
			fmt.f(_("{item} diagnostics & analysis system"), { item = pick_one(lang.nouns.objects.spaceship_parts) } ),
			fmt.f("{adjective} {item}", { adjective = pick_one(lang.adjectives.size.small), item = pick_one(lang.getAll(lang.nouns.objects)) } ),
			fmt.f(_("{adjective} {item} figurine"), {
				adjective = pick_one(join_tables(lang.adjectives.positive.magical, lang.adjectives.violent)),
				item = pick_one(lang.getAll(lang.nouns.actors.people))
			} ),
			fmt.f(_("{nice} {adjective} {item} {figurine}"), {
				nice = pick_one(lang.adjectives.positive.nice),
				adjective = pick_one(lang.getAll(lang.adjectives)),
				item = pick_one(lang.getAll(lang.nouns.actors.people)),
				figurine = pick_one({ _("figurine"), _("statuette"), _("miniature sculpture"), _("scale model") })
			} ),
			fmt.f("{nice} {item}", { nice = pick_one(join_tables(lang.adjectives.colors, lang.adjectives.positive.nice)), item = pick_one(join_tables(lang.nouns.objects.items, lang.nouns.objects.clothes)) } ),
		})
		mem.ship_interior.decoration = new_decoration
		mem.ship_interior.decoration_locked = nil
		officer.xp = officer.xp + 0.01
		-- being the morale officer, the achilles heel is concern for ones own work performance
		officer.satisfaction = math.min(9, officer.satisfaction + 0.01 * officer.xp)
	end
	
	-- officer checks in on a random crewmate
	local pal = getCrewmateOnboard()
	if pal then
		if pal.satisfaction < 1 then
			-- give him something he might want
			give_item( pal, findSuitableGift(pal) )
			officer.xp = officer.xp + 0.06
		elseif not pal.item then
			-- give him a random thing
			local random_item = pick_one(
				join_tables(
					join_tables(lang.nouns.objects.items, lang.nouns.objects.tools),
					lang.nouns.objects.wearables
				)
			)
			give_item( pal, random_item )
			officer.xp = officer.xp + 0.01
		else	-- xp becomes capped at current satisfaction (can go up) but otherwise some xp is lost out of boredom
			officer.xp = math.max(officer.satisfaction, officer.xp - 0.01)
			officer.satisfaction = officer.satisfaction - 0.002
		end
	end
	
	-- officer schedules another round
	local next_round = math.max(120, 200 - officer.xp - officer.satisfaction)
	officer.hook.hook = hook.timer(next_round, "morale_officer", officer)
end

-- the player lands on a spob with a passenger on board that might leave here
function passenger_landing( passenger )
	if spob.cur() == passenger.destination then
		vntk.msg(_("Passenger disembarks"), fmt.f(_("{skill} {name} has disembarked from your ship, leaving you with a credit chip worth {fmt_reward}."), passenger))
		player.pay(passenger.reward)
		disband_crew(passenger, fmt.f(_("{firstname} {name} disembarked from your ship at {destination}, paying you {fmt_reward}."), passenger))
		playMoney()
	end
end

-- the player lands on a world with a companion escort on board
function escort_landing(speaker)
	-- used like "why are we on this pick(<descriptors>) anyway"
	local bad_tags = {
		["garbage"] = {"dump", "literal garbage dump", "floating space turd", "scrapheap", "landfill"},
		["mining"] = {"mining world", "low-brow planet", "terrible rock", "forsaken place", "labour camp"},
		["poor"] = {"destitute world", "forsaken ground", "filthy rock", "scrapheap", "misery farm", "labour camp"}
	}
	-- used like "<tag> <descriptor> can actually be quite lucrative"
	local neutral_tags = {
		["agriculture"] = "planets",
		["criminal"] = "worlds",
		["government"] = "facilities",
		["industrial"] = "executives and their children",
		["prison"] = "workers",
		["research"] = "establishments"
	}
	-- TODO: these are special
	local good_tags = {
		["medical"] = {
			"worlds",
			"facilities",
			"planets",
			"institutions",
			"complexes"
		},
		["military"] = {
			"worlds",
			"facilities",
			"outposts",
			"organizations",
			"complexes"
		},
		-- I thought there would be some good rural words, but I keep seeing really bad ones
 --		["rural"] = {"worlds", "planets", "moons", "paradises", "gardens"},
		["shipbuilding"] = {"facilities", "locations"},
		["urban"] = {"cities", "megaplexes", "megacities", "suburbs", "clubs"},
		["trade"] = {"hubs", "kernels", "stops"},
		["rich"] = {"places", "worlds", "planets", "people", "geriatrics", "octogenarians", "centenarians"}
	}

	-- we probably didn't get our argument, so let's pick out our escort from the crew
	if not speaker then
		for _i, pers in ipairs(mem.companions) do
			if pers.skill == "Escort" then
				speaker = pers
			end
		end
	end

	if not speaker then
		print("error no speaker")
		return
	end

	-- see if we get some jobs here
	local world_score = -0.1
	local tags = spob.cur():tags()
	local good_choices = {
		_("I always say that {tag} {place} are good for business."),
		_("We should come to {place} like these more often."),
		_("We should visit {place} like these often."),
		_("Those {tag} {place} are good for business."),
		_("I like traveling to {tag} {place}."),
		_("The {tag} {place} here were quite generous."),
		_("I had a good time here as usual."),
		_("I met one of my regulars. You'll never know the details."),
		_("Even a {made_up} would like this place.")
	}
	local neutral_choices = {
		_("I think that {tag} {place} aren't the worst for business."),
		_("The business is usually good when it comes to {tag} {place}."),
		_("We should stop at {place} like these every once in a while."),
		_("We should visit {place} like this one more often, but not too often."),
		_("Those {tag} {place} are alright for business."),
		_("I like traveling to {tag} {place}."),
		_("This was a nice break."),
		_("The {tag} {place} here were decent."),
		_("I had an unexpected good time."),
		_("I had a surprisingly good time."),
		_("I had a surprisingly relaxed stay."),
		_("I lucked into one of my regulars. You'll never guess which one."),
		fmt.f(_("I saw a {made_up} for what I think was the first time."), {made_up = lang.getMadeUpName()}),
		fmt.f(_("Was that a {made_up}?"), {made_up = lang.getMadeUpName()}),
		fmt.f(_("Was that a {made_up} back there?"), {made_up = lang.getMadeUpName()}),
		fmt.f(
			_("I didn't want to ask in front of that {made_up}, but do you think it's real?"),
			{made_up = lang.getMadeUpName()}
		)
		}
	local relevant_message
	-- check good tags
	for tag, thing_choices in pairs(good_tags) do
		if tags[tag] then
			local thing = pick_one(thing_choices)
			world_score = world_score + 3
			if rnd.rnd() > 0.33 then
				relevant_message = fmt.f(pick_one(good_choices), {tag = tag, place = thing, made_up = lang.getMadeUpName()})
			end
		end
	end

	-- check neutral tags
	for tag, thing in pairs(neutral_tags) do
		if tags[tag] then
			world_score = world_score + 1
			if not relevant_message and rnd.rnd() > 0.67 then
				relevant_message =
					fmt.f(pick_one(neutral_choices), {tag = tag, place = thing, made_up = lang.getMadeUpName()})
			end
		end
	end

	-- check the dumps (make sure to check if the world is poor, because there are
	-- e.g. poor rural worlds like Waterhole's Moon)
	if world_score < 0 or tags.poor then
		for tag, choices in pairs(bad_tags) do
			if tags[tag] then
				world_score = -5
				relevant_message = fmt.f("What are we doing on this {place}?", {place = pick_one(choices)})
				-- create an unpleasant memory
				create_memory(
					speaker,
					"work",
					{
						system = system.cur(),
						planet = spob.cur()
					}
				)
			end
		end
	end

	local payoff = 0
	if world_score > 0 then
		for i = 0, world_score do
			local job_pay = world_score * 10e3 + world_score * 5e3 * rnd.threesigma()
			if rnd.rnd(0, 1) == 1 then -- we got the job
				payoff = payoff + job_pay
			elseif rnd.rnd() < (math.min(50, speaker.xp) * speaker.satisfaction / 1000) then
				-- we somehow got the job with a bonus
				payoff = payoff + job_pay + 100e3
			end
		end
		-- create a work memory
		create_memory(
			speaker,
			"work",
			{
				credits = fmt.credits(payoff),
				system = system.cur(),
				planet = spob.cur()
			}
		)
	end

	-- raise or lower satisfaction based on world score
	speaker.satisfaction = math.min(10, math.max(-10, speaker.satisfaction + world_score))

	if payoff > speaker.threshold then -- we are happy
		-- raise the satisfaction based on payoff
		speaker.satisfaction = math.min(10, speaker.satisfaction + math.floor(payoff / speaker.threshold))

		-- set our last message to happy regardless of true satisfaction
		-- if we are unhappy, maybe mention that this was a turnaround TODO
		speaker.conversation.sentiment = relevant_message
	elseif relevant_message then -- we are unhappy
		-- set our last message to dissatisfied regardless of true satisfaction
		speaker.conversation.sentiment = relevant_message
		if speaker.satisfaction < 0 then
			-- TODO: pick from choices
			speaker.conversation.sentiment = relevant_message .. " " .. pick_one(speaker.conversation.special["worry"])
		end
	end
end

-- should return the commodities that the player can sell
function get_commodities_to_sell( cargo_limit , where, limit_str )
	print("get_commodities_to_sell", cargo_limit , where, limit_str, "^^^^^^^^" )
	where = where or system.cur()
	local pp = player.pilot()
	local sellers = {}
	local total_cargo = 0
	for _k,v in ipairs( pp:cargoList() ) do
		local cargo_name = v.c:nameRaw()
		-- ignore mission cargo
		if
			not v.m
			and commodity.canSell( v.c, where )
			and cargo_name ~= "Food" -- don't sell food, crew wants it
		then
			if
				not limit_str
				or string.find(limit_str:lower(), cargo_name:lower())
			then
				print(fmt.f("get_commodities_to_sell : add cargo {q} x {name}", { q = v.q, name = cargo_name }))
				total_cargo = total_cargo + v.q
				sellers[cargo_name] = v.q
			end
		end
	end
	
	if total_cargo > cargo_limit then
		-- Simulate cargo removal
		local cl = pp:cargoList()
		local space_needed = total_cargo - cargo_limit
		local removals = {}
		for _k,v in ipairs( cl ) do
			if not v.m then
				v.p = v.c:priceAt(where)
			end
		end
		while space_needed > 0 do
			-- Find cheapest
			local cn, cq, ck
			local cp = math.huge
			for k,v in pairs( cl ) do
				if not v.m then
					if v.p < cp then
						ck = k
						cn = v.c:nameRaw()
						cp = v.p
						cq = v.q
					end
				end
			end
			-- found cheapest
			cq = math.min( space_needed, cq )
			removals[cn] = cq
			cl[ck].q = cl[ck].q - cq
			if cl[ck].q <= 0 then
				cl[ck] = nil
			end
			space_needed = space_needed - cq
		end
		-- don't sell these
		for n, q in pairs(removals) do
			local stock = sellers[n] or 0
			stock = math.max(0, stock - q)
			if stock > 0 then
				sellers[n] = stock
			else
				sellers[n] = nil
			end
		end
	end
		
	return sellers
end

-- makes the shuttler return to the mothership
function mission_return_to_player( args )
	local aimem = args.crewsheet.pilot:memory()
	aimem.radius = 5
	args.crewsheet.pilot:control(true)
	args.crewsheet.pilot:follow(player.pilot(), true)
	if not args.profit then
		args.profit = 0
	end
	
	local start_check_time = 10 * args.crewsheet.pilot:ship():size()
	
	hook.timer(start_check_time, "shuttle_check_dock_distance", args)
end

function mission_idle_return_to_player( plt, args )
	print("mission_idle_return_to_player " ..  plt:name() .. " :: " .. tostring(args) )
	if not args then
		for _i, peep in ipairs(mem.companions) do
			if peep.pilot and peep.pilot == plt then
				args = {
					crewsheet = peep,
					mission = peep.away,
					shuttle = mem.ship_interior.shuttle -- "incorrect", but we need one and args isn't being passed
				}
				return mission_return_to_player(args)
			end
		end
	end
	return mission_return_to_player(args)
end
-- destination must be a spob
function mission_travel_to_spob( args, destination )
	-- makes the pilot fly to where it needs to go
	args.crewsheet.pilot:control(true)
	-- minor sanity check here
	if not destination then
		return mission_return_to_player( args )
	end
	local next_system = system.get( destination )
	if next_system == system.cur() then
		args.crewsheet.pilot:land(destination)
		return
	end
	print("UNIMPLEMENTED: Fake (simulated) away mission to another system")
end

-- player orders shuttlepilot to sell off some cargo in the current system
-- like smuggler, but needs a shuttle from an officer
function sell_cargo_local( args )
	local shuttle = args.shuttle
	local crewman = args.crewsheet
	local active_pilot = args.crewsheet.pilot

	local will_sell = {}
	local profit = 0
	local space = crewman.pilot:cargoFree()

	-- find the nearest place that will buy some cargo
	local chosen_spob = nil
	for _i, sspob in ipairs (system.cur():spobs()) do
		if sspob:services().commodity then
			if not chosen_spob then
				chosen_spob = sspob
			elseif 
				vec2.dist2( player.pilot():pos(), chosen_spob:pos() )
				> ( vec2.dist2( player.pilot():pos(), sspob:pos() ) )
			then
				chosen_spob = sspob
			end
		end
	end
	
	if not chosen_spob then
		der.sfxUnboard()
		local message = _("Wait a minute, where am I going again? Nobody sent me any coordinates for a commodity exchange!")
		active_pilot:comm(message)
		return mission_return_to_player(args)
	end
	
	local to_sell = get_commodities_to_sell(space, chosen_spob, args.mission.target)
	
	-- remove the commodities from the players cargo hold
	-- and put them in the new ship
	for name, qty in pairs(to_sell) do
		local cc = commodity.get(name)
		local nn = player.fleetCargoRm(cc, qty)
		active_pilot:cargoAdd(cc, nn)
		profit = profit + qty * cc:priceAt(chosen_spob)
		print(fmt.f("gonna go sell {qty} x {name} for {price}, total at {total}", { qty=qty, name=name, price=cc:priceAt(chosen_spob), total=profit } ) )
	end

	hook.pilot(active_pilot, "land", "mission_away_landed", { profit = profit, crewsheet = crewman, shuttle = shuttle.ship, mission = args.mission })
	active_pilot:setNoClear(true)
	mission_travel_to_spob(args, chosen_spob)
	local message = pick_one(crewman.conversation.special.going)
	active_pilot:comm(message)
	if space == 0 then
		-- the pilot differs from the smuggler as it can be promoted all the way to lieutenant
		-- so a shuttle pilot can actually pull their own weight on a bayless ship
		crewman.xp = math.min(100, crewman.xp + 0.1)
	end
	der.sfxUnboard()
end

function buy_cargo_local( args )
	local shuttle = args.shuttle
	local crewman = args.crewsheet
	local active_pilot = crewman.pilot

	-- our mission directive is to buy, but we need to know what to buy from where
	local want = parseCommodity(args.mission.target)
	if not want then
		der.sfxUnboard()
		local message = _("Wait a minute, what am I doing again? I didn't understand the order to ") .. args.mission.directive .. " " .. args.mission.target .. _(".")
		active_pilot:comm(message)
		return mission_return_to_player(args)
	end
	local space = crewman.pilot:cargoFree()
	-- check if this system can sell us any of the want
	local chosen_spob = nil
	for _i, bspob in ipairs (system.cur():spobs()) do	
		local comms = bspob:commoditiesSold()
		for _j, cc in ipairs(comms) do
			-- this is sold here
			if cc == want then
				if not chosen_spob then
					chosen_spob = bspob
				elseif
					vec2.dist2( player.pilot():pos(), chosen_spob:pos() )
					> ( vec2.dist2( player.pilot():pos(), bspob:pos() ) )
				then
					-- this one is closer
					chosen_spob = bspob
				end
			end
		end
	end

	if not chosen_spob then
		der.sfxUnboard()
		local message = _("Wait a minute, where am I going again?")
		active_pilot:comm(message)
		return mission_return_to_player(args)
	end
	
	hook.pilot(active_pilot, "land", "mission_away_landed", { profit=-crewman.deposit, crewsheet=crewman, shuttle = shuttle.ship , mission = args.mission })
	active_pilot:setNoClear(true)
	mission_travel_to_spob(args, chosen_spob)
	local message = pick_one(crewman.conversation.special.going)
	active_pilot:comm(message)
	if space == 0 then
		-- the pilot differs from the smuggler as it can be promoted all the way to lieutenant
		-- so a shuttle pilot could actually pull their own weight on a bayless ship
		crewman.xp = math.min(100, crewman.xp + 0.1)
	end
	der.sfxUnboard()
end

function mission_engage_target( args )
	local shuttle = args.shuttle
	local crewman = args.crewsheet
	local active_pilot = crewman.pilot

	local aimem = active_pilot:memory()
	aimem.atk_kill = false
	aimem.atk_board = false
	
	local _armour, _shield, _stress, disabled = args.mission.target:health()
	if disabled then
		active_pilot:comm(fmt.f(_("Engaging {target}..."), { target = args.mission.target:name() } ))
		aimem.atk_kill = true
	end
	
	active_pilot:control(true)
	active_pilot:attack( args.mission.target )
	
	-- if we have nothing to do, got beaten or are being boarded by the player, just come back
	hook.pilot(active_pilot, "idle", "mission_idle_return_to_player", args)
	hook.pilot(active_pilot, "undisable", "mission_idle_return_to_player", args)
--	hook.pilot(active_pilot, "board", "mission_return_to_player", args)
	
	der.sfxUnboard()
end

-- wrapper for launching an away mission
function away_mission( args )
	local shuttle = args.shuttle
	local crewman = args.crewsheet
	local mission = args.mission or { mission = "Trade Mission", ship = shuttle.ship:name(), directive = "sell" }

	if not shuttle.ship or shuttle.out then
		print("away_mission: no shuttle to use " .. tostring(shuttle) .. " : " .. tostring(shuttle.ship) .. " - " .. tostring(shuttle_out))
		return -- no shuttle to use, can happen because player ordered some mission twice or whatever
	end
	
	-- pre-flight safety check
	if player.isLanded() then
		return
	end
	
	-- pilot is using this shuttle, we probably don't need this though
	if not mothership or (mothership and mothership == player.ship()) then
		mem.ship_interior.shuttle = shuttle
	end
	local fakefac = faction.dynAdd(crewman.faction, crewman.skill, crewman.typetitle, { ai = "escort_guardian", clear_enemies = true})
	
	-- create the ship
	crewman.pilot = pilot.add(shuttle.ship, fakefac, player.pilot():pos(), fmt.f("{typetitle} {name}", crewman), {ai="dummy"})
	crewman.pilot:setFuel(0) -- don't spawn any free fuel out of nowhere
	crewman.pilot:cargoRm( "all" ) -- don't spawn a ship with cargo in it for some reason
	player.pay(-crewman.deposit)
	crewman.pilot:credits(-crewman.pilot:credits() + crewman.deposit) -- holds deposit
	crewman.pilot:setHilight(true)
	crewman.pilot:setFriendly(true)
	crewman.pilot:setInvincPlayer(true)
	if crewman.manager and crewman.manager.outfits then
		crewman.pilot:outfitRm("all")
		for _j, o in ipairs(crewman.manager.outfits) do
			crewman.pilot:outfitAdd(o, 1 , true)
		end
	end
	shuttle.out = true
	mission.portrait = crewman.portrait
	crewman.portrait = "unknown"
	crewman.away = mission
	local hailhook = hook.pilot(crewman.pilot, "hail", "mission_idle_return_to_player", args) -- to make him feel better? placeholder for now I guess
	hook.pilot(crewman.pilot, "death", "terminate_crew_death", {crewman = crewman, reason = fmt.f(_("Your pilot was lost in combat along with a deposit of {amount}"), { amount = fmt.credits(crewman.deposit)}) })

	-- ready for the mission
	if mission.directive == "sell" then
		return sell_cargo_local( args )
	elseif mission.directive == "buy" and mission.target then
		return buy_cargo_local( args )
	elseif mission.directive == "engage" and mission.target and mission.target:exists() then
		hook.rm(hailhook)
		hook.pilot(crewman.pilot, "hail", "mission_idle_return_to_player")
		return mission_engage_target( args )
	end
	
	print("UNKNOWN MISSION", mission)
	print(mission.mission, mission.ship, mission.directive)
	return mission_return_to_player( args )
	
end

-- player opens the cargo bay, the smuggler is pressured to smuggle but will also restock fruit
function smuggler_cargobay(speaker)
	if speaker.shuttle.out	then
		print("shuttle is out:", tostring(speaker.shuttle.ship))
		return -- we're not home
	end
	
	-- check if WE are docked
	if player.isLanded() then
		-- currently nothing for smuggler to do unless in space
		return
	end
	
	-- check if the smuggler has a bay to use

	local bay_strength = mem.ship_interior.bay_strength
	print("bay strength", bay_strength)
	
	if bay_strength == 0 then return end -- no bay to use, nothing for smuggler to do
	
	--[[
	-- if we have a bay, calculate our bonuses based on our cargo bay workers
	-- since we want to increase satisfaction and xp for active workers we do
	-- the recalculation instead of using takeoff's calculation (we are on a UI screen anyway)
	-- this CAN be abused by the player by repeatedly opening the cargo screen to
	-- increase the smuggler and cargo worker satisfaction and xp, but honestly I
	-- think that the player can be rewarded because they wouldn't know that they're
	-- getting all these free bonuses from this anyway unless they read the source
	-- in which case they know what they're doing anyway
	--]]
	for ii, worker in ipairs(mem.companions) do
		if ii <= player.pilot():stats()["crew"] then
			if worker.skill == "Cargo Bay" then
				bay_strength = bay_strength + worker.xp * 0.1
				worker.xp = worker.xp + 0.01
				speaker.satisfaction =	speaker.satisfaction + 0.01
			end
		end
	end
	
	-- decide the ship now because we'll need the cargo size
	local bay_ship = "Llama" -- default with no strength
	local space = 15
	if bay_strength > 8 then -- a carrier
		bay_ship = "Mule"
		space = 230
	elseif bay_strength > 6 then -- perhaps a cruiser or freighter
		bay_ship = "Rhino"
		space = 150
	elseif bay_strength > 4 then
		bay_ship = "Koala"
		space = 50
	elseif bay_strength == 2 then
		bay_ship = "Quicksilver"
		space = 30
	end
	
	speaker.shuttle.ship = bay_ship
	
	local will_sell = {}
	local profit = 0
	-- check if this system can buy any of our cargo
	local chosen_spob = nil
	for _i, spob in ipairs (system.cur():spobs()) do
		if not chosen_spob then
			local comms = spob:commoditiesSold()
			for _j, cc in ipairs(comms) do
				local owned = player.fleetCargoOwned(cc)
				-- quick check to not sell food
				if cc:name() == "Food" then owned = 0 end
				if owned > 0 and not chosen_spob then
					chosen_spob = spob
				end
				if owned > 0 and space > 0 then
					-- we can sell this commodity here!
					if owned > space then
						table.insert(will_sell, {cc, space})
						profit = profit + space * cc:priceAt(chosen_spob)
						space = 0
					elseif owned < space then
						table.insert(will_sell, {cc, owned})
						profit = profit + owned * cc:priceAt(chosen_spob)
						space = space - owned
					end
				end
			end
		end
	end
	
	-- TODO: populate choices and use a proper vn discussion and include the part about the fruit
--	print(profit, space, chosen_spob)
	local choices = {}
	
	-- only allow distribution of fruit if smuggler doesn't really want to smuggle
	if chosen_spob and space > 5 and profit < 4e3 or #will_sell == 0 then
		speaker.shuttle.out = true
		speaker.away = { mission = "Smuggling Mission", ship = bay_ship, directive = "sell" }
		-- if we don't have any fruit, see if we can convert a ton of food
		if not speaker.manager.special and player.pilot():cargoHas("Food") then
			player.pilot():cargoRm("Food", 1)
			local crate = {}
			crate.fruit = lang.getRandomFruit()
			speaker.manager.special = {}
			speaker.manager.special.feedback = pick_one(getConversation(speaker).default_participation)
			speaker.manager.special.choices = {
			{ _("Distribute among crew"), "special_yes" },
			{ fmt.f(_("Discard {fruit}"), crate ), "discard_special" },
			{ _("Nothing"), "end" }
			}
			speaker.manager.special.price = math.max(200, 100 * #mem.companions - 50 * speaker.bonus)
			-- 25% chance of converting the food into water instead of consuming it all
			if rnd.rnd(0,4) == 0 then
				crate.comm = "Water"
			end
			crate.origin = system.cur()
			speaker.manager.special.crate = crate
			speaker.manager.special.label = fmt.f(_("Restock {fruit}s"), crate )
			speaker.manager.special.message = fmt.f(_("I can restock the {fruit}s from what food we got here in the cargo bay. Should I?"), crate)
		end
		-- if we have any available fruit to restock, present the option
		if not speaker.manager.special then
			
			-- no special crates or anything and
			-- not enough commodities to fill the smuggler,
			-- not worth going, don't even bother the player
			return
		end
	end
	-- we have everything we need, talk to player
	
	local message = fmt.f(_("Welcome to the cargo bay {name}."), {name = player.name() })

	vn.clear()
	vn.scene()
	vn.transition()
	local character = vn.newCharacter ( fmt.f("{typetitle} {name}", speaker), {image = speaker.vncharacter } )
	
	if #will_sell > 0 and profit > 2e3 and (space < 5 or profit > 10e3) then
		choices = join_tables(
			{ { _("Yes"), "go_smuggle"} },
			choices)
		message = fmt.f(_("Hey captain! I can smuggle some of these commodities to a nearby planet and sell at least {b} tons of {a} if you'd like for {profit}. It would spare you the effort of doing it yourself."), {a=will_sell[1][1],b=will_sell[1][2], profit=fmt.credits(profit)} )
	elseif speaker.manager.special	then
		message = message .. " " .. speaker.manager.special.message
		choices = join_tables(choices, {
			{speaker.manager.special.label, "special_yes"}
		})
	end
	choices = join_tables(choices, {
		{_("Nevermind"), "cancel"}
	})
	
	character(message)
	vn.menu(choices)
	
	if speaker.manager.special then
		vn.label("special_yes")
		character(speaker.manager.special.feedback)
		vn.func( function() 
			doSpecialManagementFunc(speaker)
		end )
			
		vn.done()
	end
	vn.label("go_smuggle")
	vn.func( function () 
		-- player said yes
		-- create the smuggling ship
		local smuggler = pilot.add(bay_ship, "Trader", player.pilot():pos(), speaker.name, {ai="dummy"})
		smuggler:credits(-smuggler:credits()) -- remove any credits

		-- remove the commodities from the players cargo hold
		-- and put them in the new ship
		for _, pair in ipairs(will_sell) do
			local cc = pair[1]
			local qty = pair[2]
			local nn = player.fleetCargoRm(cc, qty)
			smuggler:cargoAdd(cc, nn)
		end
		
		smuggler:control(true)
		smuggler:land(chosen_spob)
		hook.pilot(smuggler, "land", "mission_away_landed", { profit = profit, crewsheet = speaker, shuttle = speaker.shuttle.ship, mission = speaker.away })
		hook.pilot(smuggler, "death", "terminate_crew_death", {crewman = speaker, reason = fmt.f(_("Your smuggler was lost in combat along with a deposit of {amount}"), { amount = fmt.credits(speaker.deposit)}) })
		message = pick_one(getConversation(speaker).special.going)
		smuggler:comm(message)
		if space == 0 then
			speaker.xp = math.min(10, speaker.xp + 0.1)
		end
		der.sfxUnboard()
	end )
	vn.done()
	vn.label("cancel")
	vn.func( function() speaker.shuttle.out = nil end)
	vn.label("end")
	vn.done()
	vn.run()
	
	
end

-- do what we need to do while landed during an away mission
function mission_away_landed( old_shuttler, planet, args )
	-- boilerplate
	old_shuttler:hookClear()
	args.planet = planet
	local return_time = math.max(16, (111 - args.crewsheet.xp) - args.crewsheet.satisfaction)
	hook.timer(return_time, "mission_away_return", args)
	
	-- we are good shuttle pilots and we'll record the commodity prices while we are here
	planet:recordCommodityPriceAtTime(time.cur())

end
-- smuggler lands and must come back
function mission_away_return( args )
	-- great, now the shuttler needs to get back!
	local fakefac = faction.dynAdd(args.crewsheet.faction, args.crewsheet.skill, args.crewsheet.typetitle, { ai = "escort_guardian", clear_enemies = true})
	local shuttler = pilot.add(args.shuttle, fakefac, args.planet, fmt.f("{typetitle} {name}", args.crewsheet), {ai="dummy"})
	shuttler:cargoRm("all")
	args.crewsheet.pilot = shuttler
	shuttler:setFriendly(true)
	shuttler:setInvincPlayer(true)
	shuttler:setHilight(true)
	if args.crewsheet.manager and args.crewsheet.manager.outfits then
		shuttler:outfitRm("all")
		shuttler:outfitRm("cores")
		for _j, o in ipairs(args.crewsheet.manager.outfits) do
			local ret = shuttler:outfitAdd(o, 1 , true)
		end
	end
	
	-- before we actually "take off", we need to add any cargo that we were supposed to buy while landed
	-- do the assigned mission
	if args.mission.directive == "buy" then
		-- we can't leave without loading up some cargo
		local free_space = shuttler:cargoFree()
		local commo = parseCommodity(args.mission.target)
		print(args.mission.target)
		local amount = args.mission.target:match("%d+") or 10
		print(amount)
		amount = math.min(free_space, amount)
		local unit_price = commo:priceAt(args.planet)
		local total_price = math.ceil(unit_price * amount)
		print( fmt.f("Buying {q} units at {p} each for {t} total.", { q = amount, p = unit_price, t = total_price } ) )
		-- load up the cargo
		shuttler:cargoAdd( commo , amount )
		args.profit = -total_price
	end

	-- pick up fuel?
	local ppp = player.pilot()
	local pps = ppp:stats()
	
	local fuel_demand = pps.fuel_max - pps.fuel
	if fuel_demand > 0 then
		local sss = shuttler:stats()
		shuttler:setFuel(sss.fuel_max)
		args.profit = args.profit - math.min(fuel_demand, sss.fuel) * ppp:ship():size()
	end
	
	shuttler:credits(-shuttler:credits() + args.crewsheet.deposit) -- holds deposit
	shuttler:credits(args.profit) -- add the profit (or cost)

	mission_return_to_player(args)
	
	local message = pick_one(args.crewsheet.conversation.special.coming)
	shuttler:comm(message)

	hook.pilot(shuttler, "hail", "mission_idle_return_to_player", args)
	
	-- now as a special bonus, the shuttler has fruit to restock with from the trip
	-- and a random commodity that the crew might need
	local crate = {}
	crate.fruit = lang.getRandomFruit()
	crate.comm = pick_one({"Water", "Medicine", "Food"})
	crate.origin = system.cur()
	
	args.crewsheet.manager.special = {}
	args.crewsheet.manager.special.label = fmt.f(_("Restock {fruit}s"), crate )
	args.crewsheet.manager.special.message = fmt.f(_("I picked up crate of {fruit}s and some {comm} back in {origin}. What do you want me to do with the all the {fruit}s?"), crate)
	args.crewsheet.manager.special.feedback = pick_one(getConversation(args.crewsheet).default_participation)
	args.crewsheet.manager.special.choices = {
		{ _("Distribute among crew"), "special_yes" },
		{ _("Nothing"), "end" }
	}
	args.crewsheet.manager.special.crate = crate
	args.crewsheet.manager.special.price = 0
end

-- checks if it's alive and exists (otherwise player loses a pilot or smuggler)
-- checks if the smuggler or shuttle pilot can dock
-- if shuttle is too far, check again later
-- needs args { shuttler, crewsheet, profit }
function shuttle_check_dock_distance( args )
	local shuttler = args.crewsheet.pilot
	if not shuttler or not shuttler:exists() then
		-- player loses a shuttle pilot and the insurance deposit
		terminate_crew(
			args.crewsheet,
			fmt.f(
				_("{skill} {name} was lost -- never returned after losing communication during a cargo mission."), args.crewsheet
				) ..
			fmt.f(_(" The insurance deposit of {deposit} was written off, as was the {shuttle}."), { deposit = fmt.credits(args.crewsheet.deposit), shuttle = args.shuttle.ship or _("vessel") }),
			{ force = true }
			)
		return
	end
	local shuttler_docking_distance = docking.range(args.crewsheet)
	if vec2.dist2(player.pilot():pos(), shuttler:pos()) < shuttler_docking_distance * shuttler_docking_distance then
		shuttler:comm(pick_one(args.crewsheet.conversation.special.arrived))
		-- SUCCESS, we docked, pay the player the deposit back and any profit
		player.pay(args.profit + args.crewsheet.deposit)
		local pay = _("received")
		local from = _("from")
		if args.profit < 0 then
			pay = _("paid")
			from = _("to")
		end
		shiplog.append(
			logidstr,
			fmt.f(
				_("You {pay} {credits} {from} {skill} {name} after a successful mission."),
				{
					pay = pay,
					from = from,
					credits = fmt.credits(math.abs(args.profit)),
					skill = args.crewsheet.skill,
					name = args.crewsheet.name,
				}
			)
		)
		-- transfer any new cargo over
		for _i, cargo in ipairs(shuttler:cargoList()) do
			player.pilot():cargoAdd( cargo.c, cargo.q )
		end
		-- transfer any fuel over
		local pps = player.pilot():stats()
		player.pilot():setFuel(pps.fuel + shuttler:stats().fuel)
		shuttler:hookClear()
		shuttler:rm()
		-- if the officer went, he needs his button back now
		if string.find(args.crewsheet.skill, _("Officer")) then
			commander_button_aux(args.crewsheet)
			-- I'm paranoid, ok? it was our shuttle and it was registered as the "ship shuttle"
			mem.ship_interior.shuttle.out = nil
			args.crewsheet.shuttle.out = nil
		-- if this was our shuttle, it's no longer out (shuttler transports)
		elseif args.crewsheet.shuttle then
			args.crewsheet.shuttle.out = nil
		else	-- it must have been an officer's shuttle, register it as docked
			mem.ship_interior.shuttle.out = nil
		end

		der.sfxBoard()
		args.crewsheet.pilot = nil
		args.crewsheet.portrait = args.crewsheet.away.portrait
		args.crewsheet.away = nil
		-- docking a shuttle after a voyage increases dirt
		mem.ship_interior.dirt = mem.ship_interior.dirt + mem.ship_interior.bay_strength * player.pilot():ship():size() * 0.1

		return
	end

	shuttler:comm(pick_one(args.crewsheet.conversation.special.coming))
	if shuttler:idle() then
		return mission_return_to_player(args)
	end
	-- if we reached this point, we need to hook another timer
	hook.timer(10, "shuttle_check_dock_distance", args)
end

return contract.capture {
	name = "missions.away",
	requires = {
		"context", "content.character", "memory", "crew_factory",
		"crew_factory_npcs", "management", "management_ui", "shuttle",
	},
	exports = {
		"approachCompanion", "approachGenericCrewmate", "approachEscortCompanion",
		"approachDemolitionMan", "hydroponics_farm", "sanitation_officer_cleaning",
		"therapist_officer", "morale_officer", "passenger_landing", "escort_landing",
		"get_commodities_to_sell", "mission_return_to_player",
		"mission_idle_return_to_player", "mission_travel_to_spob", "sell_cargo_local",
		"buy_cargo_local", "mission_engage_target", "away_mission",
		"smuggler_cargobay", "mission_away_landed", "mission_away_return",
		"shuttle_check_dock_distance",
	},
}

-- chief engineer checks if other engineers need a kick
