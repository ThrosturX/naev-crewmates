local fmt = require "format"
local portrait = require "portrait"
local pilotname = require "crewmates.pilotname"
local conversation = require "events.crewmates.conversation"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function promoteToOfficer( crewmate, officer_type, hook_func ) 
	local component_manager = createGenericCrewManagerComponent()
	-- promoted pilots are special because they get their own shuttle
	if crewmate.typetitle == _("Pilot") then
		-- fix manager component for pilots
		crewmate.manager.type = _("Shuttle")
		-- steal the lines from a crew manager
		crewmate.manager.lines = component_manager.lines
		-- promoted pilot owns his own shuttle
		crewmate.shuttle = { ship = ship.get("Alpaca") }

	else
		-- replace the manager component
		crewmate.manager = component_manager

		-- promoted manager gets random management cost
		crewmate.manager.cost = 137e3 / rnd.rnd(3, 15)
		crewmate.manager.type = _("Command")
		
		-- random special manager skill
		if rnd.rnd(1, 6) == 6 then
			crewmate.manager.skill = "payroll"
		end
	end
	
	-- chief of security gains a shuttle for sacrificial active defense
	if
		string.find(officer_type, _("Chief of Security"))
	then	-- TODO: replace Hyena with cargo shuttle?
		crewmate.shuttle = { ship = ship.get("Hyena") }
	end
	
	-- assign the new title reporting directly to the first officer (or the captain if no Commander on deck)
	crewmate.typetitle = _("Lt. Commander")
	crewmate.xp = rnd.rnd(4, 13) -- start with a random amount of xp (how prepared you are for the position)
	local old_skill = crewmate.skill	-- store the old skill if we need it
	if string.find(officer_type, " of ") then
		crewmate.skill = fmt.f(_("{otype}"), {otype = officer_type})
	else
		crewmate.skill = fmt.f(_("{otype} Officer"), {otype = officer_type})
	end
	
	-- standard pay raise
	crewmate.salary = crewmate.salary + 10e3

	local srltlbl = _("Sr. Lieutenant")
	-- if we didn't specify a hook func, do some automatic setup to avoid weird commanders on bridge like the sanitation officer
	if not hook_func then
		-- chief engineer and sanitation officer don't stay on the bridge
		if officer_type == _("Sanitation") then
			hook_func = "sanitation"
			-- actually, we can't be Commanders because we need to keep the mothership clean
			crewmate.typetitle = srltlbl
			crewmate.manager = createUselessManagerComponent()
			crewmate.manager.type = _("Sanitation") -- a red herring, nothing implemented here yet, but nice to have "ship is XX % dirty"
		elseif officer_type == _("Chief Engineer") then
			crewmate.typetitle = srltlbl
			crewmate.skill = _("Chief Engineer")
			crewmate.manager.type = _("Engineering") -- a red herring, nothing implemented here yet
			hook_func = "engichief"
		elseif officer_type == _("Engineer") then
			-- just allows an extra engineer now that this one is promoted
			crewmate.typetitle = _("Sr. Engineer")
			crewmate.skill = old_skill
			hook_func = crewmate.hook.func
		elseif officer_type == _("Security") then
			-- standard security officer, not a proper bridge officer and not a commander
			crewmate.typetitle = srltlbl
			crewmate.manager = createUselessManagerComponent()
			-- a red herring, nothing implemented here yet, but nice to make him talk about victories
			crewmate.manager.type = _("Security")
		elseif officer_type == _("Science") then
			crewmate.typetitle = srltlbl
			crewmate.manager.type = _("Science")
			hook_func = "hydroponics"	
		else	-- default for all bridge officers
			hook_func = "commandAux"
		end
	end
	crewmate.hook = {
		["func"] = hook_func,
		["hook"] = nil
	}
	
	crewmate.personality = "officer" -- TODO: this is default_participation below and some other stuff maybe
	crewmate.conversation.default_participation = {
		_("Of course."),
		_("Sure."),
		_("Yes."),
		_("Good talk."),
		_("Sounds good."),
		_("Yeah."),
		_("Nice."),
		_("Alright."),
		_("I'm a bit busy, but I'll do what I can."),
		_("I'll do what I can."),
		_("I always do my best."),
		_("I'll do my best.")
	}
	
	crewmate.conversation.message = {
		fmt.f( _("{typetitle} {name} on deck.") , crewmate),
		fmt.f( _("{typetitle} {name} on duty.") , crewmate),
		fmt.f( _("{typetitle} {name} reporting.") , crewmate),
		fmt.f( _("{typetitle} {name} reporting in.") , crewmate),
		fmt.f( _("{skill} {name} on deck.") , crewmate),
		fmt.f( _("{skill} {name} reporting for duty.") , crewmate),
	}
	
	-- stifled laughter in captain's company
	crewmate.conversation.special.laugh = { _("Right, captain?") }
	
	-- instead of hysteria, we express ourselves openly about work pressure
	crewmate.conversation.special.hysteria = {
		_("The pressure might be getting to me."),
		_("The workload is getting to me."),
		_("The crew can be hard to manage sometimes."),
		_("There's always a troublemaker in the bunch."),
		_("Wait, what was that?"),
		_("What's going on over here?"),
		_("What is that over there?"),
		_("There's too much going on."),
		_("My ears are ringing."),
		_("I need that drink."),
		_("I could really use a drink right about now."),
		fmt.f(_("Is that a floating {thing}?"), { thing = getSpaceThing() }),
	}
	-- we try to be overly positive no matter what
	crewmate.conversation.special.worry = {
		_("I'm sure there's nothing to worry about."),
		_("Nothing that a drink won't fix."),
		_("Nothing that a little motivation won't fix."),
		_("Nothing that a paradise world won't fix."),
		_("Nothing that a vacation won't fix."),
		_("Nothing that a good payday won't fix."),
		_("I'm sure everything will be alright."),
		_("Everything is fine."),
		_("Everything seems fine to me."),
		_("Things are fine."),
		_("Everything is going to be fine."),
		_("Everything is going to be alright."),
		fmt.f(_("Right {name}?"), {name = player.name()} ),
	}
	
	crewmate.conversation.special.going = {
		fmt.f(_("The {goose} is loose."), { goose = pick_one(lang.nouns.actors.animals.birds) } ),
		_("Shuttle outbound."),
		_("Shuttle mission active. Officer on board."),
		fmt.f(_("{skill} shuttle mission engaged."), crewmate),
		_("Shuttle mission is live."),
		_("Shuttle outbound, see you soon captain."),
	}
	
	crewmate.conversation.special.coming = {
		_("Approach vector set and shuttle inbound."),
		_("Approach vector on course."),
		_("Shuttle inbound."),
		_("Shuttle incoming, stand by."),
		_("Shuttle inbound to dock, please stand by."),
		_("Shuttle on approach vector, stand by for docking."),
		fmt.f(_("{skill} reporting in."), crewmate),
	}
	
	crewmate.conversation.special.arrived = {
		_("Shuttle is docked and secure."),
		_("Docking bays secure. I'm back, Captain."),
		_("Shuttle secure, and so am I."),
		_("Shuttle docked."),
		_("Shuttle safely in the docking bay."),
		_("Docking successful."),
	}

	crewmate.manager.lines = nil -- get elsewhere

	return crewmate
end

-- first officer -- TODO: make sure the player has a lieutenant
-- does payroll and command
-- has a shuttle so you can't have a smuggler
-- probably the player can use the shuttle, and it's probably a shark or something like that
-- the personality is extremely chummy, as the command skill makes it easily excusable
-- the first officer also tries to be more helpful than other crew, those are vagabonds, in disarray
-- the first officer improves upon lesser managers, unlocks new hires and allows you to do
-- crazy things like rename your crew members, throw them out of the airlock, and so on
-- its the only hireable officer that can promote crew past lieutenant status and therefore the player's first commander
function createFirstOfficer()
	local crewmate = createGenericCrewmate()
	crewmate.manager = createGenericCrewManagerComponent()
	-- reuse the promotion template
	crewmate = promoteToOfficer(crewmate, _("First"), "command")
	crewmate.manager.skill = "payroll"
	crewmate.manager.type = _("First Command")
	crewmate.manager.cost = 8e3 -- I'm a commander, I'm expensive
--	crewmate.skill = _("First Officer")
	crewmate.typetitle = _("Commander")
	crewmate.salary = math.ceil(6e3 * crewmate.xp) + 20e3
	crewmate.deposit = math.ceil(2e6 + (1 - crewmate.chatter) * 3e6)
	crewmate.shuttle = { ship = ship.get("Alpaca") }

	crewmate.conversation.special.going = append_table({
		_("The goose is loose."),
		_("Shuttle outbound."),
		_("Shuttle mission active. First Officer on board."),
		_("First Officer shuttle mission engaged."),
		_("Shuttle mission is live."),
		_("Shuttle outbound, see you soon captain."),
	}, crewmate.conversation.special.going)
	
	crewmate.conversation.special.coming = {
		_("Approach vector set and shuttle inbound."),
		_("Approach vector on course."),
		_("Shuttle inbound."),
		_("Shuttle incoming, stand by."),
		_("Shuttle inbound to dock, please stand by."),
		_("Shuttle on approach vector, stand by for docking."),
		_("First Officer reporting in."),
	}
	
	crewmate.conversation.special.arrived = {
		_("Shuttle is docked and secure."),
		_("Docking bays secure, I'm back."),
		_("Shuttle secure, and so am I."),
		_("Shuttle docked."),
		_("Shuttle safely in the docking bay."),
		_("Docking successful."),
	}

	-- custom backstory since we are hired
	crewmate.conversation.backstory.intent = pick_one({
		_("I'm a trained first officer and I'll be ready to assist you on the bridge."),
		_("I can organize shuttle missions or even fly your ship while you go for a joyride. I'll be your number two."),
		_("I have special commander training and will be able to execute various tasks you might ask of me."),
		_("I have served on some pretty venerable vessels, but the captain's seat will always be yours. I don't want that responsibility full time, but I'm ready to share the load with you."),
		_("I'm a seasoned first officer. You need a someone like me to organize your crew and tell them what to do. You think you can just tell a pilot to buy some gold? You tell me to buy some gold, I prep the shuttle, I get the pilot. You sit back on your bridge and summon me if you need anything, or anyone."),
	})
	
	return crewmate
end

-- like a first officer, but the pirate version
function createPirateOfficer( crewmate )
	crewmate = crewmate or createGenericCrewmate()
	if not string.find(crewmate.skill, _("Pirate")) then
		crewmate.skill = pick_one( { _("Pirate Leader"), _("Retired Pirate") } )
	end
	crewmate.manager = createGenericCrewManagerComponent()
	crewmate.manager.type = _("Piracy")
	crewmate.manager.cost = 5e3 -- cheaper than a real commander because I'm a pirate
	crewmate.typetitle = _("Commander")
	crewmate.salary = math.ceil(4e3 * crewmate.xp) + 35e3
	crewmate.deposit = math.ceil(1e6 + (1 - crewmate.chatter) * 2e6)
	crewmate.shuttle = { ship = ship.get("Pirate Hyena") }

	crewmate.hook = {
		["func"] = "commandAux",
		["hook"] = nil
	}
	
	crewmate.conversation.special.going = {
		_("I'm going."),
		_("I'll be back."),
		_("This shouldn't take long."),
	}
	crewmate.conversation.special.coming = {
		_("I'm coming back."),
		_("Hang on, I'm coming."),
		_("Coming back.")
	}
	crewmate.conversation.special.arrived = {
		_("I'm back."),
		_("I'm back, baby."),
		_("Back.")
	}
	crewmate.conversation.backstory.intent = pick_one({
		_("I'm a seasoned pirate leader and I'll be ready to assist you manage your crew."),
		_("I can organize dangerous missions or even fly your ship while you go for a joyride. I'll be your number two."),
		_("I have extensive experience and will be able to execute various tasks you might ask of me."),
		_("I have served on some pretty venerable pirate ships, but the captain's seat will always be yours. I don't want that responsibility anymore, but I'm ready to share the burden with you."),
		_("I'm a seasoned pirate leader. You need a someone like me to organize your pirate crew and tell them what to do. You think you can just hire a bunch of pirates? You need someone to make sure they do their job. You sit back on your bridge and summon me if you need anything, or anyone, or if you need to get rid of someone."),
	})
	
	return crewmate
end

-- creates a "Pilot" that can pilot the shuttle, or perhaps the ship sometimes too if the captain wants autopilot
function createShuttlePilot()
	local crewmate = createGenericCrewmate()
	crewmate.manager = createUselessManagerComponent()
	crewmate.manager.type = _("Shuttle")
	crewmate.typetitle = _("Pilot")
	crewmate.skill = pick_one({ _("Cadet"), _("Ensign"), _("Lieutenant") })
	crewmate.other_costs = pick_one({"Medicine", "Luxury Goods", "Gold", "Diamonds"}) -- maybe some metals for repairs?
	
	crewmate.conversation.message = {
		_("Shuttle en route."),
		_("Shuttle is out."),
		_("Shuttle outbound."),
		_("Shuttle mission is active."),
		_("The shuttle is out."),
		_("I've got it. Shuttle mission active."),
		_("I'm on this. In the shuttle."),
		_("I've got this. Shuttle outbound."),
	}
	
	crewmate.conversation.backstory.intent = pick_one({
		_("Look, I'm a pilot, it's as simple as that."),
		_("I'll fly your ship or any of your shuttles for you."),
		_("As long as you have a shuttle for me to use, I'll be ready for action."),
		_("They say I'm the best in the business. Do you need a pilot or what?"),
		_("I'm a pilot. You need a bay or a dock and a shuttle for me to use. You need a pilot to sell cargo without landing, it saves time, get it?"),
	})
	
	crewmate.conversation.special.going = {
		_("Shuttle en route."),
		_("Shuttle is out."),
		_("Shuttle outbound."),
		_("Shuttle mission is active."),
		_("The shuttle is out."),
		_("I've got it. Shuttle mission active."),
		_("I'm on this. In the shuttle."),
		_("I've got this. Shuttle outbound."),
	}
	
	crewmate.conversation.special.coming = {
		_("Approach vector set and shuttle inbound."),
		_("Approach vector on course."),
		_("Shuttle inbound."),
		_("Shuttle incoming, stand by."),
		_("Shuttle inbound to dock, please stand by."),
		_("Shuttle on approach vector, stand by for docking."),
	}
	
	crewmate.conversation.special.arrived = {
		_("Shuttle is docked and secure."),
		_("Docking bays secure."),
		_("Shuttle secure."),
		_("Shuttle docked."),
		_("Shuttle safely in the docking bay."),
		_("Docking successful."),
	}
	
	return crewmate
end

-- special escort companion doesn't do payroll but is a great satisfaction buffer for the crew
-- basically the kind of crewmate that stands out a bit and is more helpful while the player learns to manage crew
-- eventually the player should aim to replace the companion escort with a personnel manager with the payroll skill
function createEscortCompanion()
	local crewmate = createGenericCrewmate()
	crewmate.manager = createGenericCrewManagerComponent()
	crewmate.typetitle = "Companion" -- generic type, doesn't do anything but might pay rent
	crewmate.skill = "Escort"
	crewmate.satisfaction = rnd.rnd(1, 3)
	crewmate.threshold = 100e3 -- how much they need to be happy after doing a paid job

	crewmate.manager.cost = math.floor(1e3 * crewmate.xp) -- the escort companion is cheaper than a generic manager, depends on starting xp
	-- should give us a fairly low salary, but we probably won't use this field often, or we'll have an exception or something
	crewmate.salary = math.floor(crewmate.xp * crewmate.satisfaction) * 10

	-- the escort companion is a bit more intimate with the captain and will
	-- talk about previous love affairs with characters of the opposite sex
	-- but for some translations, it might make sense to use something else like "my heart"
	-- used like "I wonder what she's up to these days"
	local opposite_article = _("she")
	-- 95% chance of female character to introduce large bias
	if rnd.rnd() < 0.95 then
		crewmate.gender = _("Female")
		crewmate.article_object = _("her")
		crewmate.article_subject = _("she")
		opposite_article = _("he")
		
		crewmate.portrait = pick_one({
			"neutral/female1n",
			"neutral/female2n_nogog",
			"neutral/female3n",
		})
		crewmate.vncharacter = portrait.getFullPath(crewmate.portrait)
		
		-- maybe give her a new name
		if rnd.rnd(0, 1) == 0 then
		crewmate.name = fmt.f("{made_up}{vowel}", {
			made_up = lang.getMadeUpName(),
			vowel = pick_str("aeiouy")
		})
		end
	end

	-- customize the conversation table with new backstory
	crewmate.conversation.backstory = generateBackstory(crewmate)

	-- what I say when I'm doing my job
	crewmate.conversation.message = {"I would never kiss and tell."}
	-- what I say when I'm satisfied
	crewmate.conversation.satisfied = {
		_("I'm feeling positive."),
		_("Business is good."),
		_("Keep up the good work."),
		_("There's something about this place."),
		_("I hope you're all having a pleasant time."),
		_("I hope you're having a lovely time."),
		_("I'm really enjoying this ship."),
		_("I love this ship."),
		fmt.f(_("I'm taking a liking to this {ship}."), {ship = player.pilot():ship():name()}),
		_("I've got a good feeling, things are looking up."),
		_("I will lavish myself in luxury tonight."),
		_("I will enjoy some luxuries tonight."),
		_("I will reap my rewards tonight."),
		fmt.f(
			_("I recently acquired a sample of {made_up}'s latest youth serum. Would anyone care to try some?"),
			{made_up = lang.getMadeUpName()}
		),
		_("I'm expecting a call from a customer soon, I'll spare you the details."),
		fmt.f(_("Did I tell you about the bison from {place}?"), {place = spob.get(faction.get("Dvaered"))}),
		_("I have a scheduled call with a client soon, I'll spare you the details."),
		_("I feel like we are on a winning streak."),
		_("I feel like we are on a lucky streak."),
		_("I feel like we are on a lucky roll."),
		_("Things are going alright, aren't they?"),
		_("Things are good, huh?"),
		_("Were any of you at the party last night? Wait, when was the party again? My sleep cycle is off again."),
		_("Overall, I'd say things are looking pretty good."),
		_("Sometimes there are bad times, but these aren't the worst of times."),
		_("Things have definitely been worse.")
	}
	-- what I say when not satisfied
	crewmate.conversation.unsatisfied = {
		_("I am quite unhappy."),
		_("I've been better."),
		_("I'm not feeling so well."),
		_("I worry about my financial situation."),
		_("I haven't had a good customer in far too long."),
		_("I haven't been able to visit my regular clients."),
		_("My customers are hungry, I don't know what to tell them."),
		_("Are we going anywhere nice soon?"),
		_("Please tell me we are headed towards civilization."),
		_("What in heavens are we even doing out here?"),
		_("My patience is wearing thin."),
		_("I would advise you to tread carefully."),
		_("Don't test me right now."),
		_("My patience is running out.")
	}
	
	-- maybe we don't want the generic things too here, idk
	-- things I say about {name} when I had a good conversation
	crewmate.conversation.good_talker = {
		_("I like talking with {name}."),
		_("I like {name}."),
		_("We've had some good conversations."),
		_("I think {name} likes me."),
		_("{name} is nice."),
		_("{name} seems nice."),
		_("{name} is a dear isn't {article_subject}."),
		_("Isn't {article_subject} a dear."),
		_("{name} is lovely."),
		_("That was pleasant."),
		_("That was pleasant of {article_object}."),
		_("That was nice of {article_object}."),
		_("Don't forget to enjoy the view. Look at that bright one over there. I think it's a moon."),
		_("On a happiness scale to somewhere around ten, I'd put you at around {satisfaction}."),
		_("That was pretty smart for someone with {skill} expertise."),
		_("I wouldn't have expected that from some {typetitle} with {skill} expertise.")
	}
	-- things I say about {name} when I had a bad conversation
	crewmate.conversation.bad_talker = {
		_("{name} is too negative."),
		_("I dislike {name}."),
		_("I dislike {article_object}."),
		_("I'm not fond of {name}."),
		_("I'm not very fond of {article_object}."),
		_("I am not a fan of {name}."),
		_("I'm not friends with {name}."),
		_("I'm not friends with {article_object}."),
		_("I don't want to associate with {article_object}."),
		_("I don't enjoy my conversations with {article_object}."),
		_("I think {article_subject}'s being offensive."),
		_("Sometimes I wonder if you have any {skill} experience at all.")
	}
	
	crewmate.conversation.fatigue = {
		_("I hope we're going somewhere nice."),
		_("I hope we'll land soon, preferably somewhere nice."),
		_("It can be a bit lonely out here sometimes."),
		_("Will someone join me for a spa?"),
		_("I'm going to take a bath later if someone wants to join."),
		_("I could use a break."),
		_("I'm a bit tired."),
		_("I could use some rest."),
		_(
			"You know I need my wealthy planets, don't let me be the black sheep of the bunch that's bringing everyone down."
		)
	}
	crewmate.conversation.bar_actions = join_tables(crewmate.conversation.bar_actions, {
		{
			["verb"] = pick_one(
				{
					_("seducing"),
					_("talking to"),
					_("gesturing at"),
					_("giggling at")
				}
			),
			["descriptor"] = pick_one(
				{
					_("some"),
					_("a"),
					_("a")
				}
			),
			["adjective"] = pick_one(
				{
					_("nice looking"),
					_("strange"),
					_("shady"),
					_("handsome"),
					_("dark"),
					_("mysterious"),
					_("preoccupied"),
					_("unknown")
				}
			),
			["object"] = pick_one(
				{
					_("stranger"),
					_("person"),
					_("man"),
					_("woman"),
					_("interloper"),
					_("dock worker"),
					_("crew member")
				}
			)
		}
	})
	-- special things I know how to say
	-- definitely overwrite whatever was in there before because we might pick
	-- random things from any topic here sometimes and we design the character
	-- "here" and not in the generic template
	crewmate.conversation.special = {
		["laugh"] = {
			_("*giggles*"),
			_("Hah!"),
			_("Haha!"),
			_("*laughs hysterically*"),
			_("*laughs briefly*")
		},
		["worry"] = {
			_("I hope I manage to secure a client on the next world."),
			_("Things just aren't as good as they used to be."),
			_("I'm growing increasingly concerned."),
			_("I feel as if I'm being reduced to nothing."),
			_("We are going to have to do something about that."),
			_("There are situations that need to be addressed."),
			_("From my viewpoint, things could be better."),
			_("I worry about the violence on this ship."),
			_("I'm a bit worried")
		}
	}
	crewmate.conversation.smalltalk_positive = {
		_("What a lovely view."),
		_("I'll be in my quarters."),
		_("I wish I could tell you about my last customer."),
		_("I like being surrounded by all this science."),
		_("Of all my travels, this is my favourite journey so far.")
	}
	-- unique negative smalltalk to be distinguishable from regular crew
	crewmate.conversation.smalltalk_negative = {
		_("I really need a break... To bathe myself in luxury."),
		_("I've seen better days."),
		_("The viewscreen in my quarters is malfunctioning, could you help me repair it?"),
		_("I'm getting tired of all these backwater worlds."),
		_("I'll be in my quarters."),
		_("Business could be better."),
		_("I wish I could tell you about my last customer..."),
		_("What? I don't want to talk about it."),
		_("I'm not making enough credits to keep up with my luxurious lifestyle.")
	}
	
	-- overwrite whatever topics we liked or disliked in our template
	-- list of things I like to talk about and what I say about them
	-- we'll start with a small set of topics/interests and therefore
	-- "be better at learning" because there's less noise to choose from
	crewmate.conversation.topics_liked = {
		-- list of phrases that use the things I like (or not)
		["luxury"] = {
			_("Do you want to see my new hat?"),
			_("How do you like this vintage neck-scarf?"),
			_("What do you think about this color?")
		},
		-- normally, I call this "friend", but I don't want the companion to always
		-- be talking about their friends or cat, at least not that often
		["friendship"] = {
			fmt.f(_("Check out this {ship} my friend thinking of buying."), {ship = getRandomShip()}),
			_("Do you want to see some pictures of my neice?"),
			_("I like how close we are."),
			_("I know we've had our differences, but you're alright."),
			_("I fear that we are becoming a bit too intimate."),
			_("Have I told you about my cat?"),
			_("Did I tell you about my cat?"),
			_("Do you want to see my kitty?"),
			_("Do you want to see my cat?"),
			_("Don't you just love my kitty?")
		},
		["travel"] = {
			fmt.f(
				_("One of my favourite places to visit is {place}. Have you been there?"),
				{place = spob.get(faction.get("Independent"))}
			),
			fmt.f(
				_("I fell in love with a pirate from {place}. I wonder what {article}'s up to these days."),
				{place = spob.get(faction.get("Raven Clan")), name = pilotname.human(), article = opposite_article}
			),
			fmt.f(
				_("If you've never been to {place}, we should go."),
				{place = spob.get(faction.get("Independent"))}
			),
			fmt.f(
				_("An intriguing place to visit is {place}. Have you been there?"),
				{place = spob.get(faction.get("Za'lek"))}
			),
			fmt.f(
				_("I heard that {place} is developing a new {made_up}. What do you make of that?"),
				{place = spob.get(faction.get("Za'lek")), made_up = lang.getMadeUpName()}
			),
			fmt.f(
				_("Of all my travels I must say, I've been too often to {place}. I don't mind the work."),
				{place = spob.get(faction.get("Empire"))}
			),
			fmt.f(
				_(
					"I had an affair with a servant from {place}. I wonder what meddlesome {name} is up to these days."
				),
				{place = spob.get(faction.get("Dvaered")), name = pilotname.human()}
			),
			fmt.f(
				_(
					"All the violence and lawlessness on {place} led my sister {name} towards a path of disastrous affairs."
				),
				{place = spob.get(faction.get("Dvaered")), name = pilotname.human()}
			),
			fmt.f(
				_("I went to {place} just to check it out. I haven't had the urge to go since."),
				{place = spob.get(faction.get("Soromid"))}
			),
			fmt.f(
				_("I went to {place} just to check it out. I don't recommend it."),
				{place = spob.get(faction.get("Soromid"))}
			)
		},
		["view"] = {
			_("Did you enjoy the view?"),
			_("Did you notice the spectacular view towards the star?"),
			_("What a wonderful view. The stars are amazing."),
			_("What an amazing view!"),
			_("What are you looking at?"),
			_("Are you enjoying the view?"),
			_("Keep your hands to yourself or I'll have to charge you some credits."),
			_("I like looking out at the stars."),
			_("How could anyone not admire this view?")
		}
	}
	-- list of things I don't like talking about
	-- put a bunch of things related to violent thoughts here
	crewmate.conversation.topics_disliked = {
		_("violence"),
		_("credits"),
		_("fear"),
		_("death"),
		_("kill"),
		_("poor"),
		_("trash"),
	}
	-- things we say about things we are indifferent to
	crewmate.conversation.default_participation = {
		_("Of course."),
		_("Sure!"),
		_("That sounds good."),
		_("That sounds nice."),
		_("Sounds good."),
		_("Yeah."),
		_("Nice."),
		_("Alright."),
		_("I'm a bit busy, but I'll do what I can."),
		_("I'll do what I can."),
		_("I always do my best."),
		_("I'll do my best.")
	}
	-- responses to conversations about topics I don't like
	-- generally something dismissive but the companion is a bit diplomatic but can be dramatic
	crewmate.conversation.phrases_disliked = {
		_("Do we have to talk about this?"),
		_("All you ever talk about is about {topic}."),
		_("It's {topic} this, {topic} that, you just can't get enough {topic} can you?"),
		_("Whatever."),
		_("Yeah, okay."),
		_("I am not interested in that at all. Can we talk about something else?"),
		_("Sorry, not interested."),
		_("Right."),
		_("Sure."),
		_("Yeah, because of all the {topic}, of course."),
		_("Please give me some privacy."),
		_("I would like to be dismissed."),
		_("I have something else I have to do.")
	}
	
	crewmate.hook = {
		["func"] = "escort",
		["hook"] = nil
	}

	-- fix up the manager lines a bit to add some flavor
	table.insert(crewmate.manager.lines.satisfied, _("I've been noticing a lot of positivity among the crew."))
	table.insert(crewmate.manager.lines.satisfied, _("I think most of the crew is fairly happy."))
	table.insert(
		crewmate.manager.lines.satisfied,
		_("With a captain like you, it's no wonder we're all so happy. There's nothing to worry about.")
	)
	table.insert(
		crewmate.manager.lines.satisfied,
		_("You shouldn't be having any problems with this crew. Everyone seems to be perfectly happy.")
	)
	table.insert(
		crewmate.manager.lines.satisfied,
		_("I think the crew could use a break on a nice luxurious world, but for now there's nothing to worry about.")
	)
	table.insert(
		crewmate.manager.lines.satisfied,
		_("Don't worry about the crew, there's nothing wrong that a spa won't fix.")
	)
	table.insert(crewmate.manager.lines.satisfied, _("The crew seems fine. That's not what I'm worried about."))
	table.insert(crewmate.manager.lines.satisfied, _("I wouldn't worry about the crew, at least not for a while."))

	table.insert(crewmate.manager.lines.unsatisfied, _("The crew seems fine. That's not what I'm worried about."))
	table.insert(
		crewmate.manager.lines.unsatisfied,
		_("I wouldn't worry about the crew, but they are getting kind of tense.")
	)
	table.insert(crewmate.manager.lines.unsatisfied, _("There is a slight chance of some animosity between the crew."))
	table.insert(crewmate.manager.lines.unsatisfied, _("There is a slight chance of some hostility within the crew."))
	table.insert(
		crewmate.manager.lines.unsatisfied,
		_("With a captain like you, it's no wonder we're usually all so happy. I'm sure things will get better.")
	)
	table.insert(
		crewmate.manager.lines.unsatisfied,
		_("With a captain like you, it's a wonder the situation is so dire.")
	)

	crewmate.manager.lines.promising = {
		_("Perhaps you should speak with {firstname}."),
		_("{name} has been showing signs of excellence."),
		_("{name} has been performing exceptionally."),
		_("{firstname} is being followed by good fortune."),
		_("I've heard a lot of praise about {name}."),
		_("You should keep an eye on {firstname}."),
		_("On a scale of about ten, I'd put one of your {typetitle}'s happiness at around {satisfaction:.0f}."),
		_("On a scale to around ten, I'd put one of your {typetitle}'s experience level at around {xp:.0f}."),
	}
	crewmate.manager.lines.troublemaker = {
		_("Perhaps you should speak with {name}."),
		_("You need to listen to your crew."),
		_("{name} did complain about some things."),
		_("{name} has been complaining about some issues."),
		_("{name} has been mentioning problems."),
		_("{name} is being followed by trouble."),
		_("{typetitle} problems. Yes. We should talk to them."),
		_("The {typetitle} situation could be better."),
		_("I've heard some backtalk about {name}."),
		_("I have heard rumors."),
		_("We should probably keep a better eye on {name}."),
		_("There is some unresolved tension between {name} and the rest of the crew."),
		_("Let's not get into it right now. Let me just say that it's not looking good."),
		_("I don't want to point any fingers."),
		_("Don't say I didn't warn you. Can we leave it at that?")
	}
	
	crewmate.manager.lines.specific = {
			_("{firstname} has a satisfaction score around {satisfaction:.0f}."),
			_("{name}'s experience level is around {xp:.1f}."),
			_("{name} has an experience level of {xp:.0f} and a happiness score of {satisfaction:.0f}."),
			_("I would rate {article_object} at around {satisfaction:.0f}."),
		}

	return crewmate
end

-- smuggler hangs out in cargo bay and tries to smuggle commodities to a nearby world that sells them
-- gets bonuses based on cargo bay workers
-- supposed to be a powerful early-game crew
function createSmuggler()
	local crewmate = createGenericCrewmate()
	crewmate.manager = createUselessManagerComponent()
	crewmate.manager.type = _("Stock")
	crewmate.typetitle = _("Smuggler")
	crewmate.skill = _("Smuggler")
	crewmate.salary = 0
	crewmate.bonus = 0
	crewmate.other_costs = pick_one({"Medicine", "Food", "Luxury Goods"})
	crewmate.chatter = 0.2 + rnd.twosigma() * 0.1
	crewmate.deposit = math.ceil(1e6 + (1 - crewmate.chatter) * 2e6)
	crewmate.shuttle = {}
	crewmate.hook = {
		["func"] = "smuggler",
		["hook"] = nil
	}
	crewmate.conversation.backstory.intent = pick_one({
		_("Look, I'm a smuggler, it's as simple as that."),
		_("You point to a planet, you open the cargo bay, I tell you what I can take, capiche?"),
		_("As long as you have a fighter bay on your ship, I should be able to do my job."),
		_("I don't really like talking to strangers. Do you need a smuggler or what?"),
		_("I'm a smuggler. You need a bay or a dock. I'll be in the cargohold if you need me."),
	})
	crewmate.conversation.satisfied = {
		_("I'll be in the cargo bay if you need me."),
	}
	crewmate.conversation.unsatisfied = {
		_("I'll be in the cargo bay if you need me. *scoffs*"),
	}
	crewmate.conversation.good_talker = {
		_("Yeah, {article_subject}'s alright."),
		_("I actually don't mind {article_object} that much."),
		_("I'll be in the cargo bay if you need me."),
	}
	crewmate.conversation.bad_talker = {
		_("Yeah, {article_subject}'s not listening."),
		_("I wanna skin {article_object} so much."),
		_("Drop it."),
		_("Just drop it."),
		_("I'll be in the cargo bay if you need me."),
		fmt.f(_("Maybe some of you would like to play {game} in the cargo bay sometime. It gets lonely."), {game = getShipboardActivity("game") } )
	}
	crewmate.conversation.special.coming = {
		_("Hold on, I gotta realign the docking clamps."),
		_("I'm coming, give me a minute."),
		_("It might take a while to fully align once I'm close enough."),
		_("Hold your horses buster, I'm doing the best that I can here."),
	}
	crewmate.conversation.special.arrived = {
		_("Got it."),
		_("Check your logs."),
		_("Not bad."),
		_("I've seen worse."),
		_("I'm here."),
		_("We're in."),
		_("I'm back."),
	}
	crewmate.conversation.special.going = conversation.basic().message
	
	return crewmate
end

-- hull integrity engineer repairs armour when not under any stress at cost of energy and shields
-- generates a lot of heat but can also repair when near death
-- good for when you want to be able to take armour damage in a shield ship
-- and if you have a lot of armour hitpoints (each uninterrupted healing cycle increases healing bonus)
-- gets bonuses based on maintenance workers
function createArmorEngineer(fac)
	local crewmate = createGenericCrewmate()
	crewmate.faction = fac
	crewmate.typetitle = _("Engineer")
	crewmate.skill = _("Hull Integrity")
	crewmate.salary = 3e3 * (crewmate.xp * crewmate.satisfaction)
	crewmate.other_costs = pick_one({"Diamond", "Ore", "Gold"})
	crewmate.chatter = 0.4 + rnd.twosigma() * 0.2
	crewmate.hook = {
		["func"] = "engihull",
		["hook"] = nil
	}
	crewmate.conversation.message = {
		_("Power levels normal."),
		_("Everything is within parameters."),
		_("Engineering reporting: Everything is OK."),
		_("We're doing fine down here."),
		_("Systems are online."),
		_("We are back to full power."),	
	}
	crewmate.conversation.backstory.intent = pick_one({
		_("Everyone needs an engineer, maybe two."),
		_("I'll make sure your power doesn't go to waste."),
		_("I'm specialized in hull integrity engineering."),
		_("You'll be glad to have an engineer like me on your ship, believe me."),
		fmt.f(_("I once fixed a {thing} on a three hour spacewalk."), {thing = getSpaceThing() } ),
		_("You might need me in a situation, think about that."),
		_("I'll get you out of a tough spot, or rather, I'll keep you in one piece for the trip back."),
		_("Danger is my middle name! Well, within reasonable parameters."),
	})
	crewmate.conversation.special.engine = {
		_("Easy does it..."),
		_("Easy girl..."),
		_("There, girl..."),
		_("There we go..."),
		_("You can do it, come on..."),
		_("I know we can do this..."),
		_("I got this."),
		_("You got this."),
		_("Trust the engine."),
		_("Everything will be alright."),
		fmt.f(_("Come on {made_up} engine don't fail me now."), { made_up = lang.getMadeUpName() }),	
	}
	crewmate.conversation.special.worry = {
		_("Probably."),
		_("If my calculations are correct..."),
		_("Did I double check those calculations?"),
		_("Wait a minute..."),
	}
	
	return crewmate
end

function createPowerEngineer(fac)
	local crewmate = createArmorEngineer()
	crewmate.faction = fac
	crewmate.typetitle = _("Engineer")
	crewmate.skill = _("Core Stabilization")
	crewmate.salary = 3e3 * (crewmate.xp * crewmate.satisfaction)
	crewmate.other_costs = pick_one({"Diamond", "Ore", "Gold"})
	crewmate.chatter = 0.4 + rnd.twosigma() * 0.2
	crewmate.hook = {
		["func"] = "engipowr",
		["hook"] = nil
	}
	crewmate.conversation.message = {
		_("System levels normal."),
		_("Everything is within parameters."),
		_("Engineering reporting: Everything is OK."),
		_("We're doing fine down here."),
		_("Systems are online."),
	}
	crewmate.conversation.backstory.intent = pick_one({
		_("Everyone needs an engineer, maybe two."),
		_("I'll make sure your power doesn't go to waste."),
		_("I'm specialized in reactor engineering."),
		_("You'll be glad to have an engineer like me on your ship, believe me."),
		fmt.f(_("I once fixed a {thing} on a three hour spacewalk."), {thing = getSpaceThing() } ),
		_("You might need me in a situation, think about that."),
		_("I'll get you out of a tough spot, or rather, I'll keep you in one piece for the trip back."),
		_("Danger is my middle name! Well, within reasonable parameters."),
	})
	
	return crewmate
end

function createShieldEngineer(fac)
	local crewmate = createPowerEngineer()
	crewmate.faction = fac
	crewmate.typetitle = _("Engineer")
	crewmate.skill = _("Shield Harmonizing")
	crewmate.salary = 3e3 * (crewmate.xp * crewmate.satisfaction)
	crewmate.other_costs = pick_one({"Water", "Food", "Gold"})
	crewmate.chatter = 0.4 + rnd.twosigma() * 0.2
	crewmate.hook = {
		["func"] = "engishld",
		["hook"] = nil
	}
	
	crewmate.conversation.backstory.intent = pick_one({
		_("Everyone needs an engineer, maybe two."),
		_("I'll make sure your power doesn't go to waste."),
		_("I'm specialized in shield stabilization engineering."),
		_("You'll be glad to have an engineer like me on your ship, believe me."),
		fmt.f(_("I once fixed a {thing} on a three hour spacewalk."), {thing = getSpaceThing() } ),
		_("You might need me in a situation, think about that."),
		_("I'll get you out of a tough spot, or rather, I'll keep you in one piece for the trip back."),
		_("Danger is my middle name! Well, within reasonable parameters."),
	})
	
	return crewmate
end

-- It doesn't get much simpler than this for a custom character,
-- plants explosives after the player boards a hostile natural ship
-- usually it's enough to make sure it doesn't come back
-- uses engineer slot (can only have 2 engineers by default)
function createExplosivesEngineer(fac)
	local character = createGenericCrewmate()
	fac = fac or faction.get("Za'lek")

	local portrait_func = portrait.getMale
	character.gender = "Male"
	character.article_object = "him"
	character.article_subject = "he"
	-- only 35% chance of female character to introduce small bias
	if rnd.rnd() < 0.35 then
		character.gender = "Female"
		portrait_func = portrait.getFemale
		character.article_object = "her"
		character.article_subject = "she"
	end
	character.name = pilotname.generic()
	character.typetitle = ("Engineer")
	character.skill = _("Demolition")
	character.satisfaction = rnd.rnd(1, 3)
	character.xp = math.floor(10 * (1 + rnd.sigma())) / 10
	character.portrait = portrait_func()
	character.faction = fac
	character.chatter = 0.3 + rnd.threesigma() * 0.1 -- how likely I am to talk at any given opportunity (could be NEVER!)
	character.deposit = math.ceil(100e3 * character.satisfaction * character.xp + character.chatter * rnd.rnd() * 10e3)
	character.salary = 0
	character.other_costs = "equipment"
	-- the explosives expert is a bit of a weirdo and gets his own custom conversation sheet
	-- actually that's a good way for me to find out if refactoring is breaking stuff
	character.conversation = {
		["backstory"] = generateBackstory(character),
		-- what I say when I'm doing my job
		["message"] = {
			_("The bomb has been planted."),
			_("The fuse has been lit."),
			_("The fuse is set."),
			_("Explosives in place."),
			_("I've set the charges."),
			_("Bombs in place."),
			_("Kaboom!"),
			_("Boom!"),
			_("Let's go!"),
			_("Bombs away..."),
			_("Can we stay and watch this one? It's gonna blow in a bit."),
			_("Special delivery."),
			_("Who needs stern chasers when you've got explosives?"),
			_("She's set to blow."),
			_("Fire in the hole!"),
			_("Fire in the hole."),
			_("Fire. Hole."),
			_("Tick tick tick..."),
			_("Tick tock..."),
			_("I've dropped a bomb."),
		},
		-- what I say when I'm satisfied
		["satisfied"] = {
			_("I'm happy."),
			_("What can I say? It's a good day."),
			_("I feel alive."),
			_("I feel so alive."),
			_("I feel great."),
			_("I feel fantastic."),
			fmt.f(_("I feel like {million}!"), {million = fmt.credits(1e6 * rnd.rnd(1, 10))})
		},
		-- what I say when not satisfied
		["unsatisfied"] = {
			_("I am unhappy."),
			_("Everything is bleak."),
			_("I want to use my explosives."),
			_("I'm bored."),
			_("I'm so bored."),
			_("I'm really bored."),
			_("There's nothing to do around here."),
			_("Nothing ever happens around here."),
			_("Nothing ever happens on this ship."),
			_("There's no action on this ship."),
			_("This ship is so boring."),
			_("It's too quiet here.")
		},
		-- things I say about or back to {name} when I had a good conversation
		["good_talker"] = {
			_("I like talking with {name}."),
			_("{name} is nice."),
			_("Well, {article_subject}'s nice."),
			_("This was nice."),
			_("Bitchin'."),
			_("Cool."),
			_("Awesome."),
			_("Kaboom."),
			_("Kaplow."),
			_("Boom!"),
			_("Bombs away!"),
			_("Radical! Pun intended."),
			_("Well that's pretty sweet."),
			_("Isn't this nice."),
			_("Isn't this lovely."),
			_("That's great."),
			_("Yeah, yeah. I know. I'm with you."),
			_("Yeah, I'm with you."),
			_("Yeah, I know. I'm with you."),
			_("Don't look at me, I'm with {article_object} on this.")
		},
		-- things I say about {name} when I had a bad conversation
		["bad_talker"] = {
			_("{name} is a downer."),
			_("I don't like {name}. How many times do I have to say it?"),
			_("I don't like you, {name}."),
			_("Screw {name}."),
			_("To hell with {name}."),
			_("Bah!"),
			_("Screw it."),
			_("To hell with it."),
			fmt.f(
				_("That little {made_up} can go float {article_object}self."),
				{made_up = lang.getMadeUpName(), article_object = "{article_object}"}
			),
			_("To hell with {article_object}!"),
			_("Can you see the look I'm giving {article_object}?"),
			_("{name} gets to do anything {article_subject} likes."),
			_("Everything is always about {name}, isn't it?"),
			_("Everything is about {article_object}, isn't it?")
		},
		["fatigue"] = {
			_("Are we going to do something anytime soon?"),
			_("It's cold out there in space. Even with the explosions."),
			_("I want more explosions."),
			_("I could use a drink."),
			_("I need a drink."),
			_("I need a drink, damn it!"),
			_("I'm kind of beat."),
			_("I could use some shut-eye."),
			_("Where's my hat? Someone bring me my hat!"),
			_("Man I got too many bombs and not enough booms."),
			_("Where's all the action?"),
			_("I want to destroy a Goddard."),
			fmt.f(_("I want to destroy a {ship}"), {ship = getSpaceThing() } ),
			_("Where's the strong stuff?"),
			_("I need some of the good stuff."),
			_("Where's a heavy drink when you need one?"),
			_("Either my brain's going to explode or a nearby ship. That's for sure.")
		},
		["bar_actions"] = {
			{
				["verb"] = pick_one(
					{
						_("seducing"),
						_("talking to"),
						_("gesturing at"),
						_("staring at")
					}
				),
				["descriptor"] = pick_one(
					{
						_("some"),
						_("a"),
						_("a")
					}
				),
				["adjective"] = pick_one(
					{
						_("tall"),
						_("strange"),
						_("shady"),
						_("handsome"),
						_("dark"),
						_("mysterious"),
						_("preoccupied")
					}
				),
				["object"] = pick_one(
					{
						_("stranger"),
						_("person"),
						_("vagabond"),
						_("piece of art"),
						_("interloper"),
						_("hologram"),
						_("animal")
					}
				)
			},
			{
				["verb"] = pick_one(
					{
						_("motioning"),
						_("signaling"),
						_("gesturing"),
						_("communicating")
					}
				),
				["descriptor"] = pick_one(
					{
						_("with his"),
						_("by waving his"),
						_("by moving his")
					}
				),
				["adjective"] = pick_one(
					{
						_("hand"),
						_("hands"),
						_("arms"),
						_("legs"),
						_("fingers"),
						_("ears"),
						_("eyes"),
						_("eyebrows"),
						_("tongue")
					}
				),
				["object"] = pick_one(
					{
						_("in the air"),
						_("towards a table"),
						_("over his chest"),
						_("around his face"),
						_("inconsistently"),
						_("like a maniac"),
						_("without regard to his surroundings")
					}
				)
			}
		},
		-- special things I know how to say
		["special"] = {
			["laugh"] = {
				_("*laughs maniacally*"),
				_("*laughs hysterically*"),
				_("*laughs frantically*"),
				_("Heh."),
				_("*chuckles*"),
				_("*cackles*"),
				_("Hehe."),
				_("Right? *laughs*"),
				_("*laughs*"),
				_("Am I right? Anyone?"),
				_("Right?"),
				_("Am I right or what?"),
				_("Yallahahahaha!"),
				_("*coughing laughter*"),
				_("*laughs while coughing*"),
				_("*asphyxiating laughter*"),
				_("Whoops, where did my lucky cigar go?")
			},
			["random"] = {
				_("Tick tock!"),
				_("Shakalakalaka!"),
				_("Kaboom!"),
				_("BOOM!"),
				_("Aha!"),
				_("Tick tock..."),
				_("Tickety tock..."),
				_("It's time to say goodnight."),
				_("Close your eyes, it's gonna get bright.")
			},
			["worry"] = {
				_("I hope I remembered to set the fuse..."),
				_("Oh, wait a minute..."),
				_("Did I get that right?"),
				_("At least I hope I'm right."),
				_("If everything goes to plan."),
				_("Maybe."),
				_("I think."),
				_("I think..."),
				_("I'm pretty sure."),
				_("Time will tell."),
				_("My lucky cigar never fails me."),
				_("Do you have it?")
			}
		},
		["smalltalk_positive"] = {
			_("Do you guys remember the last ship we boarded?"),
			_("What was the name of that last ship? She went down beautifully."),
			_("I'll be in my quarters if you need me."),
			_("I'm going to go hang out with the cargo."),
			_("Let me know if you need anything.")
		},
		["smalltalk_negative"] = {
			_("It's been a while since we paid anyone a special kind of visit, if you know what I mean."),
			_("Why don't we ever get dirty anymore?"),
			_("Do you guys remember the last ship we boarded?")
		},
		-- list of things I like to talk about and what I say about them
		["topics_liked"] = {
			-- list of phrases that use the things I like (or not)
			["violence"] = {
				fmt.f(_("Check out this {ship} I got to destroy."), {ship = getRandomShip()}),
				fmt.f(_("Have I told you about the {ship} I destroyed during my training?"), {ship = getRandomShip()})
			},
			["friendship"] = {
				fmt.f(_("Check out this {ship} I'm thinking of buying."), {ship = getRandomShip()}),
				fmt.f(_("Check out the custom paintjob on this {ship}!"), {ship = getRandomShip()}),
				fmt.f(_("My old friend {name} would love this."), {name = pilotname.human()}),
				fmt.f(_("I'm sure {name} would appreciate this place."), {name = pilotname.human()})
			},
			["science"] = {
				fmt.f(_("Check out the landing gear on this {ship}!"), {ship = getRandomShip()}),
				fmt.f(_("Have you seen the new {ship} features?"), {ship = getRandomShip()}),
				fmt.f(_("I heard about some unexplained phenomena at {place}."), {place = spob.get(true)}),
				fmt.f(
					_("I wonder what the mystery about {place} is, maybe I missed something."),
					{place = spob.get(true)}
				),
				fmt.f(
					_(
						"I thought I saw a {ship} following me past {place}, my sensors were going crazy, but then I saw it with my own eyes. It was a comet!"
					),
					{ship = getRandomShip(), place = spob.get(true)}
				)
			}
		},
		-- list of things I don't like talking about, words I don't like hearing
		["topics_disliked"] = {
			_("luxury"),
			_("luxurious"),
			_("soap"),
			_("lotion")
		},
		-- things we say about things we are indifferent to
		["default_participation"] = {
			_("Err.. Yeah!"),
			_("Sure!"),
			_("That sounds good."),
			_("Yeah."),
			_("Nice."),
			_("Boom, baby!")
		},
		-- responses to conversations about topics I don't like
		["phrases_disliked"] = {
			_("Do we have to talk about this?"),
			_("All you ever talk about is {topic}."),
			_("It's {topic} this, {topic} that, you just can't get enough {topic} can you?"),
			_("Whatever."),
			_("Yeah, okay."),
			_("Right."),
			_("Sure."),
			_("Yeah, because of all the {topic}, of course.")
		}
	}
	character.hook = {
		["func"] = "demoman",
		["hook"] = nil
	}

	return character
end

-- creates a random engineer
function createEngineer(fac)
	local choice = rnd.rnd(0, 3)
	
	if choice == 0 then
		return createArmorEngineer(fac)
	elseif choice == 1 then
		return createShieldEngineer(fac)
	elseif choice == 2 then
		return createPowerEngineer(fac)
	end
	
	return createExplosivesEngineer(fac)
end

--	decide what crew the player gets to encounter here

return contract.capture {
	name = "crew_factory_officers",
	requires = { "context", "content.random", "crew_factory" },
	exports = {
		"promoteToOfficer", "createFirstOfficer", "createPirateOfficer",
		"createShuttlePilot", "createEscortCompanion", "createSmuggler",
		"createArmorEngineer", "createPowerEngineer", "createShieldEngineer",
		"createExplosivesEngineer", "createEngineer",
	},
}
