local fmt = require "format"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

local function contains_ci(haystack, needle)
	if type(haystack) ~= "string" or needle == nil then
		return false
	end
	return haystack:lower():find(tostring(needle):lower(), 1, true) ~= nil
end

function speak_notify(speaker)
	local conversation = getConversation(speaker)
	local message = pick_one(conversation.message)

	if conversation.special and rnd.rnd(0, 1) == 1 then
		message = message .. " " .. add_special(speaker)
	end

	_comm(fmt.f(_("{typetitle} {name}"), speaker), message, "F")
end

-- records an interaction about one of reactor's disliked topics brought up by offender
-- might create a memory like "offender talks about topic too much"
function dislike_topic(topic, reactor, offender)
	-- reactor doesn't like offender as much, decrease satisfaction and record a sentiment
	reactor.satisfaction = reactor.satisfaction - 0.03

	-- this is a low priority sentiment, use the table instead of the head
	insert_sentiment(reactor, fmt.f(pick_one(getConversation(reactor).bad_talker), offender))

	-- try to create a memory about this event
	if rnd.rnd() < reactor.chatter then
		create_memory(reactor, "animosity", {name = offender.name, topic=topic})
	end
end

-- returns the keyword that evaluator didn't want to hear
function dislikes_phrase(phrase, evaluator)
	for disgust, _bool in pairs(getTopics(evaluator).disliked) do
		if contains_ci(phrase, disgust) then
			return disgust
		end
	end

	return false
end

-- returns the keyword that evaluator is interested in
function doeslike_phrase(phrase, evaluator)
	for interest, _phrases in pairs(getTopics(evaluator).liked) do
		if contains_ci(phrase, interest) then
			return interest
		end
	end

	return false
end

-- returns a list of appropriate responses and the topic that sparked interest
function appreciate_spoken(spoken, appreciator)
	-- first check if we dislike something
	local disgust = dislikes_phrase(spoken, appreciator)
	local conversation = getConversation(appreciator)
	if disgust then
		-- just pick the one we want now, because we want to format it with the topic
		return {
			fmt.f(pick_one(conversation.phrases_disliked), {topic = disgust})
		}, disgust
	end

	-- check if we are do like something
	local interest = doeslike_phrase(spoken, appreciator)
	if interest then
		return getTopics(appreciator).liked[interest], interest
	end

	-- we don't care about this at all
	return conversation.default_participation, nil
end

-- attempt to generate a list of valid responses based on what was said
function generate_responses(spoken, crewmate)
	local responses, topic = appreciate_spoken(spoken, crewmate)

	-- this is a topic we like talking about or that we dislike
	if topic then
		return responses
	end

	-- try to figure out if there is something that looks like a question or doubt that we can agree/disagree with
	local doubters = {
		_("who"),
		_("what"),
		_("why"),
		_("when"),
		_("know"),
		_("sure")
	}

	for _, doubt in ipairs(doubters) do
		if string.find(spoken, doubt) then
			return getConversation(crewmate).default_participation
		end
	end

	-- we still don't know what this is, generate some responses about our irritation
	local imaginary_topic =
		pick_one(
		{
			_("*inaudible*"),
			_("*expletive*"),
			lang.getMadeUpName(),
			extract_keyword(spoken) or _("nonsense")
		}
	)

	-- are we being shouted at? If so, we can use that as a topic
	if spoken == spoken:upper() and spoken:len() > 0 then
		table.insert(responses, _("There's no need to shout.")) -- it's funny because there are dialog lines about being hard of hearing
		imaginary_topic = "shouting"
	end

	for _i, phrase in ipairs(getConversation(crewmate).phrases_disliked) do
		table.insert(responses, fmt.f(phrase, {
			topic = imaginary_topic,
			name = "{name}",
			article_object = "{article_object}",
			article_subject = "{article_subject}",
			firstname = "{firstname}",
		}))
	end

	return responses
end

-- calculate the interaction between starter and partaker
-- note that starter can by anyone here, even the player
-- but the partaker is a proper topiced character that must like topic if we get here
-- returns the partaker's response after hearing about their liked topic
function interact_topic(topic, starter, partaker)
	local responses = getTopics(partaker).liked[topic]
	partaker.satisfaction = partaker.satisfaction + 0.02

	-- we like each other now, maybe remember that, but depends on the conversation partner whether we create a memory or not
	local who = rnd.rnd(0, 5)
	if who == 0 then
		if starter.conversation then -- this check is required to make sure that you don't try to create a memory for the player
			starter.conversation.sentiment = fmt.f(pick_one(getConversation(starter).good_talker), partaker)
			if rnd.rnd() < partaker.chatter then
				create_memory(starter, "friend", partaker)
			end
			starter.satisfaction = starter.satisfaction + 0.12 -- we made a friendship bond stronger
		end
	elseif who == 1 then
		partaker.conversation.sentiment = fmt.f(pick_one(getConversation(partaker).good_talker), starter)
		if rnd.rnd() < starter.chatter then
			-- make sure starter isn't the player because we don't know how we'll do those memories
			if starter.conversation then
				create_memory(partaker, "friend", starter)
			end
		end
	end -- otherwise, we forget about it

	return responses
end

-- listener "hears" what is spoken and forms an opinion about speaker
-- returns a response appropriate to the reaction and the object of reaction if any
function analyze_spoken(spoken, speaker, listener)
	-- see if we can appreciate what was said to us
	local responses, topic = appreciate_spoken(spoken, listener)
	
	if topic then
		-- see if it was good or bad
		if dislikes_phrase(spoken, listener) then
			dislike_topic(topic, listener, speaker)
			local conversation = getConversation(listener)
			responses = join_tables(join_tables(
					responses, conversation.bad_talker),
					conversation.smalltalk_negative
				)
			return fmt.f(pick_one(responses), speaker)
		else -- we like talking about this!
			-- calculate the interaction (the listener's response) to speaker mentioning topic
			return pick_one(interact_topic(topic, speaker, listener)), topic
		end
	end
	-- we don't have a topic, we don't understand
	-- lets do a simple analysis so that we seem like we know what we're saying or why we're saying it
	local analysis = {}
	-- check if it was a question
	analysis.index = spoken:find("?", 1, true)
	if analysis.index then -- it was probably a question
		-- what was it about?
		if contains_ci(spoken, "remember")
			or contains_ci(spoken, "are you")
			or contains_ci(spoken, "does")
			or contains_ci(spoken, "do ")
			or contains_ci(spoken, "play")
			or contains_ci(spoken, "right")
		then
			-- seeking affirmation
			analysis.question = "affirm"
		elseif contains_ci(spoken, "when") then
			-- asking about time
			analysis.question = "time"
		elseif contains_ci(spoken, "why")
			or contains_ci(spoken, "what")
		then
			-- asking something specific
			analysis.question = "specific"
		elseif contains_ci(spoken, "is")
			or contains_ci(spoken, "can ")
			or contains_ci(spoken, "i ")
		then -- asking something we're probably unsure about and makes us feel uncomfortable
			analysis.question = "affirm_negative"
		end
	end

	-- check if it has my name or article in it (right now, I don't think about other peolpe)
	if contains_ci(spoken, listener.name)
		or contains_ci(spoken, listener.firstname)
		or contains_ci(spoken, listener.article_subject)
		or contains_ci(spoken, listener.article_object)
		then
		analysis.subject = "me"
	end
	
	-- if it was a question and it was about me, respond appropriately
	if analysis.question and analysis.subject == "me" then 
		-- TODO: need a sentiment evaluator
		return pick_one(getConversation(listener).default_participation), listener.name
	elseif analysis.question then
	-- if it wasn't about me, respond as directed
		if analysis.question == "affirm" then
			-- nice to feel included in conversation
			listener.satisfaction = listener.satisfaction + 0.01
			return pick_one(getConversation(listener).default_participation), "small talk"
		elseif analysis.question == "affirm_negative"
			or analysis.question == "time" then
			-- making me uncomfortable
			listener.satisfaction = listener.satisfaction - 0.01
			return pick_one(getConversation(listener).unsatisfied), nil
		end
	end
	
	-- if we still have nothing, also do a deep search of our topics
	-- this will degrade performance as the memory table grows and
	-- hopefully give us the kick we need to start pruning it
	local topics = getTopics(listener)
	local liked = topics.liked
	local disliked = topics.disliked
	analysis.choices = {}
	local brief = sanitize_phrase(spoken)
	for my_topic, phrases in pairs(liked) do
--		print("checking liked topic with phrases", my_topic, phrases)
		if #analysis.choices == 0 then
			for _, phrase in ipairs(pick_some(phrases)) do
				local extracted = extract_keyword(phrase)
				-- let's see if we think they might be talking about this
				if contains_ci(brief, extracted) then
					table.insert(analysis.choices, my_topic)
				end
			end
			
			-- satisfaction decreases because I have to think about more topics
			-- otherwise I risk looking like an idiot blurting out the first thing I say
			listener.satisfaction = listener.satisfaction - 0.001 * (#analysis.choices - 3)
		end
	end
	
	
	if #analysis.choices >= 1 then
		-- I think I know what topic they're talking about, let's try to talk about it
		for _i, keyword in ipairs(analysis.choices) do
			if disliked[keyword] then
				-- we didn't want to talk about this
				listener.satisfaction = listener.satisfaction - 0.05
				return fmt.f(pick_one(getConversation(listener).phrases_disliked), speaker), keyword
			end
		end
		local like = pick_one({
			_("I like talking"),
			_("I enjoy talking"),
			_("I enjoy partaking in conversations"),
			_("I like being included when we talk"),
			_("I feel included when we talk"),
			_("I like to talk"),
			_("Let's talk more"),
			_("Let's talk"),
			_("It's nice to talk"),
		})
		-- feel like we are having a good conversation
		topic = pick_one(analysis.choices)
		print(fmt.f("picked topic <{topic}> from <{source}>.", {topic = topic, source = spoken} ))
		listener.satisfaction = listener.satisfaction + 0.03
		insert_sentiment(listener, fmt.f([[{like} about {topic}.]], { like = like, topic = topic }))
		local subject = speaker
		return fmt.f(pick_one(interact_topic(topic, speaker, listener)), subject), topic
	else
		-- we have no idea what the hell you're saying, fallback to default
		print(fmt.f("{listener} didn't understand when {speaker} said <{spoken}>.", {listener=listener.name, speaker=speaker.name, spoken = spoken }))

		-- continue with smalltalk, or whatever this is and adjust the satisfaction slightly
		responses = {
			_("Whatever."),
			_("Yeah, okay."),
			fmt.f(_("Okay, {name}."), speaker),
			fmt.f(_("Aright, {name}."), speaker),
			_("Sure."),
			_("Oh, really?")
		} -- default responses
		responses = join_tables(responses, getConversation(listener).default_participation)
		
		-- if both speakers are happy, increase their satisfaction a little bit from the interaction
		if speaker.satisfaction > 0 and listener.satisfaction > 0 then
			speaker.satisfaction = speaker.satisfaction + 0.01 -- it was a good chat
			listener.satisfaction = listener.satisfaction + 0.01 -- thanks for including me
			-- we had a good conversation, let's remember our partner maybe
			if rnd.rnd() > speaker.chatter / 2 then
				insert_sentiment(speaker, fmt.f(pick_one(getConversation(speaker).good_talker), listener))
				if not listener.conversation.sentiment then
					listener.conversation.sentiment = fmt.f(pick_one(getConversation(listener).good_talker), speaker)
				end
			end
			-- if the listener isn't very chatty, they will remember this
			if rnd.rnd() > listener.chatter then
				listener.conversation.sentiment = fmt.f(pick_one(getConversation(listener).good_talker), speaker)
			end
		elseif speaker.satisfaction < 0 and listener.satisfaction < 0 then
			-- penalize negative banter quite heavily
			speaker.satisfaction = speaker.satisfaction - 0.04 -- I didn't get my attention
			listener.satisfaction = listener.satisfaction - 0.02 -- why you gotta drag me into this
			if not listener.conversation.sentiment then
				if rnd.rnd(0, 7) == 0 then
					listener.conversation.sentiment = fmt.f(pick_one(getConversation(listener).bad_talker), speaker)
				end
			end
			insert_sentiment(speaker, fmt.f(pick_one(getConversation(speaker).bad_talker), listener))
		else
			-- feel randomly about this interaction, slightly weighted towards negative
			speaker.satisfaction = speaker.satisfaction + math.floor(10 * rnd.threesigma()) / 1000 - 0.01
			listener.satisfaction = listener.satisfaction + math.floor(10 * rnd.threesigma()) / 1000 - 0.0075
		end
		-- retain having not understood this
		local sentiment_options = {
			[[I didn't really get it when {speaker} said "{spoken}".]],
			[[I don't really listen to {speaker} much.]],
			[[{speaker} says stuff all the time, but I don't pay much attention to it.]],
			[[{speaker} says stuff all the time, but I don't pay much attention to it. Should I?]],
			[[{spoken} *chuckles*]],
		}
		insert_sentiment(listener, fmt.f(pick_one(sentiment_options), {speaker=speaker.name, spoken = spoken }))
		return fmt.f(pick_one(responses), speaker), nil
	end
end

-- talker tries to start a conversation with other about topic
function converse_topic(topic, talker, other)
	local my_topics = getTopics(talker).liked
	local choices = my_topics[topic]

	-- this should be a logically impossible branch but I leave it here 
	-- for the free feedback in case I made a mistake somewhere
	if not choices then
		local tname = talker
		local oname = other
		if tname then tname = talker.name end
		if oname then oname = other.name end
		print(fmt.f("converse_topic no choices {topic} {talker} {other}", {topic = topic, talker=tname, other=oname}))
		return
	end
	
	-- snip-in: we might want to do something with subject some analysis whatever
	local subject = talker -- for now, we talk about ourselves
	-- speak the chosen phrase
	_comm(fmt.f("{typetitle} {name}", talker), fmt.f(pick_one(choices), subject), "F")

	-- other party probably responds
	if other and other.chatter * (0.75 + rnd.rnd()) > rnd.rnd() and other ~= FAKE_CAPTAIN then
		local responses = getConversation(other).default_participation
		local answered_in = rnd.rnd(4, 16)
		local otopics = getTopics(other)
		-- do we have to adjust our default responses?
		if otopics.disliked[topic] then -- no thanks
			-- record the negative interaction about topic with talker
			dislike_topic(topic, other, talker)
			responses = getConversation(other).phrases_disliked
		elseif otopics.liked[topic] then -- we like this topic (we have memories and we don't dislike it)
			-- let them interact
			responses = interact_topic(topic, talker, other)

			-- the other party will have responded positively, let's end the conversation here with a default response
			hook.timer(
				answered_in + rnd.rnd(2, 5),
				"say_specific",
				{me = talker, message = pick_one(getConversation(talker).default_participation)}
			)
		end
		hook.timer(answered_in, "say_specific", {me = other, message = fmt.f(pick_one(responses), join_tables(talker,{topic = topic}))})
	end

end

function speak(talker, other)
	local colour = "F"
	local choices
	local last_sentiment = talker.conversation.sentiment
	
	-- figure out what to say
	-- do I have a sentiment that I need to get off my chest?
	if talker.conversation.sentiment then
		-- less important thoughts, we store them all and then throw them away after we picked one out of this hat
		choices = {last_sentiment}
		-- do we want to talk about something else later?
		if talker.conversation.sentiments and rnd.rnd() < talker.chatter then
			talker.conversation.sentiment = pick_one(talker.conversation.sentiments)
		else
			talker.conversation.sentiment = nil
		end
	elseif talker.conversation.sentiments then
		choices = talker.conversation.sentiments
		talker.conversation.sentiments = nil
	elseif talker.satisfaction > 5 then
		-- I'm quite satisfied
		choices = talker.conversation.satisfied
	elseif talker.satisfaction < -3 then
		-- I'm noticably unsatisfied
		choices = talker.conversation.unsatisfied
		colour = "r"
	elseif rnd.rnd() < 0.042 then -- let's try to be original, share a fun fact
		choices = talker.conversation.backstory.funfacts
	else
		-- do I want to talk about a favourite topic?
		-- if the crew is a silent type, be more likely to just make smalltalk
		if rnd.rnd() < talker.chatter then
			-- let's consider our liked topics
			local topic
			local topics = getTopics(talker)
			for ttt, _v in pairs(topics.liked) do
				-- if we talk a lot, we will talk more randomly about topics by increasing the chance on low chatters
				if rnd.rnd() > talker.chatter then
					-- if we like the topic, talk about it unless we randomly feel like we have to talk about it
					-- otherwise we're always going to be negative, but we want negative memories not to be too repetitive
					if not topics.disliked[ttt] or rnd.twosigma() > 1 then
						topic = ttt
					end
				end
			end
			-- if we picked a topic
			if topic then
				-- rare edge case we talk to the captain instead of ourselves
				if not other then
					other = FAKE_CAPTAIN
				end
				return converse_topic(topic, talker, other)
			end
		end
		-- I don't have anything interesting to say, try smalltalk
		if talker.satisfaction > 0 then
			choices = getConversation(talker).smalltalk_positive
		else
			--			  colour = "y"
			choices = getConversation(talker).smalltalk_negative
		end
	end

	-- hopefully impossible safety branch
	if not choices or #choices == 0 then
	 choices = {"I have nothing to say."}
	end
	
	-- we didn't start discussing a topic, say what's on our mind
	local spoken = pick_one(choices)
	-- say it
	_comm(fmt.f("{typetitle} {name}", talker), spoken, colour)
	local listener = other or getCrewmateOnboard()
	-- if there's another person in the conversation, let them interact
	-- a response is more likely than striking a conversation
	if other and other.chatter * 1.5 > rnd.rnd() and other ~= FAKE_CAPTAIN then

		-- see if we want to strike up a new conversation based on interests
		for interest, _phrases in pairs(getTopics(other).liked) do
			if contains_ci(spoken, interest) then
				return converse_topic(interest, other, talker)
			end
		end

		-- not sure what to say yet, use the analyzer		 
		local response = analyze_spoken(spoken, talker, other)
		local answered_in = rnd.rnd(4, 16)
		hook.timer(answered_in, "say_specific", {me = other, message = response})

		-- listener feels randomly about this interaction, slightly weighted towards
		-- the negative, mostly for being targeted out of the blue
		listener.satisfaction = listener.satisfaction + math.floor(10 * rnd.twosigma()) / 1000 - 0.005
		-- if talker currently has a new sentiment then we just set it because of conversation
		-- so let's express ourselves if it seems novel
		if talker.conversation.sentiment and talker.conversation.sentiment ~= last_sentiment and rnd.rnd(0, 1) == 0 then
			-- TODO here: give the other person a chance to retort?
			-- it's our turn to talk, or at least we think so
			-- TODO: let's try to start a conversation instead
			local our_response = rnd.rnd(6, 12)
			hook.timer(
				answered_in + our_response,
				"say_specific",
				{me = talker, message = talker.conversation.sentiment}
			)
		elseif rnd.rnd() > talker.chatter then
			-- forget about it this new sentiment, we don't need to talk about it that much
			talker.conversation.sentiment = nil
		elseif talker.chatter > rnd.rnd() then
			-- we actually start feeling pressured to answer, and we analyze what was said back at us
			hook.timer(
				answered_in + rnd.rnd(3, 6),
				"say_specific",
				{me = talker, message = analyze_spoken(response, other, talker)}
			)
		end
	elseif listener and listener ~= talker then
		-- check if we can appreciate something that was spoken
		local appreciation, interest = appreciate_spoken(spoken, listener)

		-- listener thought about something, let's remember that instead of discarding the useful data
		insert_sentiment(listener, pick_one(appreciation))

		-- listener will mention his interest to the talker and try to start a conversation
		if interest then
			-- see if we have a sentiment
			return converse_topic(interest, listener, talker)
		elseif listener.conversation.sentiment then
			-- listener will mention his sentiment to another party
			local responder = talker
			if other then
				responder = other
			end
			
			if responder == nil then
				print("WARNING COMING! Responder is nil: talker, other, responder, listener:", talker, other, responder, listener)
			end
			
			hook.timer(
				rnd.rnd(6, 36), -- it might take us a while to speak up
				"speak_to",
				{
					me = listener,
					responder = responder,
					message = listener.conversation.sentiment
				}
			)
		end
	end
end

-- a hook wrapper that makes arg.me speak to arg.responder and 
-- makes arg.responder respond back (without expecting a reply)
function speak_to(arg)
	local response_delay = rnd.rnd(4, 8)
	local colour = arg.colour or "F"
	_comm(fmt.f("{typetitle} {name}", arg.me), arg.message, colour)
	if arg.responder then
	hook.timer(
		response_delay, "say_specific",
		{me = arg.responder, message = analyze_spoken(arg.message, arg.me, arg.responder) }
	)
	else
		print("WARNING: Speak_to with no responder! args:", arg)
		for k,v in pairs(arg) do
			print(fmt.f("{k}, {v}"), {k=k,v=v})
		end
	end
end

-- makes arg.me say arg.message to nobody (without expecting anything in return)
-- but only if we are un board
function say_specific(arg)
	if arg.me.away and arg.me.away.ship then
		-- missing people don't talk
		return
	end
	local colour = arg.colour or "F"
	_comm(fmt.f("{typetitle} {name}", arg.me), arg.message, colour)
end

-- the crew starts a conversation
function start_conversation()
	-- TODO: Talk attempts should be something like crew_mates / 3 or similar until you have a crew manager
	-- pick a random person and see if they want to talk
	local talker = getCrewmateOnboard()
	if not talker then
		return
	end
	local other = getCrewmateOnboard()

	print(fmt.f("picked {name} to talk", talker))
	if other == talker then
		-- special case: I will talk to myself
		if talker.satisfaction > -1 or talker.chatter < rnd.rnd() then
			-- don't talk to myself, I'm not crazy
			other = nil
		end
	end

	-- we are more likely to talk if we are not feeling neutral
	local fudge = math.abs(talker.satisfaction / 10)
	if rnd.rnd() < talker.chatter + fudge then
		-- I will speak
		speak(talker, other)
	else
		print(fmt.f("{name} didn't want to talk", talker))
		-- let other talk instead with a smaller chance
		if other and rnd.rnd() < (other.chatter / 2) then
			print(fmt.f("{name} got a chance to speak", other))
			speak(other) -- they just talk to themselves, not expecting an answer
		elseif other and rnd.rnd() < other.chatter then
			-- we actually wanted to talk, this makes us unhappy
			other.satisfaction = other.satisfaction - 0.02
			insert_sentiment(other, fmt.f(pick_one(getConversation(other).bad_talker), talker))
		end
	end

	-- hook initiation of a new conversation
	hook.rm(mem.conversation_hook)
	mem.conversation_hook = hook.date(time.new(0, 1, rnd.rnd(0, 300)), "start_conversation")
end

return contract.capture {
	name = "conversation_runtime",
	requires = { "context", "content.character", "memory" },
	exports = {
		"speak_notify", "dislike_topic", "dislikes_phrase", "doeslike_phrase",
		"appreciate_spoken", "generate_responses", "interact_topic",
		"analyze_spoken", "converse_topic", "speak", "speak_to",
		"say_specific", "start_conversation",
	},
}

-- randomly picks a planet belonging to a faction, or "my home planet" if it didn't pick one before it ran out
