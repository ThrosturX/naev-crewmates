local fmt = require "format"
local pilotname = require "crewmates.pilotname"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function add_special(speaker, kind)
	local specials = getConversation(speaker).special
	if not specials then
		return ""
	end
	local choice = pick_key(specials)
	if kind and specials[kind] then
		choice = kind
	end
	-- we have something like "laugh" and need to get the list inside
	local options = specials[choice]

	return pick_one(options)
end

-- returns an evaluation score of this item determining how much satisfaction it will give us to consume
-- or a base score to evaluate receipt on
function evaluate_item( character, item )
	local preferences = getPreferences(character)
	-- we "probably" like this a bit
	local favor = 2 * rnd.rnd() + rnd.twosigma() * 0.4 + 0.12
	for _, liked in ipairs(preferences.liked) do
		if string.find(item, liked) then
			favor = favor + rnd.rnd()
		end
	end
	for _, disliked in ipairs(preferences.disliked) do
		if string.find(item, disliked) then
			favor = favor - rnd.rnd() * 3
		end
	end
	
--	print(fmt.f("evaluate_item {name} scores {item} at {evaluation}.", { name = character.name, item = item, evaluation = favor }))
	return favor
end

-- returns an approximate evaluation score of this item
-- like evaluate_item but a bit careless and depends on the mood
function evaluate_item_haste ( character, item ) 
	local preferences = getPreferences(character)
	local favor = rnd.threesigma() * 0.3
	if character.satisfaction < 0 then
		-- we are negative
		-- assuming we don't like the item that much but expecting to like something
		favor = favor - rnd.rnd() * 0.2
		for _, liked in ipairs(pick_some(preferences.liked)) do
			if string.find(item, liked) then
				favor = favor + rnd.rnd()
			end
		end
	else
		-- we are positive
		-- assuming we like the item and hope that it doesn't disappoint
		favor = favor + rnd.rnd() + 1
		for _, disliked in ipairs(pick_some(preferences.disliked)) do
			if string.find(item, disliked) then
				favor = favor - rnd.rnd() * 2
			end
		end	
	end
	
--	print(fmt.f("evaluate_item_haste {name} scores {item} at {evaluation}.", { name = character.name, item = item, evaluation = favor }))
	return favor
end

-- the character sheet pp is possibly affected by phrase, changing the article of thought
-- has some small potential for garbled thought, which is absolutely fine... if everything goes to plan
function sentimentalize( pp, phrase )
	-- control for preventing execution
	-- this might be expensive, so let's not always execute the logic
	if math.abs(rnd.threesigma()) < 2.4 then
		-- "most of the time, we quit early"
		return
	end
	
	-- calculate how much we listen and how much we like/dislike
	local sentiment_cutoff = 10 * pp.chatter + math.abs(pp.satisfaction)
	local sentiment_score = 0
	local captured_attractor
	local captured_disguster
	local last
	local saved
	local prefs = getPreferences(pp)
	-- okay, the fun begins, lets see if this sentiment attracts our attention
	for word in sanitize_phrase(phrase):gmatch("%w+") do
		if math.abs(sentiment_score) < sentiment_cutoff then
			for _i, found in ipairs(prefs.liked) do
				if string.find(found, word) then
					sentiment_score = sentiment_score + 1
					-- we like something!! check if its a noun
					for _j, noun in ipairs(lang.getAll(lang.nouns)) do
						if string.match(noun, word) then
							captured_attractor = noun
							if last then saved = last end
						end
					end
				end
			end
			for _i, found in ipairs(prefs.disliked) do
				if string.find(found, word) then
					sentiment_score = sentiment_score / 2 - 1
					-- we hate something!! check if its a noun
					for _j, noun in ipairs(lang.getAll(lang.nouns)) do
						if string.match(noun, word) then
							captured_disguster = noun
							if last then saved = last end
						end
					end
				end
			end
		end
		last = word
	end
	
	if sentiment_score > -1 and sentiment_score < 1 then
		-- we didn't really care about this, don't change our thoughts at all
		return
	end
	
	-- more likely to think about the thing we didn't like if there is one
	if sentiment_score < 1 then
		captured_attractor = captured_disguster or captured_attractor
	end
	
	-- common edge case, we said something like "noun was adjective", then it's the last word
	if not saved then saved = last end
	
	-- check if we saved an adjective to adorn our noun with
	if saved and captured_attractor then
		for _i, adj in ipairs(lang.getAll(lang.adjectives)) do
			if saved and string.find(saved, adj) then
				captured_attractor = fmt.f( _([[{adj} {thing}]]), { adj = adj, thing = captured_attractor} )
				saved = nil
			end
		end
	end
	
	-- we have a calculated sentiment, let's not waste it since we are being sentimental
	pp.satisfaction = pp.satisfaction + sentiment_score / (math.abs(sentiment_score) + math.min(16, pp.xp))
	-- update our thoughts if we had one
	pp.article_of_thought = captured_attractor or pp.article_of_thought
end

-- makes sure our sentiments haven't just been cleared before inserting one
-- increases xp a little bit too because we tried to remember something
function insert_sentiment(character, sentiment)
	if not character.conversation.sentiments then
		character.conversation.sentiments = {}
	end

	local sentiments = character.conversation.sentiments
	for _, existing in ipairs(sentiments) do
		if existing == sentiment then
			return
		end
	end

	-- see if we can take a noun from this sentiment and be thinking about it
	sentimentalize(character, sentiment)
	
	table.insert(sentiments, sentiment)
	while #sentiments > 16 do
		table.remove(sentiments, 1)
	end
	character.xp = math.min(100, character.xp + 0.006)
end

-- wrapper to prettify	phrases
function format_dialog( phrase )
	-- add ending punctuation if none found
	local punct_ok = ";:,.!?"
	local punctuation = _(".")
	local last = phrase:sub(-1)
	for i = 1, #punct_ok do
		if last == punct_ok[i] then
			punctuation = ""
		end
	end
	
	-- ensure it starts with capital letter
	return phrase:gsub("^%l", string.upper) .. punctuation
end

-- constructs a phrase that states a fact like
-- apples are good
-- I like bananas
-- I think that organic chemistry is enjoyable
-- If parameters contains a subject, it must contain a verb_subj and can contain a state_subj
-- the plurality parameter only applies to the object for now, because the subject's plurality is controlled by the verb
-- params subject, object, verb_subj, verb_obj, state_subj, state_obj, conjunction, plural, tense
-- you can also construct the phrase with {part_object} or {part_subject} but that's kind of pointless
function construct_phrase_statement(character, parameters)
--[[
	print("construct_phrase_statement")
	for k, v in pairs(parameters) do
		print(k .. ":	\t" .. tostring(v))
	end
	print("construct_phrase_statement end")
--]]	
	local tense = parameters.tense or "present"
	local plurality = parameters.plural or "singular"
	local phrase
	
	if parameters.verb_obj == "auto" then
		parameters.verb_obj = lang.verbs.being[tense][plurality]
	end
	
	-- we want to state a fact about an object
	if parameters.object and parameters.state_obj then
		if plurality ~= "singular" then -- we need to transform the object somehow
			parameters.object = lang.getPlural(parameters.object)
		end
		if parameters.verb_obj then
			parameters.part_object =  fmt.f(_("{object} {verb_obj} {state_obj}"), parameters)
		else
			parameters.part_object =  fmt.f(_("{object} {state_obj}"), parameters)
		end
	elseif parameters.object then
		parameters.part_object = parameters.object
	end
	
	-- we want to state a fact about a subject e.g. john [is|likes being] happy or john likes gold
	if parameters.subject and parameters.verb_subj and parameters.state_subj then
		parameters.part_subject =  fmt.f("{subject} {verb_subj} {state_subj}", parameters)
	elseif parameters.subject and parameters.verb_subj then
		-- we don't have a state of being, so this is "john likes"
		parameters.part_subject =  fmt.f(_("{subject} {verb_subj}"), parameters)
	end
	
	if parameters.part_subject and parameters.part_object then
		-- we want to extend our statement of some object to a subject
		if not parameters.conjunction then
			parameters.conjunction = pick_one(lang.conjunctions.that)
		end
		-- e.g. <john said> <that> <gold is good>
		phrase = fmt.f(_("{part_subject} {conjunction} {part_object}"), parameters)
	elseif parameters.part_subject and not parameters.part_object then
		-- we want to describe a subjects state of being
		-- eg I am tired, you are boring, this is meaningless
		phrase = parameters.part_subject
	elseif parameters.part_object then
		-- we just want to state a fact about some object
		phrase = parameters.part_object
	else
		print("ERROR NO PHRASE")
		for k, v in pairs(parameters) do
			print(k .. ":	\t" .. tostring(v))
		end
	end
	
	return format_dialog(phrase)
end

-- create a random memory
function generate_memory(character)

	local location = system.cur()
	if player.isLanded() then
		-- we are on a planet, it happens here
		location = spob.cur()
	end
	
	local construct_params = {}
	local rndchoice = rnd.rnd(1, 5)
	local other = getCrewmateOnboard()
	if rndchoice == 1 then -- first person
		-- talk about myself, something like " I feel ripe "
		construct_params.subject = _("I")
		-- if the subject is 3rd person singular we need to add a weird s here...
		construct_params.verb_subj = pick_one({
			_("feel"),
			_("want to look"),
			_("look"),
			_("sound"),
			_("think I'm"),
			_("am")
		})
		construct_params.state_subj = pick_one(lang.getAll(lang.adjectives))
		return construct_phrase_statement(character, construct_params)
	elseif rndchoice == 2 then -- second person
		-- talk about you
		construct_params.subject = _("you")
		construct_params.verb_subj = pick_one({
			_("look"),
			_("look a bit"),
			_("seem"),
			_("seem a bit"),
			_("sound a bit"),
		})
		construct_params.state_subj = pick_one(lang.getAll(lang.adjectives))
		return construct_phrase_statement(character, construct_params)
	elseif rndchoice == 3 and other then -- third person
		-- talk about someone else
		
		-- how do we describe them
		if rnd.rnd(0, 1) == 1 then
			construct_params.subject = other.firstname
		elseif rnd.rnd(1, 2) == 2 then
			construct_params.subject = other.name
		else
			construct_params.subject = other.article_subject
		end
		if other.item then
			-- describe what they have
			construct_params.verb_subj = pick_one({
				_("looks to"),
				_("appears to"),
				_("seems to"),
			})
			-- assume that they like it
			construct_params.state_subj = pick_one({
				_("like"),
				_("appreciate"),
				_("enjoy"),
				_("be enjoying"),
				_("be fond of"),
				_("be appreciative of"),
				_("be thankful for"),
			})
			-- construct a conjunction (sorry, I hack it from her->her him->his here)
			construct_params.conjunction = other.article_object:gsub("m", "s") -- this is a hack, sorry
			construct_params.object = other.item
		else
			-- describe how they look
			construct_params.verb_subj = pick_one({
				_("looks"),
				_("appears"),
				_("seems"),
				_("smells"), -- this'll be interesting, just want to see what it produces, you might want to delete this
			})
			construct_params.state_subj = pick_one(lang.getAll(lang.adjectives))
		end
		return construct_phrase_statement(character, construct_params)
	elseif rndchoice == 4 then -- describe some object
		if character.item then
			construct_params.object = character.item
		elseif mem.ship_interior.decoration then
			construct_params.object = mem.ship_interior.decoration
		else
			construct_params.object = pick_one(lang.getAll(lang.nouns.objects))
		end
		
		-- in English we add a determiner
		construct_params.object = fmt.f(_("That {thing}"), { thing = construct_params.object})
		
		local obj_eval = evaluate_item_haste(character, construct_params.object)

		construct_params.verb_obj = "auto"
		construct_params.tense = "past"
		if obj_eval > 1 then
			construct_params.state_obj = pick_one(lang.getAll(lang.adjectives.positive))
		elseif obj_eval < 0 then
			construct_params.state_obj = pick_one(lang.getAll(lang.adjectives.negative))
		else
			construct_params.state_obj = pick_one(lang.getAll(lang.adjectives.neutral))
		end
		
		return construct_phrase_statement(character, construct_params)
	else -- standard choices
		local problem_items = join_tables(
			player.pilot():outfitsList(),
			lang.getAll(lang.nouns.objects.spaceship_parts)
		)
		-- a bunch of random memories that will start to sound repetitive eventually and cause the crew member to seem senile
		local standard_choices = {
			fmt.f(_("I had a thought in {system} but I forgot it."), { system = location } ),
			fmt.f(_("I still think about {system} sometimes."), { system = location } ),
			fmt.f(
				_("I think there's an issue with our {outfit}, I'm going to go and check it out."),
				{outfit = pick_one(problem_items)}
			),
			fmt.f(_("I was just doing a routine {outfit} inspection. I swear."), {outfit = pick_one(problem_items)}),
			fmt.f(
				_("Before you go there, I don't want to hear about the {outfit} problems."),
				{outfit = pick_one(problem_items) }
			),
			fmt.f(_("Before you go there, I don't want to hear about what happened in {system}."),
				{ system = location}
			),
			fmt.f(_("Before you go there, I don't want to talk about what happened back in {system}."),
				{ system = location}
			),
			_("I see that look you're giving me! I was there too you know, let's just drop it!"),
			_("I see that look you're giving me."),
			_("I was there too, just drop it."),
			fmt.f(_("Oh {swear}, not this again, can we just drop it?"), {swear = lang.getMadeUpName()}),
			_("I'm getting real tired of getting all these looks."),
			fmt.f(_("I'll never forget the flight of {shipname}."), {shipname = player.ship()})
		}
		return pick_one(standard_choices)
	end
end

-- creates a memory of a certain kind, or a random memory
function create_memory(character, memory_type, params)
	local topic = pick_one({ _("random things"), _("stuff"), _("small talk"), _("nothing") })
	local new_memory
	if memory_type == "gift" then
		-- we format about ourselves unless the item belongs to someone else (params)
		if not params then params = character end
		-- we were given an item that we appreciated receiving
		-- must have an item on hand!
		local choices = {
			_("I really liked that {item}."),
			_("Did I ever tell you about the {item} I got?"),
			_("I liked that {item}."),
			_("I want more {item}s."),
			_("I like {item}s."),
			_("That {item} was exactly what I needed."),
			_("I love a good {item}."),
			_("Can I have another {item}?"),
			_("Where can I get a {item}?"),
			_("Where can I get another {item}?"),
			_("How do we get {item}s?"),
			_("How do we get more {item}s?"),
			_("Where did we get those {item}s?"),
		}
		new_memory = pick_one(choices)
		
		-- memory READY, extra code here to strengthen it, plug into fatigue conversation
		
		-- since we are creating an (expectedly positive) memory,
		-- we should reminisce about this when we are fatigued
		-- but only if it's a food, otherwise we'll want a random fruit
		-- TODO: factor this logic out to extract a noun descriptor (e.g. letter <of recommendation>)
		local extracted_noun
		
		for _i, noun in ipairs(lang.getAll(lang.nouns.food)) do
			if (
				not extracted_noun 
				or noun:len() > extracted_noun:len()
			) and string.find(character.item, noun)
			then
				extracted_noun = noun
			end
		end
		
		if not extracted_noun then
			extracted_noun = lang.getRandomFruit()
		end
		
		local desires = {
			_("I really want a {item}."),
			_("I'd love a {item} right about now."),
			_("I've got the urge to eat a {item}."),
			_("I want to eat some {item}s"),
			_("I would eat a {item} now if I could, seriously."),
			_("Man, would I love a {item}."),
			_("Where can I get {item}s?"),
			_("I need some {item}s."),
			_("Where did we get those {item}s?"),
			_("Can you hook me up with another one of those {item}s?"),
			_("I want more {item}s."),
			_("How do we get {item}s?"),
			_("How do we get more {item}s?"),
			_("No {item}s..."),
			_("Where are all the {item}s?"),
			_("Where are the {item}s?"),
			_("Where is my {item}?"),
		}

		-- create a "desire" memory
		create_memory(character, "specific", { topic = "fatigue", specific = fmt.f(pick_one(desires), {item = extracted_noun} ) } )
		
	elseif memory_type == "payoff" then
		-- simple case, we got paid, this is a credits memory
		topic = "credits"
		local choices = {
			_("I made {credits} on one of my trips to {planet}."),
			_("I made {credits} on our voyage through {system}."),
			_("I'd like to go to {planet} again sometime.")
		}
		new_memory = pick_one(choices)
	elseif memory_type == "specific" then
		-- we are just learning how to say a new sentence, which should be in our params
		new_memory = params.specific or tostring(params)
	elseif memory_type == "underpaid" then
		topic = pick_one({"credits", "business", _("the captain"), player.name()})
		local choices = {
			_("The captain didn't calculate my salary correctly."),
			fmt.f(_("{name} didn't calculate my salary correctly."), {name	= player.name() }),
		   _("The captain paid me the wrong salary."),
			fmt.f(_("{name} didn't pay me my full salary."), {name	= player.name() }),
			_("My salary wasn't calculated correctly."),
			_("I didn't get my full salary."),
			_("The captain makes a lot of mistakes when it comes to calculations.")
		}
		local cparams = {}
		local paycheck = pick_one({ _("salary"), _("wages"), _("paycheck"), _("compensation") })
		if rnd.rnd(0, 1) == 0 then
			-- subject is captain
			cparams.subject = pick_one({
				_("The captain"),
				player.name(),
				fmt.f(_("Captain {name}"), {name = player.name()}),
			})
			if rnd.rnd(0, 1) == 0 then
				-- paid me the wrong salary
				cparams.verb_subj = _("paid me")
				cparams.conjunction = _("the")
				cparams.object = _("wrong salary")
			else
				-- didn't calculate my salary corrcectly
				cparams.verb_subj = pick_one({
					_("didn't calculate"),
					_("miscalculated"),
				})
				cparams.conjunction = _("my")
				cparams.object = paycheck
				cparams.state_obj = _("correctly")
			end
		elseif rnd.rnd(0, 1) == 0 then
			-- subject is salary
			cparams.object = fmt.f(_("my  {paycheck}"), {paycheck = paycheck} )
			cparams.state_obj = pick_one({
			_("wasn't calculated correctly"),
			_("was miscalculated")
			})
		else -- subject is me
			-- I didn't get my full salary
			cparams.subject = _("I")
			cparams.conqunction = _("didn't")
			cparams.verb_subj = pick_one( { _("get"), _("receive") } )
			cparams.object = pick_one({
				fmt.f(_("my full {paycheck}"), {paycheck = paycheck} ),
				fmt.f(_("the right {paycheck}"), {paycheck = paycheck} ),
				fmt.f(_("my proper {paycheck}"), {paycheck = paycheck} ),
			})
		end
		
		new_memory = construct_phrase_statement(character, cparams)
	elseif memory_type == "friend" then
		-- real quick, make sure we're not memorizing about ourselves
		if character == params then
			print(fmt.f("{name} tried to create a self-memory, but we don't know what to do with those yet", character))
			return
		end
		-- learn about the friend by fetching info from params, which must be a character sheet
		-- hopefully these will become catalysts for further conversation
		local actions = {
			_("I witnessed {name} "),
			_("I was with {name} while {article_subject} was "),
			_("Was {name} really "),
			_("I saw {name} "),
			_("{name}? I saw {article_object} "),
			_("I noticed that {name} was ")
		}
		local when = {
			_(" earlier."),
			_(" the other day."),
			_(" at the bar."),
			_(" in the break room."),
			_(" some time ago."),
			_(" recently."),
			_(", but it feels like ages ago.")
		}
		local topics = getTopics(params)
		local liked_topic = pick_key(topics.liked) or _("things")
		local disliked_topic = pick_key(topics.disliked) or _("things")
		local choices = {
			-- some random memories from the bar
			pick_one(actions) .. getBarSituation(params) .. pick_one(when),
			pick_one(actions) .. getBarSituation(params) .. pick_one(when) .. " " .. add_special(character, "laugh"),
			add_special(character, "laugh") .. " " .. pick_one(actions) .. getBarSituation(params) .. pick_one(when),
			-- remembering that they like some topic (or dislike)
			pick_one(actions) ..
				"talking a lot about things like the err " .. liked_topic .. " or whatever.",
			pick_one(actions) .. "talking about the um " .. liked_topic .. " or whatever.",
			pick_one(actions) ..
				"expressing concern when the conversation was focused on " ..
					 disliked_topic .. ".",
			pick_one(actions) ..
				"expressing concern when the conversation was focused on " ..
					disliked_topic .. pick_one(when),
			-- remembering that we had a special moment in this solar system
			fmt.f(_("{name} and I had a special moment in {system}."), {name = params.firstname, system = system.cur()}),
			fmt.f(_("I had a nice time with {name} in {system}."), {name = params.name, system = system.cur()}),
			construct_phrase_statement(
				character,
				{
					["subject"] = _("I"),
					["object"] = pick_one({ params.name, params.first_name, params.article_object}),
					["verb_subj"] = pick_one({
						_("like"),
						_("had a nice time with"),
						_("enjoy the company of"),
						_("love talking to"),
					})
				}
			),
			construct_phrase_statement(
				character,
				{
					["subject"] = _("I"),			
					["verb_subj"] = pick_one({
						_("think"),
						_("believe"),
						_("always say"),
					}),
					["object"] = pick_one({ params.name, params.first_name, params.article_subject}),
					["verb_obj"] = "auto",
					["state_obj"] = pick_one(lang.getAll(lang.adjectives.positive))
				}
			),
			construct_phrase_statement(
				character,
				{
					["object"] = pick_one({ params.name, params.first_name }),
					["verb_obj"] = "auto",
					["state_obj"] = pick_one(lang.getAll(lang.adjectives.positive))
				}
			),
		}
		local choice = pick_one(choices)
		-- if we're asking a question, let's fix the punctuation real quick
		if string.find(choice, "Was") then
			choice = string.gsub(choice, "%.", "?", 1)
		end

		topic = "friends"
		new_memory = choice
	elseif memory_type == "animosity" then
		-- generate a short insulting phrase
		local starts = {
			"{name}?",
			_("{name}? That"),
			_("That"),
			_("Oh that"),
			_("I should tell you that {name} is nothing but a")
		}
		-- make sure we have a name
		params.name = params.name or lang.getMadeUpName()
		local start = fmt.f(pick_one(starts), params)
		local insult = lang.getInsultingProperNoun()
		local punctuation =
			pick_one(
			{
				".",
				"!",
				"...",
				"!!",
				_("- *sigh*."),
				_(". Yeah. I said it.")
			}
		)
		
		if params.topic then
				topic = params.topic
				local topicsss = tostring(string.gsub(topic, "s+$", ""))	-- not as good as I expected
				punctuation = fmt.f(_(" always blabbers about {topic}."), { topic = params.topic })
		else
			-- this is an aggressive thought, let's classify it as violence
			topic = "violence"
		end
		new_memory = fmt.f("{start} {insult}{punctuation}", {start = start, insult = insult, punctuation = punctuation})
		
	elseif memory_type == "violence" then
		-- this is a violence memory, let's classify it as such
		topic = pick_one({ _("violence"), _("destruction") })
		-- we destroyed a ship, a few generic options, a few specific options,
		-- and a couple of "wow, we sure do a lot of <param>"
		local choices = {
			_("Do you remember that {ship} we got in {system}? It had {credits} in it."),
			_("Man, that {ship}. I still keep thinking about it."),
			_("That {target} never stood a chance."),
			_("Do you remember that {target} we got in {system}? It had {credits} in it."),
			_("Do you remember the {ship}?"),
			_("Do you remember that {target}?"),
			_("Do you remember the {ship}}? The one with {credits} in it."),
			_("I still keep thinking about that {ship} we got in {system}.")
		}
		-- if we got lots of credits
		if params.cred_amt > 25e3 then
			-- wow, that's a lot, actually let's overwrite the default choices
			if params.cred_amt > 187e3 then
				choices = {
					_("I'll never forget that {ship} in {system}."),
					_("{credits} is a lot of credits."),
					_("{system} is actually one of my favourite places to visit."),
					_("{system} is actually one of my favourite places to visit. If you want to know why, I'd tell you to ask a certain {target}, but I'm afraid that's impossible now. Bless the rich bastard."),
					_(
						"My favourite ship to board is the {ship}. Well, I can have many favourites, but that's a top contender for sure."
					),
					_("That {target} never stood a chance."),
					_("That {target} was in the wrong neighborhood, that's for sure."),
					_("That I don't know what a {ship} like that was doing in {system} with {credits} on board."),
					_("I still can't stop thinking about that {ship}!")
				}
				-- small chance of a memorable event
				if character.last_kill and character.last_kill == params.ship then
					table.insert(
						choices,
						"{ship} are incredibly lucrative targets! We got a hundreds of thousand from just a few of them!"
					)
				end
				-- more likely to mention it in a generic manner soon
				insert_sentiment(character, fmt.f(pick_one(choices), params))
				-- this was a lot of credits, this is now a memory about the credits
				topic = pick_one({"credits", "business"})
			end
			-- okay, so if it was a lot we'll still have some other choices, but let's add everything here that's "decent"
			table.insert(choices, _("I like getting big bounties."))
			table.insert(choices, _("Does anyone want to travel to {system} and pray for some credits?"))
			if params.cred_amt > 50e3 then
				table.insert(choices, _("We should hunt more {ship}s."))
				table.insert(choices, _("We should keep hunting {ship}s."))
				table.insert(choices, _("That {ship} we got once had {credits} in it."))
				table.insert(choices, _("Maybe we should go back to {system} to find more {ship}s."))
				table.insert(choices, _("I think we should take a little visit to {system}."))
				-- if we just killed something like this
				if character.last_kill and character.last_kill == params.ship then
					table.insert(choices, _("We sure like to go after those {ship}s."))
					table.insert(choices, _("I feel like we are always hunting {ship}s."))
					table.insert(choices, _("I feel like the only ships we bother with anymore are {ship}s."))
					table.insert(
						choices,
						fmt.f(
							_("That {ship} was nothing but a {spacething} and its captain a {spacefool}."),
							{ship = params.ship, spacething = getSpaceThing(), spacefool = lang.getInsultingProperNoun()}
						)
					)
				end
				-- let's remember this kill more than usual
				character.last_kill = params.ship
				insert_sentiment(character, fmt.f(pick_one(choices), params))
			end
			-- hopefully we'll get a chance to talk about this, maybe multiple times
			insert_sentiment(character, fmt.f(pick_one(choices), params))
			-- the above is a wrapper that makes sure the table exists, it definitely exists now, don't use the wrapper
			table.insert(character.conversation.sentiments, fmt.f(pick_one(choices), params))
			table.insert(character.conversation.sentiments, fmt.f(pick_one(choices), params))
		end

		new_memory = pick_one(choices)
	elseif memory_type == "hysteria" then
		-- we're having a nervous breakdown and are about to have an unreal experience
		local choices = {
			_("Man, what a {ship}, that {target} was a complete waste of {credits}. Am I right?"),
			add_special(character) .. " " .. lang.getMadeUpName() .. " " .. add_special(character, "laugh"),
			add_special(character) .. "... " .. add_special(character) .. "... " .. add_special(character),
			lang.getMadeUpName() .. " " .. lang.getMadeUpName() .. " " .. add_special(character),
			_("Why are we traveling to {system} again? I'd much rather go to {ship}."),
			_("Can't you see it out there? Tell me you can see it? You can see it can't you?"),
			_("Tell me you just saw that, I'm not the only one that just saw that, right?"),
			_("{target}na{target} {ship}ra{target} {system}{ship}{system}da..."),
			_("Why does this say our armour is at {armour} percent? These are percentages right?"),
			_("Why does this say our armour is at {armour} percent? Is that right?"),
			_("Why does this say our armour is at {armour} percent?"),
			-- scary thoughts
			_("This is all too real. I want to go home."),
			_("Sometimes I regret signing up for this."),
			_("I didn't sign up for this."),
			_("When did I sign up for this?"),
			_([[This isn't what I meant when I said "hang my hat"...]]),
			_(
				"Sometimes I can't get the thought out of my head... It's just this thin piece of hull between us and nothingness for distances so vast you can't even realistically imagine."
			),
			-- aggressive ramblings and antisocial tendencies develop
			_("Don't you look at me like that! Don't do it!"),
			_("Hey, watch it!"),
			_("I saw that."),
			_("I know you're about to bring it up, I see that look in your eyes, quit it!"),
			_("Are you looking at me?"),
			_("Maybe all the violence has been getting to me."),
			_("Maybe all the violence is starting to get to me."),
			-- poignant moment such as remembering an old friend or having a epiphany
			fmt.f(_("I miss that rascal {name}. A true friendship never really ends."), {name = pilotname.human()}),
			fmt.f(_("I used to have a friend called {name}."), {name = pilotname.human()}),
			fmt.f(_("I miss my old friend {name}."), {name = lang.getMadeUpName()}),
			_("You know, the best ship is friendship."),
			_(
				"I used to dream of sailing on a pirate ship as a child. Unfortunately, we don't live in that kind of fairy tale world. I did my time on a pirate ship in space, but I realized that what I really wanted was to feel the salty sea air blow across my face and fling my hair into the air."
			),
			_("Maybe I shouldn't be so closed off about my affairs."),
			_("Maybe I shouldn't be so defensive about my affairs."),
			_("I can be a bit evasive when it comes to my affairs."),
			-- borrowed bits to conform with other memories
			_("That {ship} we got once had {credits} in it."),
			_("Maybe we should go back to {system} to find more {ship}s."),
			_("I think we should take a little visit to {system}."),
			_("I was just doing a routine {ship} inspection. I swear."),
			_("I still have scary thoughts about {system}."),
			_("Do you remember when we almost got stranded in {system}?"),
			_("We should probably avoid {system}."),
			generate_memory(character), -- a random memory
		}

		-- have some random thoughts
		insert_sentiment(character, fmt.f(pick_one(choices), params))
		table.insert(character.conversation.sentiments, fmt.f(pick_one(choices), params))
		table.insert(character.conversation.sentiments, fmt.f(pick_one(choices), params))
		-- pick the memory
		new_memory = pick_one(choices)
	else
		-- create a random memory about what we know about
		if not params then
			params = {}
		end
		-- we might need the system, let's make sure we have that
		params.system = params.system or system.cur()

		-- populate our choices with randomly generated memories
		local choices = {
			generate_memory(character),
			generate_memory(character),
			generate_memory(character),
		}

		-- check if this system has places we can refuel
		local can_refuel = false
		for key, spob in ipairs(params.system:spobs()) do
			if spob:canLand() and spob:services()["refuel"] then
				can_refuel = true
			end
		end

		-- check if we are scarily low on fuel and there are no refueling places
		if player.pilot():stats().fuel <= 100 and not can_refuel then
			topic = "travel"
			table.insert(
				choices,
				fmt.f(
					_("I'll never forget the feeling of looking at the gauge and seeing the value read out as {fuel}."),
					{fuel = player.pilot():stats().fuel}
				)
			)
			table.insert(choices, _("I thought we were going to die in {system}."))
			table.insert(choices, _("I still have scary thoughts about {system}."))
			table.insert(choices, _("Do you remember when we almost got stranded in {system}?"))
			table.insert(choices, _("We should probably avoid {system}."))
			-- random chance for this stressful situation to classify this memory as fear
			if rnd.rnd() < 0.16 then
				topic = "fear"
			end
		end

		-- see if some irrational fear kicks in and we become slightly traumatized
		if player.pilot():health() < 96 then
			local stressors = {_("fear"), _("death"), _("weapon"), _("shield")}
			topic = pick_one(stressors)
			-- we might start disliking this topic as well now
			if not getTopics(character).disliked[topic] then
				-- if we like violence or if we have high xp, we resist disliking the stressor
				if getTopics(character).liked.violence and rnd.rnd() > character.xp * character.satisfaction then
					-- dev note: getTopics(character) guarantees NOTALK[character.name] to exist
					NOTALK[character.name][topic] = true
				elseif rnd.rnd() * 2 > character.xp * character.satisfaction then
					NOTALK[character.name][topic] = true
				end
			end
		end

		-- check if we are low on armour
		if player.pilot():health() < 35 then
			-- this is now a violent memory
			topic = "violence"
			table.insert(choices, _("I thought we were going to die in {system}."))
			table.insert(choices, _("I still have scary thoughts about {system}."))
			table.insert(choices, _("Do you remember when we almost got sucked into space that time in {system}?"))
			table.insert(choices, _("We should probably avoid {system}."))
			if player.pilot():health() < 10 then
				-- actually, let's remember this specific system because that's pretty scary
				topic = system.cur():name()
			end
		end

		new_memory = pick_one(choices)
	end

	if not character.memories then
		character.memories = {}
	end
	-- whether we actually like this or not (check dislikes first), this is now a topic we bring up
	if not character.memories[topic] then
		character.memories[topic] = {}
	end

	-- if we have memories of this system, put it there instead so we keep talking about it but don't always say the same thing
	local csn = system.cur():name()
	if character.memories[csn] then
		topic = csn
	end

	-- before we insert the memory, check how big this topic is and prune a bit if necessary
	-- our best crew can have 15 memories each, which I think is still a lot
	local max_memories = math.ceil(character.xp * 0.144)
	if #character.memories[topic] >= max_memories then
		character.memories[topic] = pick_some(character.memories[topic])
	end

	print(fmt.f("{person} created memory about {topic}: <{memory}", {person = character.name, memory = fmt.f(new_memory, params), topic = topic }))
	-- insert the memory to long term memory (gets pruned)
	local fnewmem = fmt.f(new_memory, params)
	table.insert(character.memories[topic], fnewmem)	
	
	-- insert to short term memory (cleared on save/load)
	if not SHORT_TERM_MEMORY[character.name] then
		SHORT_TERM_MEMORY[character.name] = {}
	end
	if not SHORT_TERM_MEMORY[character.name][topic] then
		SHORT_TERM_MEMORY[character.name][topic] = {}
	end
	table.insert(SHORT_TERM_MEMORY[character.name][topic], fnewmem)

	-- have a chance to talk about this memory (think about this memory soon)
	insert_sentiment(character, fmt.f(new_memory, params))

	-- we created a memory, that gives us some experience
	character.xp = math.min(100, character.xp + 0.03)
end

-- the crewmate consumes an item on hand (if any, unless non-consumable *unimplemented) and enjoys it
function crewmate_use_item(character)
	if not character.item then return end
	
	local favor = evaluate_item_haste(character, character.item)
	character.satisfaction = character.satisfaction + favor
	
	
	
	if favor > 2 then
		-- we really liked this item a lot, this item makes our satisfaction influence our xp
		-- at the same time, we cap xp at 2 here because being this happy is a baseline mood
		character.xp = math.max(2, math.min(100, character.xp + character.satisfaction * 0.01))
		create_memory(character, "gift")
	elseif favor > 1 and rnd.twosigma() > 1.5 then
		-- remember enjoying this item
		create_memory(character, "gift")
	elseif favor < 0 then
		local yuck = {
			_("That was something."),
			_("That {item} was terrible."),
			_("I didn't like that {item}."),
			_("I'm glad to be rid of that {item}?"),
			_("Why did I even get this {item}?"),
			_("I didn't want that {item}."),
			_("I didn't really enjoy my {item}."),
			_("I didn't enjoy my {item}."),
			_("I didn't like my {item}."),
			_("I discarded that {item}."),
			_("I threw the {item} in the ") .. pick_one( { _("bin"), _("trash"), _("rubbish") } ) .. ".",
			pick_one(
			{
			_("I jetissoned the "), _("I launched the "), _("I jetissoned that "), _("I jetissoned that stinking "), _("I launched that bloody ") 
			}) .. _(" {item} out the airlock. ") .. add_special(character),
		}
		insert_sentiment(character, fmt.f(pick_one(yuck), character))
	end
	
	-- consume/discard the item
	character.item = nil
end

-- gives the character some item to (hopefully) use later
-- the character carefully inspects the item, judging how much it likes it
function give_item( character, item )
	-- only take the item if we have nothing or if this item appeals to us
	if not character.item or evaluate_item_haste(character, item) > 0 then
		character.item = item
	end
	local evaluation = evaluate_item(character, item) * 0.1
	character.satisfaction = character.satisfaction + evaluation
	if evaluation > 1 then
		-- we must have really liked this item
		create_memory(character, "gift")
	elseif evaluation < 0.04 then
		-- this item was a waste of our time
		local yuck = {
			_("What am I supposed to do with this?"),
			_("What am I supposed to do with this {item}?"),
			_("I didn't like that {item}."),
			_("What am I doing with this {item}?"),
			_("Why do I have a {item}?"),
			_("I don't want this {item}."),
			_("Do you want this {item}?"),
		}
		insert_sentiment(character, fmt.f(pick_one(yuck), character))
	end
end

function has_interest(character, interest)
	if not LOADED[character.name] then
		return false
	end
	for topic, _phrases in pairs(getTopics(character).liked) do
		if topic == interest then
			return true
		end
	end

	return false
end

-- makes speaker speak their message and anything special they might know
-- used to make a champion notify the player that they are doing their mission

return contract.capture {
	name = "memory",
	requires = { "context", "content.random", "content.character" },
	exports = {
		"add_special", "evaluate_item", "evaluate_item_haste", "sentimentalize",
		"insert_sentiment", "format_dialog", "construct_phrase_statement",
		"generate_memory", "create_memory", "crewmate_use_item", "give_item",
		"has_interest",
	},
}
