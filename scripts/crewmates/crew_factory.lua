local fmt = require "format"
local portrait = require "portrait"
local pir = require "common.pirate"
local pilotname = require "crewmates.pilotname"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function getSpobForFaction(faction)
	for _i, place in ipairs(spob.getAll()) do
		if place:faction() == faction and rnd.rnd() < 0.16 then
			return place
		end
	end

	return "my home planet"
end

local function getRandomSpob()
	local places = spob.getAll()
	if #places <= 0 then
		return _("somewhere far away")
	end
	return pick_one(places)
end

-- generates a backstory for an incomplete companion
-- requires the typetitle, faction and skill fields to be set
-- could use a lot of love :)
function generateBackstory(cdata)
	local backstory = {}
	local random_ship = getRandomShip()
	local random_lastname, random_firstname = pilotname.human()
	if cdata.typetitle == "Companion" then
		backstory.intent =
			pick_one(
			{
				_("I provide services for my customers on various worlds."),
				_("I provide my services for customers around the galaxy."),
				_("I do my business on prosperous worlds."),
				_("I conduct business with wealthy clientele."),
				_("I conduct business around major hubs."),
				_("I would like to live on your ship as I conduct my business around the galaxy."),
				_("My business benefits greatly from frequent travel and I'm looking for a ship."),
				_("I'm looking for a ship from which to conduct my business.")
			}
		)
		backstory.origin = getSpobForFaction(cdata.faction)
		backstory.funfacts = {
			_("My clients are the high paying kind."),
			_("My customers keep me happy."),
			_("I enjoy lavishing myself in luxury."),
			fmt.f(_("I own a {ship}, but I don't like to fly it."), {ship = random_ship}),
			fmt.f(_("Did you know that I'm from {origin}?"), backstory),
			fmt.f(_("I don't talk about my customers, but I can tell you about {lover}."), {lover = random_firstname}),
			fmt.f(
				_("{lover} was my first love, we met on {pworld}. Don't ask me what I was doing there."),
				{lover = random_firstname, pworld = getSpobForFaction(faction.get("Raven Clan"))}
			)
		}
	elseif cdata.skill == _("Demolition") then
		-- TODO: right now this is for explosives expert, but we need a generic engineer one
		backstory.intent =
			pick_one(
			{
				_("I love to blow things up."),
				_("You look like you could use a demolition man!"),
				_("I am an explosives expert."),
				_("I'll make sure enemies you board don't come back."),
				_("I like to make things go boom."),
				_("I will blow it into smithereens. Just point the finger and I'll set the charges."),
				_("We're going to have a lot of fun together, believe me.")
			}
		)
		backstory.origin = getSpobForFaction(cdata.faction)
		backstory.funfacts = {
			fmt.f(_("Did you know that I'm from {origin}?"), backstory),
			_("One day, I'd love to rig a Goddard to blow..."),
			fmt.f(_("One day I'll tell you about my first {ship} and what happened to it."), {ship = random_ship}),
			fmt.f(
				_("My last captain named his ship the {shipname}. What an idiot. It had to go, it had to blow."),
				{shipname = lang.getMadeUpName()}
			),
			fmt.f(
				_(
					"One of my last captains almost renamed his ship to {shipname} in a drunken stupor... I made sure that couldn't happen."
				),
				{shipname = lang.getMadeUpName()}
			),
			fmt.f(
				_("I used to have a cousin named {cousin}, but don't ask me what happened to him."),
				{cousin = random_firstname}
			),
			fmt.f(_("You ever heard of the {shipname}? Yeah, that was me."), {shipname = random_lastname}),
			fmt.f(_("You ever heard of the {made_up} explosion? Yeah, I did that."), {made_up = lang.getMadeUpName()})
		}
	else -- something super generic
		backstory.intent =
			pick_one(
			{
				_("I'm looking for a ship to lay low on for as long as you'll have me."),
				_("I'm looking for a ship to lay low on."),
				_("I'm just looking to hang back for a while."),
				_("I was just hoping to catch a ride."),
				_("I'm just hoping to catch a ride to anywhere and maybe get some work along the way."),
				_("I'll hang around for a bit if you don't mind my company."),
				_(
					"I like to make conversation. Maybe I can join your crew and participate in all the fun and excitement that happens on your ship?"
				),
				_("I will keep you company. I'm not sure if you need it, though."),
				_("I've been out of work for a while and am looking for a place to hang my hat."),
				_("I'm looking for a new family."),
				_(
					"I'm looking for a ship for work. I'm not from around here and my last captain traded in his ship to pay off some debt."
				),
				_("I'm a hard worker. I'll make sure your docking clamps are secure every time."),
				_("I'm a good worker. I'll make sure your cargo bay equipment is in order."),
				_(
					"I inherited an interplanetary tea house franchise, but the relative ease of spacetravel completely destroyed the market. It only lasted me seven years. I wish it could have been eight."
				)
			}
		)
		backstory.origin =
			pick_one(
			{
				_("somewhere far away"),
				_("a bad place"),
				_("nowhere"),
				"Janus Station",
				getRandomSpob(),
				_ "Kramer",
				_("Earth"),
				_("the future"),
				lang.getMadeUpName(),
				_("outer space"),
				_("House Goddard"),
				_("Townstead"),
				("Eden")
			}
		)

		-- everyone gets a unique fun fact backstory
		backstory.funfacts = {
			fmt.f(_("I used to work on a {ship}, that was really something."), {ship = getRandomShip()}),
			fmt.f(_("I used to run a side gig where I repaired {thing}s."), {thing = getRandomThing()}),
			fmt.f(_("If anyone asks where I'm from, just tell them I'm from {origin}."), backstory),
			fmt.f(
				_("If anyone asks you where I'm from, tell them I'm from {origin}, see if they believe you."),
				backstory
			),
			fmt.f(_("Don't tell anyone that I'm from {origin}, not that they would believe you."), backstory),
			fmt.f(
				_(
					"I used to work near Crylo and one day, {someone} caught a {fish} so big we were called down to transport it off-world on our Gaiwan."
				),
				{
					someone = pick_one(
						{_("someone"), _("somebody"), _("a youngster"), _("some group"), _("some people")}
					),
					fish = pick_one({_("fish"), _("whale"), _("creature"), _("shark")})
				}
			),
			fmt.f(
				_("I used to work on a {ship} near {place}."),
				{
					ship = getRandomShip(),
					place = getSpobForFaction(pick_one({
						faction.get("Empire"), faction.get("Za'lek")
					})),
				}
			),
			fmt.f(
				_("One of my previous ships had a regular tour of {place}."),
				{place = getSpobForFaction(faction.get("Soromid"))}
			),
			fmt.f(_("My last ship, the {name}, was a {coffin}."), {name = lang.getMadeUpName(), coffin = getSpaceThing()}),
			fmt.f(_("My last captain named his ship the {shipname}. What an idiot."), {shipname = lang.getMadeUpName()}),
			fmt.f(
				_(
					"My last captain named his ship the {shipname}. The thing was a {bettername}. The captain was a {trashname}."
				),
				{shipname = lang.getMadeUpName(), bettername = getSpaceThing(), trashname = lang.getInsultingProperNoun()}
			),
			fmt.f(
				_("One of my last captains almost renamed his ship to {shipname} in a drunken stupor."),
				{shipname = lang.getMadeUpName()}
			),
			pick_one({
			_("I'm not exactly the most useful person, but I'm hoping that nobody will notice."),
			_("I'm not really a hard worker, but I'm hoping that nobody will notice."),
			_("Actually, I am pretty lazy and I think that honesty is a damn good policy."),
			fmt.f(_("I'm a pretty hard worker, at least that's what my {relative} always said."), {relative = pick_one({
					_("mother"), _("father"), _("nephew"), _("neice"), _("cousin"), _("uncle"), _("aunt"), _("grandmother"), _("grandfather"), _("old boss"), _("last employer")
				})}),
			}),
		}
	end
	-- The crewmate also gets a rare and unique looking special fact
	local special_facts = {
		fmt.f(
			_(
				"Actually, I killed someone on my last crew. That's why I'm really here. I'll never forget {name} and that last look."
			),
			{name = pilotname.generic()}
		),
		fmt.f(
			_(
				"I had a secret love affair on my last post. That's why I'm really here. I'll never forget {name} and that kiss goodbye."
			),
			{name = pilotname.human()}
		),
		fmt.f(
			_(
				"I have a large scar on my back. I got it in an altercation between a mighty warlord on {place} due to a misunderstanding."
			),
			{place = getSpobForFaction(faction.get("Dvaered"))}
		),
		fmt.f(
			_(
				"I have a large scar on my leg. I got it in an altercation with a fiesty {person} on {place} after a slight misunderstanding."
			),
			{
				person = pick_one({_("woman"), _("youngster"), _("acrobat"), _("man"), _("warrior")}),
				place = getSpobForFaction(faction.get("Dvaered"))
			}
		),
		fmt.f(
			_("I have a hole in my leg. I got it after a minor misunderstanding with a {person} near {place}."),
			{
				person = pick_one(
					{_("drone"), _("robotic guard"), _("manual firearm"), _("fictional character"), _("badass")}
				),
				place = getSpobForFaction(faction.get("Za'lek"))
			}
		),
		_("I lived on Kramer for over a year. I'll save you the jealousy and spare you the details."),
		_("I killed a man with my bare hands, but I'll spare you the details."),
		_(
			"I killed a man with my bare hands, it was intense. It was me or him. I was obviously outmatched, but I got lucky."
		),
		fmt.f(
			_(
				"I was once a split second from getting blasted into bits by an armed guard near {place} when a masked stranger appeared out of nowhere and swapped out his plasma rifle with an umbrella! Yeah, I didn't believe it when it happened right in front of my eyes either."
			),
			{place = getSpobForFaction(faction.get("Dvaered"))}
		),
		_(
			"Don't tell anyone I told you this, but I once managed to fool a bounty hunter by masking my Quicksilver as a Kestrel. To this day I can't belive he just trusted his sensors and didn't notice the stark differences between a Quicksilver and a Kestrel through the optical interface. Not to mention the difference in size!"
		),
		_("One of my lovers near Zinter is a pyromaniac. I'd stay away from that area.")
	}
	table.insert(backstory.funfacts, pick_one(special_facts))

	return backstory
end

function generateIntroduction(cdata)
	local greetings = {
		_("Hi."),
		_("Hi!"),
		_("Hello."),
		_("Hello!"),
		_("Hi there!"),
		_("Hello there."),
		_("Hi there."),
		_("Greetings."),
		_("Salutations."),
		_("Ni hao."),
		_("Huzzah!"),
		_("Hey!")
	}

	-- I say this if I'm a chatterbox right before asking if I can join the crew
	local preprompts = {
		_("I'd love to join a crew such as yours."),
		_("I'd love to serve on a ship such as yours."),
		_("So..."),
		_("Well anyway..."),
		_("Well, what do you think?")
	}

	local prompts = {
		_("Can I join your crew?"),
		_("What do you say, would you like me on board?"),
		_("Would you like to add me to your roster?"),
		_("Would you like to add me to your crew?"),
		_("Can I live on your ship?"),
		_("What do you say, can I come on board?")
	}

	local reassurances = {
		_("You can count on me!"),
		_("I'll show you, you'll see!"),
		_("You will regret not taking me on!"),
		_("I'll be a good companion."),
		_("I'll be a good crewmate."),
		_("I'll be a hard worker, you'll see."),
		_("Is it obvious that I like to talk? Oh well..."),
		_("I tend to talk a lot, I hope that's okay..."),
		_("My friends say that I'm a bit of a chatterbox...")
	}

	-- just generate a random backstory for now
	local backstory = cdata.conversation.backstory
	local params = {
		greeting = pick_one(greetings),
		prompt = pick_one(prompts),
		preprompt = pick_one(preprompts),
		intent = backstory.intent,
		reassurance = pick_one(reassurances),
		funfact = pick_one(backstory.funfacts),
		skill = cdata.skill,
		name = cdata.name
	}

	-- use chatter to determine how much backstory to give (and maybe.. 'mystery'? nah...)
	local approachtext
	if cdata.chatter < 0.2 then -- I am the strong, silent type
		approachtext = "Hello. {skill}. Need one?"
	elseif cdata.chatter < 0.36 then -- I am a quiet person
		approachtext = "{greeting} {intent} {prompt}"
	elseif cdata.chatter < 0.6 then -- I speak an average amount
		approachtext = "{greeting} I'm {name}. {intent}\n\n{funfact} {prompt}"
	else -- I talk a lot
		if rnd.rnd(0, 1) == 0 then
			approachtext = "{greeting} My name is {name}. {intent} {reassurance}\n\n{funfact} {preprompt} {prompt}"
		else
			approachtext =
				"{greeting} {intent} Oh, did I mention that my name is {name}? {reassurance}\n\n{funfact} {preprompt} {prompt}"
		end
	end

	return fmt.f(approachtext, params)
end


function crewManagerAssessment()
	local troublemaker
	local star
	local min_satisfaction = 0
	local max_satisfaction = 0
	local cumul_satisfaction = 0
	for _i, crew in ipairs(mem.companions) do
		cumul_satisfaction = crew.satisfaction + cumul_satisfaction
		if crew.satisfaction > max_satisfaction then
			max_satisfaction = crew.satisfaction
		elseif crew.satisfaction < min_satisfaction then
			min_satisfaction = crew.satisfaction
			troublemaker = crew
		end
		if not star and crew.satisfaction > 3 and not crew.manager then
			star = crew
		elseif star and crew.satisfaction > star.satisfaction and not crew.manager then
			star = crew
		end
		-- prioritize higher xp crew
		if star and crew.xp * crew.satisfaction > star.xp * star.satisfaction and not crew.manager then
			star = crew
		end
	end
	
	-- if we aren't satisfied to at least 1, let's worry
	if (cumul_satisfaction / #mem.companions) < 1 then
		return "unsatisfied", troublemaker
	end

	-- if someone is at -1, let's worry
	if min_satisfaction <= -1 then
		return "troublemaker", troublemaker
	end

	-- if someone is doing well, notify
	if star then
		return "promising", star
	end
	
	return "satisfied", troublemaker
end

-- returns whether or not an utterance despleases someone
function displeases ( someone, utterance )
	for _i, hate in ipairs(getPreferences(someone).disliked) do
		if string.find(utterance, hate) then
			return true
		end
	end
	return false
end

-- generates an item that scores strongly with most of the crew
function findSuitableDecoration ()
	local scores = {}
	
	-- score every picked noun for every crew member...
	for _i, word in ipairs(
		join_tables(
			pick_some(lang.getAll(lang.nouns)),
			pick_some(lang.getAll(lang.adjectives))
		)
	) do 
		for _j, who in ipairs(mem.companions) do
			local score = scores[word] or 0
			if displeases( who, word ) then
				-- heavy penalty
				scores[word] = score - math.ceil(#mem.companions / 2)
			else
				scores[word] = score + 1
			end
		end
	end

	local picked_adjective, picked_noun
	
	-- now pick a noun and adjective
	table.sort(scores, function (a,b) return a[2] > b[2] end)
	local min_score_a = 1
	local min_score_n = 1
	-- what is this word now? maybe I could have stored it, but whatever, not performance critical here			
	for word, score in pairs(scores) do
		if score >= min_score_n then
			for _j, noun in ipairs(lang.getAll(lang.nouns)) do
				if
					word == noun
					and (not picked_noun or rnd.rnd(1,7) == 0)
				then
					picked_noun = noun
					min_score_n = score / 2
				end
			end
		end
		if score > min_score_a then
			for _j, adjective in ipairs(lang.getAll(lang.adjectives)) do
				if
					word == adjective
					and (not picked_adjective or rnd.rnd(1,7) == 0)
				then
					picked_adjective = adjective
					min_score_a = score / 2
				end
			end
		end
	end
	
	-- we are not guaranteed to find something everyone likes, so need a fallback
	if not picked_adjective then
		picked_adjective = _("vase of")
	end
	
	if not picked_noun then
		picked_noun = _("flowers")
	end
	
	return picked_adjective .. " " .. picked_noun
end

-- generates a suitable gift for personality
function findSuitableGift( personality )
	local liked = {}
	
	for _i, pref in ipairs(getPreferences(personality).liked) do
		-- what is this preference?
		
		-- is it like a color? we want to prioritize this
		for _j, color in ipairs(lang.getAll(lang.adjectives.colors)) do
			if
				string.find(pref, color)
				and not displeases(personality, color)
				and (not liked.color or rnd.rnd(0, 1) == 0)
			then
				liked.color = color
			end
		end
		
		-- is it some other adjective? we want a couple
		for _j, adj in ipairs(
			join_tables(
				lang.getAll(lang.adjectives.positive),
				lang.getAll(lang.adjectives.negative)
			)
		) do
			if
				string.find(pref, adj)
				and not displeases(personality, adj)
				and rnd.rnd(0, 7) >= 5
			then
				if not liked.ad1 and rnd.rnd(0, 3) == 1 then
					liked.ad1 = adj
				elseif not liked.ad2 and rnd.rnd(0, 2) == 1 then
					liked.ad2 = adj
				end
			end
		end
		
		-- is it a noun? we want a good one here, preferably with lots of characters but not always
		local good = rnd.rnd(0, 1)
		local prefers = function (a, b) if good then return a:len() > b:len() else return rnd.rnd(-1, 1) end end
		for _j, noun in ipairs(lang.getAll(lang.nouns.objects)) do
			if
				string.find(pref, noun)
				and not displeases(personality, noun)
				and (not liked.noun or prefers(noun, liked.noun))
			then
				liked.noun = noun
			end
		end
	end
	
	if not liked.noun then
		return _("symbolic gesture") -- we don't know what to give them
	end
	
	-- postprocessing, don't duplicate colors
	if liked.color then
		if liked.ad2 and string.find(liked.ad2, liked.color) then
			liked.ad2 = nil
		end
		
		if liked.ad1 and string.find(liked.ad1, liked.color) then
			liked.ad1 = nil
		end
	end

	-- don't duplicate adjectives
	if liked.ad2 and (not liked.ad1 or string.find(liked.ad2, liked.ad1) or string.find(liked.ad1, liked.ad2) ) then
		liked.ad1 = liked.ad2
		liked.ad2 = nil
	end

	local order = ""
	if liked.ad2 and liked.color then
		order = "{ad2} {color} {ad1} {noun}"
	elseif liked.ad1 and liked.color then
		order = "{ad1} {color} {noun}"	
	elseif liked.color then
		order = "{color} {noun}"
	elseif liked.ad2 then
		order = "{ad2} {ad1} {noun}"
	elseif liked.ad1 then
		order = "{ad1} {noun}"
	else
		order = "{noun}"
	end
		
	return fmt.f(order, liked)
end

-- returns an assessment on the crew members and their psychology
-- returns the assesment string, the troublemaker and a 
-- suggestion for a suitable decoration
function psychologicalAssessment()
	-- start with a basic personnel assessment, then season it with flavor
	local passessment, person = crewManagerAssessment()
	
	-- we can talk to noticeable passengers and figure out where they want to go
	if person and person.typetitle == _("Passenger") then
		passessment = "passenger"
	end
	
	return passessment, person, findSuitableDecoration()
end

--	helper to fetch the max crew even if we aren't on our mothership
function getMaxCrew()
	local max_crew = player.pilot():stats().crew
	local mothership_name = naev.cache().player_mothership or mothership
	if mothership_name and mothership_name ~= player.ship() then
		local commander = getCommander()
		if commander and commander.pilot and commander.pilot:exists() then
			max_crew = commander.pilot:stats().crew
		else
			for _, owned_ship in ipairs(player.ships()) do
				if owned_ship.name == mothership_name then
					max_crew = owned_ship.ship:shipstat("crew")
					break
				end
			end
		end
	end
	return max_crew
end

-- checks if you have a good minimum crew and whether the crew is doing well
-- returns "the assesment" and the subject of the assessment if it is a personnel assessment
function commandAssessment()
	local passessment, person = crewManagerAssessment()
	local max_crew = getMaxCrew()
	local overstaffed = false
	local worst = { ["name"] = _("that guy"), ["firstname"] = _("a troublemaker"), xp = 0, ["article_subject"] = _("he") }
	-- assess general and janitorial strength
	local workers = {}
	workers.janitorial = 0
	workers.general = 0
	workers.security = 0
	for ii, crewmate in ipairs(mem.companions) do
		if ii <= max_crew then
			if
				string.find(crewmate.skill, _("Sanitation"))
				or string.find(crewmate.skill, (_("Janitor")))
			then
				-- janitors can be doubly effective or extremely ineffective
				workers.janitorial = workers.janitorial + math.max(0.25, math.min(2, crewmate.xp * crewmate.satisfaction))
			elseif string.find(crewmate.skill, _("Rookie")) then
				if crewmate.xp < worst.xp then
					worst = crewmate
				end
				workers.general = workers.general + 0.12
				-- we don't have any skills, so we clean as well
				workers.janitorial = workers.janitorial + 0.1
			elseif string.find(crewmate.skill, _("Cadet")) then
				workers.general = workers.general + 0.25
			elseif string.find(crewmate.skill, _("Ensign")) then
				workers.general = workers.general + 1
			elseif string.find(crewmate.skill, _("Lieutenant")) then
				workers.general = workers.general + 0.5
				-- we are responsible, so we clean as well
				workers.janitorial = workers.janitorial + 0.2
				if crewmate.xp >= 100 then
					workers.promotable = crewmate
				end
			elseif string.find(crewmate.skill, _("Security")) then
				workers.security = workers.security + 1
			end
		elseif ii > max_crew then
			overstaffed = true
		end
	end
	local effective_janitors = workers.janitorial + (0.5 * workers.general)
	
	local janitors_needed =  math.floor(math.min(#mem.companions * 0.168 + 0.75, max_crew * 0.16))
	
	if effective_janitors < janitors_needed then
		return _("Sanitation"), nil
	end
	
	if overstaffed then
		return _("Overstaffed"), worst
	end
	
	-- reuse calculation for general work strength
	if workers.general + workers.security + workers.janitorial < math.floor(max_crew * 0.24) then
		return _("Short Staffed"), nil
	end
	
	-- if we can promote someone, let the player know
	if workers.promotable then
		return _("Promotable"), workers.promotable
	end
	
	return passessment, person
end

-- creates a manager component that's only useful for specials
function createUselessManagerComponent()
	local manager = {}
	manager.type = ""
	manager.cost = 0 -- can't be activated if cost is 0
	
	return manager
end

GENERIC_MANAGER_LINES = {}
GENERIC_MANAGER_LINES.satisfied = {
	_("The crew seems happy."),
	_("The crew is content."),
	_("The crew doesn't look so bad at all."),
	_("The crew seems to be enjoying themselves."),
	_("The crew doesn't need any micromanagement at this point."),
	_("The crew doesn't seem to be having any issues."),
	_("The crew's looking good."),
	_("The crew seems to be doing good."),
	_("The crew is performing within parameters."),
	_("The crew is doing well.")
}
GENERIC_MANAGER_LINES.unsatisfied = {
	_("The crew seems unhappy."),
	_("The crew isn't happy."),
	_("The crew doesn't look very happy."),
	_("The crew doesn't seem very happy."),
	_("The crew doesn't look happy."),
	_("The crew doesn't seem happy."),
	_("The crew's in a slump."),
	_("The crew could use a turnaround."),
	_("The crew is getting fatigued."),
	_("The crew needs a change of pace.")
}
GENERIC_MANAGER_LINES.troublemaker = {
	_("We've got some problems with {name}."),
	_("You have a troublemaker in your crew."),
	_("{name} has been performing poorly."),
	_("{name} has been causing some issues."),
	_("{name} has been causing problems."),
	_("{name} has been causing trouble."),
	_("Honestly, we are having {typetitle} problems."),
	_("The {typetitle} situation could be better."),
	_("The {typetitle} situation has been better."),
	_("The {typetitle} problem is getting worse."),
	_("The {typetitle} situation is becoming noticeable."),
	_("The {typetitle} situation needs to be improved."),
	_("I've had some complaints about {name}."),
	_("I've had some complaints."),
	_("We've got some issues with {name}."),
	_("We've got some unresolved tension between {name} and the rest of the crew."),
	_("We've got some unresolved tension some {typetitle} and the rest of the crew."),
	_("We've got some {typetitle} complaining about the rest of the lot."),
	_("Let's not get into it. It's not looking good."),
	_("I don't want to point any fingers."),
	_("Don't say I didn't warn you. Can we leave it at that?")
}
-- the regular personnel manager isn't social, just wants to do payroll
-- companion does the social stuff, but doesn't do payroll
GENERIC_MANAGER_LINES.specific = {
	_("Yes... {article_subject} probably scores around {satisfaction:.0f}."),
	_("Let's see... {article_subject} has an experience level around {xp:.0f} according to my notes."),
	_("That {skill} {typetitle} has an experience level of {xp:.0f} and a happiness score of {satisfaction:.0f}."),
	_("I would put {article_object} at around {satisfaction:.0f} on the happiness scale."),
	_("I'm not quite sure what you want me to tell you about {article_object}."),
	_("I don't really want to talk about {article_object}."),
	_("Do we have to discuss the staff? I'd rather just do payroll."),
	_("I think that {article_subject} is doing fine, stop bothering me."),
	_("I think that {article_subject} is doing fine, do we have to keep talking about {article_object}?"),
	_("Come on, {article_subject} is fine, do we have to keep talking about {article_object}?"),
	_("I think {article_subject} is alright, is something wrong with {article_object}?"),
	_("Why are you asking about {article_object}?"),
	_("I think that {article_subject} is probably doing alright, but you never know. I can only take a guess."),
	_("Do we have to keep talking about {article_object}? {firstname} is just one of the bunch."),
	
}
-- default manager can't recognize exceptional crew
GENERIC_MANAGER_LINES.promising = GENERIC_MANAGER_LINES.satisfied

-- create a generic manager component for crew management (goes into companion.manager)
function createGenericCrewManagerComponent()
	local manager = {}

	manager.type = _("Personnel")
	manager.cost = 3e3 -- how much it costs to "activate" this manager

	manager.lines = GENERIC_MANAGER_LINES

	return manager
end

PSYCHOANALYST_LINES = {
	_("Yes... {article_subject} displays a mood best described as the number {satisfaction:.0f}."),
	_("Let's see... {article_subject} has a preference for {article_of_thought}s according to my notes."),
	_("That {skill} {typetitle} has a happiness score of {satisfaction:.0f}."),
	_("I would put {article_object} at around {satisfaction:.0f} on the happiness scale."),
	_("I would suggest a {article_of_thought} to give {article_object}."),
	_("I know from my conversations with {article_object} that {article_subject} would appreciate a {article_of_thought}."),
	_("Perhaps you can decorate the ship with {article_of_thought}s, I assume you want to try to cheer {article_object} up?"),
	_("I think that {article_subject} would really appreciate a {article_of_thought}."),
	_("I can tell you that {article_subject} would love a {article_of_thought}, perhaps you can give {article_object} one?"),
	_("Someone like {article_object} would probably like a {article_of_thought}."),
	_("I think {article_subject} likes {article_of_thought}s"),
	_("Why don't you get {article_object} a {article_of_thought}?"),
}

MORALE_MANAGER_LINES = {
	_("Yes... {article_subject} probably scores around {satisfaction:.0f}."),
	_("Let's see... {article_subject} has an mood level around {satisfaction:.0f} according to my notes."),
	_("That {skill} {typetitle} has a happiness score of {satisfaction:.0f}."),
	_("I would put {article_object} at around {satisfaction:.0f} on the happiness scale."),
	_("{firstname}? What do you want to know about {article_object}?"),
	_("I don't think you should worry about the {skill}s too much."),
	_("I don't think you should worry about that {typetitle} too much."),
	_("I think that {article_subject} is doing fine, don't even worry about it."),
	_("I think that {article_subject} is doing fine, don't worry about {article_object}."),
	_("Come on, {article_subject} is fine, don't worry about {article_object}."),
	_("I think {article_subject} is alright, is something wrong with {article_object}?"),
	_("Why are you asking about {article_object}? Should I keep an eye on the {skill}s?"),
	_("{firstname}? Should I be keeping a closer eye on the {skill}s?"),
	_("According to my notes, {article_subject}'s got around {satisfaction:.1f} happy chappy points."),
	_("Based on my best judgement, {article_subject} seems to be feeling like a solid {satisfaction:.1f}."),
	_("That {skill} {typetitle} extrudes an aura scoring at about {satisfaction:.1f}."),
	_("That {skill} {typetitle} has a happiness score of {satisfaction:.0f}."),
	_("That {skill} {typetitle} has a satisfaction score of {satisfaction:.0f}."),
	_("That {skill} {typetitle} seems to be around {satisfaction:.0f} in mood."),
	_("{firstname} has a satisfaction score around {satisfaction:.1f}."),
	_("{name}'s current mood is at around {satisfaction:.1f}."),
	_("{name} has a happiness score of {satisfaction:.0f}."),
	_("I would rate {article_object} at around {satisfaction:.0f} these days."),
}

-- this manager needs lines that use the {article_of_thought} that gets planted during the evaluation
function createPsychologicalManagerComponent()
	local manager = createGenericCrewManagerComponent()
	
	manager.lines.specific = PSYCHOANALYST_LINES
		
	manager.lines.passenger = {
		_("Perhaps you should speak with {name}."),
		_("You need to get rid of some of these passengers."),
		_("{name} did complain about not being at {destination}."),
		_("{name} has been complaining about wanting to go to {destination}."),
		_("{typetitle} problems. Yes. We should talk to them."),
		_("The {typetitle} situation could be better."),
		_("I've heard some backtalk about {name}."),
		_("I have heard rumors."),
		_("We should probably keep a better eye on {name}."),
		_("There is some unresolved tension between {name} and the rest."),
		_("Let's not get into it right now. Let me just say that it's not looking good."),
		_("I don't want to point any fingers."),
		_("Don't say I didn't warn you. Can we leave it at that?")
	}
	
	return manager
end

function createMoraleOfficerComponent()
	local manager = createGenericCrewManagerComponent()
	
	manager.lines.specific = MORALE_MANAGER_LINES
	
	return manager
end

-- create a generic crewmate with no special skills whatsoever
function createGenericCrewmate(fac)
	fac = fac or faction.get("Independent")
	local portrait_arg = fac
	-- External commander clients can require a crewmate while the player is in
	-- space, where there is no current spob whose faction could be inspected.
	local pf = fac
	if player.isLanded() then
		pf = spob.cur():faction()
	end
	local lastname, firstname = pilotname.human()
	if pir.factionIsPirate(pf) then
		fac = faction.get("Pirate")
		lastname = pilotname.pirate()
		portrait_arg = "Pirate"
	end
	local portrait_func = portrait.getMale

	local character = {}
	character.gender = "Male"
	character.article_object = "him"
	character.article_subject = "he"
	-- generic character has 50% chance of being male or female
	if rnd.rnd(0, 1) == 1 then
		character.gender = "Female"
		character.article_object = "her"
		character.article_subject = "she"
		portrait_func = portrait.getFemale
	-- TODO: female name
	end
	character.last_paid = time.cur()
	character.name = lastname
	character.firstname = firstname

	character.typetitle = _("Crew")
	character.skill = pick_one({_("Cargo Bay"), _("Sanitation"), _("Janitorial"), _("Maintenance"), _("Security"), _("Rookie"), _("Cadet"), _("Ensign"), _("Lieutenant")})
	character.satisfaction = rnd.rnd(-1, 5) -- there is a chance of hiring a troublemaker or negative nancy
	character.threshold = 1e3 -- how much they need to be happy after doing a paid job
	character.xp = math.floor(10 * (7 + 2 * rnd.threesigma())) / 10
	character.portrait = portrait_func(portrait_arg)
	character.vncharacter = portrait.getFullPath(character.portrait)
	character.faction = fac
	character.chatter = 0.5 + rnd.twosigma() * 0.2 -- how likely I am to talk at any given opportunity
	character.deposit = math.abs(math.ceil(9e3 * character.satisfaction * character.xp + character.chatter * rnd.rnd() * 8e3) + 35e3)
	character.salary = math.abs(math.ceil(1 + character.xp * character.satisfaction) * 1000 * rnd.rnd() + math.ceil(character.chatter * 100)) + 21
	character.other_costs = "Water" -- if you don't have a cost factor, just cost water
	-- seed the original thought with something generic
	character.article_of_thought = pick_one(join_tables({
			_("credit chip"),
			_("spacetravel"),
			_("religion"),
			_("faith"),
			_("book"),
			_("priest"),
			_("passenger"),
			_("male"),
			_("female"),
			_("clown"),
			}, { pick_one(lang.getAll(lang.nouns)) }
		)
	)
	
	local multipliers = {
		[_("Lieutenant")] = 32,
		[_("Ensign")]	= 16,
		[_("Cadet")] = 6,
		[_("Maintenance")] = 3,
		[_("Janitorial")] = 0.8,
	}
	for skill, multiplier in pairs(multipliers) do
	-- generic salary/deposit adjustment based on skill
		if string.find(character.skill, skill) then
			character.salary = character.salary * multiplier + multiplier * multiplier
			character.deposit = (1e3 + character.deposit ) * multiplier
		end
	end
	
	character.pseed = rnd.rnd(1, 9999)
	character.personality = "basic"
	
	character.conversation = {
		["backstory"] = generateBackstory(character),
		-- list of things I like to talk about and what I say about them
		["special"] = {},
	}

	-- TODO HERE: Generate some usages of suitable gift candidates
	-- give the character some unique bar actions
	character.conversation.bar_actions = {
		{
			["verb"] = pick_one(
				{
					_("swirling"),
					_("sipping"),
					_("drinking"),
					_("enjoying"),
					_("nursing"),
					_("nursing on"),
					_("chugging")
				}
			),
			["descriptor"] = pick_one(
				{
					_("a"),
					_("another"),
					_("some"),
					_("some kind of")
				}
			),
			["adjective"] = pick_one(
				{
					_("cheerful"),
					_("bizarre"),
					_("steaming"),
					_("iced"),
					_("chilled"),
					_("extravagant"),
					_("foaming")
				}
			),
			["object"] = pick_one(
				{
					_("drink"),
					_("wine"),
					_("tea"),
					_("concoction"),
					_("elixir"),
					_("mixture of fluids"),
					_("beverage"),
					_("beer"),
					_("coffee"),
					_("spirit")
				}
			)
		}
	}

	return character
end

-- create a generic manager that only knows how to do payroll and assess the crew
function createGenericManager()
	local crewmate = createGenericCrewmate()
	crewmate.manager = createGenericCrewManagerComponent()
	crewmate.manager.skill = "payroll"
	crewmate.typetitle = _("Manager")
	crewmate.skill = crewmate.manager.type
	crewmate.salary = math.ceil(2e3 * crewmate.xp)
	return crewmate
end

function createCommandManagerComponent()
	local lines = merge_tables( {}, GENERIC_MANAGER_LINES ) -- create a copy

	lines.satisfied = join_tables(lines.satisfied, {
		_("I'm feeling positive."),
		_("Business is good."),
		_("Keep up the good work."),
		_("There's something about this place."),
		_("Everyone is having a pleasant time."),
		_("The crew having a lovely time."),
		_("Everyone seems to be enjoying this ship."),
		_("What can I say, we love the ship."),
		fmt.f(_("I'm taking a liking to this {ship}."), {ship = player.pilot():ship():name()}),
		_("I've got a good feeling, things are looking up."),
		_("How about that drink later?"),
		_("I will enjoy a strong but relaxing drink, will you join me?"),
		_("I'll have a nice drink tonight. You can join me if you'd like"),
		fmt.f(
			_("I have been brushing up on my {made_up}. Would you like to spar later on?"),
			{made_up = lang.getMadeUpName()}
		),
		_("I've been talking with some of the crew, they like the available fruit."),
		fmt.f(_("Did I tell you about the creature from {place}?"),
			{place = getSpobForFaction(faction.get("Soromid"))}),
		_("I had to scold some of the crew earlier, I'll spare you the details, it's no big deal."),
		_("I feel like we are on a winning streak."),
		_("I feel like we are on a lucky streak."),
		_("I feel like we are on a lucky roll."),
		_("Things are going alright, aren't they?"),
		_("Things are good, huh?"),
		_("Overall, I'd say things are looking pretty good."),
		_("Sometimes there are bad times, but these aren't the worst of times."),
		_("Things have definitely been worse."),
		_("If we have an eligible shuttle and cargo that we can sell locally, we can send a pilot or I can take it myself. It's a real time saver."),
		_("I've been noticing a lot of positivity among the crew."),
		_("I think most of the crew is fairly happy."),
		_("With a captain like you, it's no wonder we're all so happy. There's nothing to worry about."),
		_("You shouldn't be having any problems with this crew. Everyone seems to be perfectly happy."),
		_("I think the crew could use a drink on a nice luxurious world, but for now there's nothing to worry about."),
		_("Don't worry about the crew, there's nothing wrong that a drink won't fix."),
		_("The crew seems fine. That's not what I'm worried about."),
		_("I wouldn't worry about the crew, at least not for a while."),
	})
	
	local jlabel = _("Sanitation")
	local slabel = _("Short Staffed")
	local olabel = _("Overstaffed")
	local plabel = _("Promotable")
	
	lines[jlabel] = {
		_("You need more janitors doing their job."),
		_("You need more sanitation workers."),
		_("You need more janitorial workers."),
		_("You might need to hire more janitorial staff"),
		_("You might need to motivate janitorial staff"),
		_("The ship is getting dirty, we need more dedication to sanitation."),
		_("We're unable to keep the ship clean as it stands."),
		_("We need more staff dedicated to cleaning."),
		_("We need more focus on the janitorial staff."),
		_("We need more dedication to the cleaning efforts."),
		_("We have to do something about this mess."),
		_("We have to do something about the uncleanliness."),
		_("We have to do something about all the grime."),
	}
	
	lines[slabel] = {
		_("We're a little short staffed."),
		_("We could use some more workers."),
		_("We could use some more crew on general duty."),
		_("We don't have enough crew for a ship of this size."),
		_("We have more tasks that need doing than we have crew members."),
		_("The workload is too high for a crew of this size."),
		_("A ship like this needs a much larger crew."),
		_("We don't have enough crew members on board."),
		_("We need to hire more crew members."),
	}
	
	lines[olabel] = {
		_("We're overstaffed."),
		_("We are paying a lot of workers."),
		_("We could use less crew on general duty."),
		_("We have enough crew for a ship of this size."),
		_("We have too many crew members for a ship of this size."),
		_("We have more crew that need doing than we have tasks."),
		_("A ship like this needs a smaller crew."),
		_("A ship like this needs a tighter crew."),
		_("We don't have enough space for all our crew members on board."),
		_("We should fire some crew members, like maybe {name}."),
		_("We should fire someone with {xp:.0f} experience or less."),
		_("We should fire some crew members, perhaps {firstname}."),
		_([[All you have to do is say  "fire {firstname}" and {article_subject} goes out the airlock.]]),
		_([[If you tell me to  "throw {firstname} out of the airlock" then that's where {article_subject} goes.]]),
	}
	
	lines[plabel] = {
		_([[You have a {skill} that can be promoted. Just say the word.]]),
		_([[You might want to recommend {skill} {name} for a promotion if you've got any unmanned posts.]]),
		_([[{skill} {name} is rising up in the ranks, perhaps {article_subject} is ready for a promotion?]]),
		_([[One of your {skill}s is showing a lot of promise, I think it might be time for a promotion soon.]]),
		_([[If you can find an officer position for {skill} {name}, I'm sure {article_subject}'s dying for the opportunity.]]),
		_([[I remember being a young {skill} once. Those were the days.]]),	-- lines for reminiscing instead of notifying
		_([[Did I ever tell you about my younger years? Boy do I have stories...]]),
		_([[I had a lovely chat with {firstname} recently. It's looking good for sure.]]),
		
	}
	
	lines.promising = {
		_("{firstname} has {xp:.2f} experience points!"),
		_("Everything is looking great, how about that {firstname}?"),
		_("{name} has been showing signs of excellence."),
		_("{name} has been performing exceptionally."),
		_("{firstname} is doing well."),
		_("I've heard a lot of praise about {name}."),
		_("You should keep an eye on {firstname}."),
		_("On a scale of about ten, I'd put one of your {typetitle}'s happiness at around {satisfaction:.1f}."),
		_("On a scale to around ten, I'd put one of your {typetitle}'s experience level at around {xp:.1f}."),
		_("Smooth sailing, just the way I like it."),
		_("Smooth sailing, just how I like it."),
		_("Smooth sailing, exactly as I like it."),
		_("Nothing but clear skies."),
		_("Get a load of that view!"),
		_("Nothing but nebula and adventures ahead."),
		_("We're living the dream."),
		fmt.f(_("Have you heard the one about the {foo} and the {bar}?"), { foo = lang.getMadeUpName(), bar = lang.getMadeUpName() } ),
		fmt.f(_("Have I told you the one about the {foo} and the {bar} in the {thing}?"), { foo = lang.getMadeUpName(), bar = lang.getMadeUpName(), thing = getSpaceThing() } ),
		fmt.f(_("Have I told you the one about the {foo} and the {bar} that tried to destroy the {thing}?"), { foo = getSpaceThing(), bar = lang.getMadeUpName(), thing = getSpaceThing() } ),
		fmt.f(_("A {foo}, a {bar} and a {biz} walk into a {place} searching for some {fruit}... Oh wait, I've told you this one already haven't I?"), { foo = lang.getMadeUpName(), bar = lang.getMadeUpName(), biz = lang.getMadeUpName(), place = getSpaceThing(), fruit = lang.getRandomFruit() } ),
		_("I would really love a banana right about now."),
		fmt.f(_("I would really love a {banana} right about now."), { banana = lang.getRandomFruit() }),
		fmt.f(_("Say, would you like this {banana}?"), { banana = lang.getRandomFruit() }),
		fmt.f(_("Do you want this {banana}? I have another one for me."), { banana = lang.getRandomFruit() }),
		_("Good times ahead."),
		_("How's the budget? The staff is great!"),
		_("If it were appropriate, I would kiss you."),
	}
	
	lines.troublemaker = join_tables(pick_some(lines.troublemaker), {
		_("Perhaps we can commend {name} to try to motivate {article_object}."),
		_("Perhaps you'd like for me to commend {name} to try to motivate {article_object} a bit."),
		_("Perhaps you'd like for me to commend {name} to try to cheer {article_object} up a bit."),
		_("You might want to ask me to restock the bananas."),
		fmt.f(_("You might want to ask me to restock the {banana}s."), { banana = lang.getRandomFruit() } ),
		_([[If you ask me to "restock fruit" with food in our cargo, I'll have it ready by the next time we talk.]]),
		_([[If you ask me to commend {name}, I'll get {article_object} something nice to make {article_object} feel better.]])
	})

	
	lines.specific = pick_some({
		_("Yes... {article_subject} probably scores around {satisfaction:.0f}."),
		_("Let's see... {article_subject} has an experience level around {xp:.0f} according to my notes."),
		_("That {skill} {typetitle} has an experience level of {xp:.0f} and a happiness score of {satisfaction:.0f}."),
		_("I would put {article_object} at around {satisfaction:.0f} on the happiness scale."),
		_("{firstname}? What do you want to know about {article_object}?"),
		_("I don't think you should worry about the {skill}s too much."),
		_("I don't think you should worry about that {typetitle} too much."),
		_("I think that {article_subject} is doing fine, don't even worry about it."),
		_("I think that {article_subject} is doing fine, don't worry about {article_object}."),
		_("Come on, {article_subject} is fine, don't worry about {article_object}."),
		_("I think {article_subject} is alright, is something wrong with {article_object}?"),
		_("Why are you asking about {article_object}? Should I keep an eye on the {skill}s?"),
		_("{firstname}? Should I be keeping a closer eye on the {skill}s?"),
		_("According to my notes, {article_subject}'s got around {xp:.1f} experience."),
		_("Based on my best judgement, {article_subject} seems to be feeling like a solid {satisfaction:.1f}."),
		_("That {skill} {typetitle} has an experience level of {xp:.1f}."),
		_("That {skill} {typetitle} has a happiness score of {satisfaction:.0f}."),
		_("That {skill} {typetitle} has a satisfaction score of {satisfaction:.0f}."),
		_("That {skill} {typetitle} ranks at {xp:.0f} experience and seems to be around {satisfaction:.0f} in mood."),
		_("{firstname} has a satisfaction score around {satisfaction:.1f}."),
		_("{name}'s experience level is around {xp:.1f}."),
		_("{name} has an experience level of {xp:.0f} and a happiness score of {satisfaction:.0f}."),
		_("I would rate {article_object} at around {satisfaction:.0f} these days."),
	})

	-- standard fixes
	table.insert(lines.unsatisfied, _("There is a slight chance of some animosity between the crew."))
	table.insert(lines.unsatisfied, _("There is a slight chance of some hostility within the crew."))
	table.insert(
		lines.unsatisfied,
		_("With a captain like you, it's no wonder we're usually all so happy. I'm sure things will get better.")
	)
	table.insert(
		lines.unsatisfied,
		_("With a captain like you, it's a wonder the situation is so dire. Maybe I can try to motivate them?")
	)
	table.insert(
		lines.unsatisfied,
		_("I wouldn't worry about the crew, but they are getting kind of tense.")
	)
	table.insert(lines.unsatisfied, _("The crew seems fine. That's not what I'm worried about."))
	
	local manager = {}
	manager.lines = lines
	
	return manager
end

function createAdvancedCommandManagerComponent()
	local manager = createCommandManagerComponent()
	table.insert(manager.lines.unsatisfied, _([[Try saying "banana" to me.]]))
	table.insert(manager.lines.unsatisfied, _([[Try saying "list cadets" to me if you're having trouble remembering their names.]]))
	table.insert(manager.lines.unsatisfied, _([[Tell me who or what you're worried about.]]))
	table.insert(manager.lines.unsatisfied, _([[If you tell me to commend myself, I'll use the reward to treat myself.]]))

	table.insert(manager.lines.unsatisfied, _("I hope you know that you can ask me to commend specific crew members for a small fee."))
	table.insert(manager.lines.unsatisfied, _("You might want to ask me to commend specific crew members, it only costs a small fee to be effective."))
	table.insert(manager.lines.unsatisfied, _("You might want to ask me to restock some fruit, it only costs a small fee and a ton of food."))
	table.insert(manager.lines.unsatisfied, _("You might want to ask me to dig out some fruit, it only costs a small fee and a ton of food."))
	table.insert(manager.lines.unsatisfied, _("I won't show you everything I can do. You have to talk to me. Banana?"))

	return manager
end

function createManager( mtype )
	if mtype == _("Manager") then
		return createGenericCrewManagerComponent()
	elseif mtype == _("Psychology") then
		return createPsychologicalManagerComponent()
	elseif mtype == _("Morale") then
		return createMoraleOfficerComponent()
	elseif mtype == _("First Command") then
		return createAdvancedCommandManagerComponent()
	elseif
		mtype == _("Command")
		or mtype == _("Piracy")
	then
		return createCommandManagerComponent()
	end
	print("UNKNOWN MANAGER TYPE: " .. tostring(mtype))
	return createGenericCrewManagerComponent()
end

MANAGERS = {}

-- gets the manager lines of this kind of manager
function getManagerLines( character )
	local mtype = character.manager.type
	-- guard case resource not loaded
	if not MANAGERS[mtype] then
		MANAGERS[mtype] = createManager(mtype)
	end
	local lines = MANAGERS[mtype].lines
	if character.manager.lines then
		lines = {}
		lines = merge_tables(lines, MANAGERS[mtype].lines)
		lines = merge_tables(lines, character.manager.lines)
	end
	return lines
end

-- TODO: Fix conversation
-- TODO NOTE: Add secret fugitives
-- a passenger is a fake crewmate who just takes a slot and wants to get somewhere
-- you pay a small deposit but you get a reward when you drop him off
-- IMHO their best use is to pick them up and sacrifice them for XP, or if you get
-- a passenger paying 3 mil to go to Vilati Vilata of course I'll take them
function createPassenger()
	local crewmate = createGenericCrewmate()
	crewmate.personality = "passenger"
	crewmate.skill = pick_one(append_table({ _("Priest"), _("Scholar"), _("Trader"), _("Executive"), _("Business Expert"), _("Civilian"), _("Worker"), _("Politician"), _("Activist"), _("Researcher"), _("Craftsman") }, lang.getAll(lang.nouns.actors.people))):gsub("^%l", string.upper)
	crewmate.typetitle = _("Passenger")
	crewmate.reward = math.min(3e6, math.ceil( (crewmate.xp + math.abs(crewmate.satisfaction)) * crewmate.salary ) + 2e3)
	crewmate.fmt_reward = fmt.credits(crewmate.reward)
	crewmate.salary = 0
	crewmate.deposit = crewmate.reward * rnd.rnd() * math.min(0.26, rnd.rnd())
	crewmate.other_costs = pick_one({"Food", "Water", "Luxury Goods", "Gold", "equipment"})
	crewmate.destination = spob.getLandable(true)
	-- TODO HERE: randomly a passenger is actually a fugitive and has a hook that spawns enemy bounty hunters
	crewmate.hook = {
		["func"] = "passenger",
		["hook"] = nil
	}

	crewmate.conversation.fatigue = {
		fmt.f(_("I think I'd like to get off at {destination}."), crewmate),
		fmt.f(_("I thought it was all going to be action. But instead it's mostly fear, and a lot of nothing. I wonder when we'll get to {destination}."), crewmate),
	}
	
	crewmate.memories = {
		["travel"] = pick_some({
			fmt.f(_("I think I'd like to go to {destination}."), crewmate),
			fmt.f(_("If you take me to {destination}, I'll give you {fmt_reward}."), crewmate),
			fmt.f(_("If you stop at {destination}, I'll give you {fmt_reward} and get off there."), crewmate),
			fmt.f(_("I'd like to go to {destination} some day."), crewmate),
			fmt.f(_("I think I'd like to visit {destination}."), crewmate),
		})
	}

	crewmate.conversation.backstory.intent = pick_one({
		_("I'm a wayfarer looking to find a new place to hang my hat."),
		_("I'm just a traveler looking to find a new home."),
		fmt.f(_("I'm looking for a ride to someplace. I'm not sure where, maybe {destination}?"), crewmate),
		_("I've traveled the galaxy far and wide. This time I leave my fate up to chance. I'll get off whenever I feel like it."),
		fmt.f(_("I'll give you {fmt_reward} if you take me to a place like {destination}."), crewmate),
		_("I'm lost."),
		_("I don't belong here."),
		_("I escaped from a nearby labour camp and have been on the run ever since. Let me hide out on your ship and I'll get off when it's safe."),
		fmt.f(_("I escaped from a nearby detention facility and have been on the run ever since. Let me hide out on your ship and I'll get off when it's safe. I'll give you {fmt_reward} for your efforts when I get off."), crewmate),
		_("I'm lost. I don't belong here. Can you help me?"),
		_("I don't belong here. Everything went the wrong way. Please help me. I need to get out of here."),
	})
	
	return crewmate
end

-- create a ship psychologist
-- plants article_of_thought into a character sheet from a generated appropriate gift
function createPsychologistManager( fac )
	local crewmate = createGenericCrewmate()
	crewmate.personality = "pleaser"
	crewmate.manager = createPsychologicalManagerComponent()
	crewmate.manager.skill = nil -- no special skills, only assessment, other medical officers will have something	here
	crewmate.manager.type = _("Psychology")
	crewmate.typetitle = _("Councelor")
	crewmate.skill = _("Medical Officer")
	crewmate.salary = math.ceil(4e3 * crewmate.xp) + 12500
	crewmate.deposit = math.ceil(750e3 + (1 - crewmate.chatter) * 300e3)
	crewmate.other_costs = "Medicine"
	crewmate.hook = {
		["func"] = "psychotherapy",
		["hook"] = nil
	}

	-- fix conversation lines
	crewmate.conversation.message = {
		fmt.f( _("{typetitle} {name} on deck.") , crewmate),
		fmt.f( _("{typetitle} {name} on duty.") , crewmate),
		fmt.f( _("{typetitle} {name} reporting.") , crewmate),
		fmt.f( _("{typetitle} {name} reporting in.") , crewmate),
		fmt.f( _("{skill} {name} on deck.") , crewmate),
		fmt.f( _("{skill} {name} reporting for duty.") , crewmate),
	}
	
	-- stifled laughter in captain's company
	crewmate.conversation.special.laugh = {
		_("*snickers* Right, captain?"),
		_("*snickers*"),
		_("*stifled laughter*"),
	}
	
	-- instead of hysteria, we express ourselves openly about work pressure
	crewmate.conversation.special.hysteria = {
		_("The ship could use a {article_of_thought}."),
		_("The workload is getting to me."),
		_("The crew can be hard to manage sometimes. They need a {article_of_thought}."),
		_("There's always a troublemaker in the bunch."),
		_("Wait, what was that?"),
		_("What's going on over here?"),
		_("What is that over there?"),
		_("There's too much going on."),
		_("My ears are ringing."),
		_("I need that drink."),
		_("I could really use a drink right about now."),
		fmt.f(_("Is that a floating {thing}?"), { thing = getSpaceThing() }),
		_("Where are all the {article_of_thought}s?"),
	}
	
	crewmate.conversation.backstory.intent = pick_one({
		_("I am a trained ship psychologist. I will help keep your crew in check and ensure that they don't go too insane."),
		_("I enjoy analyzing the feeble minds of starship crew. You can trust me to keep them in check."),
		_("As long as you have a crew for me to analyze, I'll be ready for action."),
		_("Is your crew feeling down? Maybe you need a ship psychologist."),
		_("I'm a medical officer with psychologist specialization. You need a happy crew if you want them to perform their duties. I've seen too many ships go down in disarray. I'll tell you what your crew members want, they will spill their beans to me. I guarantee it."),
	})
	
	return crewmate
end

function createMoraleOfficer()
	local crewmate = createGenericCrewmate()
	crewmate.personality = "yesman"
	crewmate.manager = createGenericCrewManagerComponent()
	crewmate.manager.type = _("Morale")
	crewmate.manager.skill = _("Stock")	-- TODO: Quartermaster does stock stuff, how to manage him?
	crewmate.skill = _("Morale Officer")
	crewmate.typetitle = _("Officer")
	crewmate.salary = math.ceil(1e3 * crewmate.xp) + 1e3
	crewmate.hook = {
		["func"] = "morale",
		["hook"] = nil
	}
	
	return crewmate
end

-- creates a scientist that does hydroponics farming or whatever
-- converts some water into food (at a fairly bad conversion ratio)
-- produces a free special fruit crate at each harvest (~150-250 periods)
function createScienceFarmer( fac )
	local crewmate = createGenericCrewmate()
	crewmate.manager = createUselessManagerComponent()
	crewmate.manager.type = _("Science")
	crewmate.skill = pick_one({ _("Rookie"), _("Lieutenant"), _("Civilian") })
	crewmate.typetitle = pick_one({ _("Biologist"), _("Algae Farmer"), _("Weed Farmer"), _("Plant Farmer"), _("Microbiologist"), _("Scientist"), _("Researcher") })
	crewmate.hook = {
		["func"] = "hydroponics",
		["hook"] = nil
	}
	
	-- I made food
	crewmate.conversation.message = {
		_("The farm is working."),
		fmt.f( _("{typetitle} {name} reporting positive results in the hydroponics farm.") , crewmate),
		_("The hydroponics farm is functioning within parameters."),
		_("The hydroponics farm is working as expected."),
		fmt.f( _("{typetitle} {name} reporting success in hydroponics farming.") , crewmate),
		fmt.f( _("{skill} {name} on deck, hydroponics farm report: Successful.") , crewmate),
		fmt.f( _("{skill} {name} reporting with positive results with regards to the hydroponics farm.") , crewmate),
	}
	-- instead of hysteria, we express ourselves openly about work pressure
	crewmate.conversation.special.hysteria = {
		_("The pressure might be getting to me."),
		_("The workload is getting to me."),
		_("The plants can be hard to manage sometimes."),
		_("There's always a problem with the water."),
		_("Wait, what was that?"),
		_("What's going on over here?"),
		_("What is that over there?"),
		_("There's too much going on."),
		_("My ears are ringing."),
		_("I need that drink."),
		_("I could really use a drink right about now."),
		fmt.f(_("Is that a floating {thing}?"), { thing = getSpaceThing() }),
	}
	
	crewmate.conversation.backstory.intent = pick_one({
		_("I'm a trained science officer and I'll make sure to convert any excess water into food."),
		_("I have a degree in science that can help the ship. How would you like to convert water into food?"),
		_("Did you know that you can grow plants from just bacteria and sunlight? I'll take the excess waste on your ship and use it as fertilizer to grow food. We'll need water too, but that shouldn't be a problem."),
		_("I have served on some pretty venerable vessels, but I just want to do my science."),
		_("I'm a seasoned science officer. You need a someone like me to grow food on your ship in remote regions of space. You think you can survive without food and water? You can buy food and water, but you'll run out. At that point you can mine ice for water, but the food -- you'll need me for that."),
	})
	
	return crewmate
end

-- TODO: create an advisory officer (can do a command assessment + payroll but no command tasks or command conversation)
-- basically this is the "first officer" before you have a lieutenant

return contract.capture {
	name = "crew_factory",
	requires = { "context", "content.random", "content.character" },
	exports = {
		"getSpobForFaction", "generateBackstory", "generateIntroduction",
		"crewManagerAssessment", "displeases", "findSuitableDecoration",
		"findSuitableGift", "psychologicalAssessment", "getMaxCrew",
		"commandAssessment", "createUselessManagerComponent",
		"GENERIC_MANAGER_LINES", "createGenericCrewManagerComponent",
		"PSYCHOANALYST_LINES", "MORALE_MANAGER_LINES",
		"createPsychologicalManagerComponent", "createMoraleOfficerComponent",
		"createGenericCrewmate", "createGenericManager",
		"createCommandManagerComponent", "createAdvancedCommandManagerComponent",
		"createManager", "MANAGERS", "getManagerLines", "createPassenger",
		"createPsychologistManager", "createMoraleOfficer", "createScienceFarmer",
	},
}

-- converts a crewmate into an officer of <officer_type>
-- an officer needs a bunch of lines to work as a commander
-- we give them here
