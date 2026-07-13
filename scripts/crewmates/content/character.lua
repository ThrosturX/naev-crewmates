local fmt = require "format"
local pilotname = require "crewmates.pilotname"
local prng = require "prng"
local conversation = require "events.crewmates.conversation"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function generateTopics( seed )
	local topics = {
		-- list of phrases that use the things I can like (or not)
		["small talk"] = {
			_("I can't stop thinking about {article_of_thought}s."),
			_("I keep thinking about {article_of_thought}s."),
			_("I had a thought about a {article_of_thought}."),
			_("What do you think about {article_of_thought}s?"),
			_("Do you like {article_of_thought}s?"),
			_("I had a {article_of_thought} once, what about you?"),
			_("I've got {article_of_thought}s on my mind."),
			_("So... How about them {article_of_thought}s?"),
			_("Are you using a new shampoo?"),
			_("What's that smell? Smells kind of nice."),
			_("So, what do you think about {article_of_thought}s?"),
			_("Who doesn't love a {article_of_thought}?"),
			
		},
		["the view"] = {
			_("Did you see the view at that last shipyard?"),
			_("Did you notice the spectacular view during that eclipse?"),
			_("What a wonderful view. The stars are amazing."),
			_("What a wonderful view. The stars are as amazing as {article_of_thought}s."),
			_("What a wonderful view. The galaxy is amazing."),
			_("What a fantastic view. Reminds me of {article_of_thought}."),
			_("What a fantastic view."),
			_("What a fascinating display."),
			_("A view like that is worth a lot of credits."),
			_("Wow, get a load of that view!"),
			_("Oh man, what was that? Did anyone else see that?"),
			_("Did anyone else see that?"),
			_("Did you see that?"),
			_("Did you see that? Was that a {article_of_thought}?"),
			_("This is why people travel, this is a true life of luxury."),
			_("I like looking out at the stars."),
			_("How could anyone not admire this view?")
		},
		["luxury"] = {
			fmt.f(_("Do you want to see my {ship}? I keep it in storage."), {ship = getRandomShip()}),
			fmt.f(_("How do you like this {thing}?"), {thing = getRandomThing()}),
			fmt.f(_("I'm thinking about investing in {thing}s."), {thing = getRandomThing()}),
			fmt.f(_("I'm thinking about investing in {thing}s, what do you think?"), {thing = getRandomThing()}),
			_("What do you think about this color?"),
			_("Will you take me to Kramer some day?"),
			_("You should try the soap that I'm using, I don't know where you get your stuff."),
			_("You should try this lotion."),
			_("Here, try this cream."),
			_("Here, try this."),
			_("Here, try this, I know you'll like it."),
			_(
				[[Here, smell this. It's called "the faithful friend", but it cost a lot of credits, almost as much as this ship.]]
			),
			_(
				[[Here, smell this. It's called "the pacifier of violence", but it cost a lot of credits, almost as much as this ship.]]
			),
			fmt.f(
				_("You should try this new virtual viewport simulator, it lets you pretend you're on a {ship}."),
				{ship = getRandomShip()}
			),
			_("Back when I got my first Admonisher at Minerva Station, it cost ten thousand tokens."),
			_("I'll never fly in a Llama again, I much prefer the Gawain."),
			_("I'll never fly in a shuttle again, I much prefer the Gawain."),
			_("The Gawain is probably my favourite ship. I mean, that interior is to die for, literally."),
			_("The Gawain is probably my favourite ship. I mean, that interior is to kill for, literally.")
		},
		["friendships"] = {
			fmt.f(_("Check out this {ship} my friend thinking of buying."), {ship = getRandomShip()}),
			_("Do you want to grab a coffee?"),
			_("Do you want to grab a {article_of_thought}?"),
			_("I like how close we are."),
			_("I know we've had our differences, but you're alright."),
			_("Hey, buddy! Hows it's going? You good?"),
			fmt.f(_("Check out the custom paintjob on this {ship}!"), {ship = getRandomShip()}),
			fmt.f(_("My friend {name} would love this."), {name = pilotname.human()}),
			fmt.f(_("I'm sure {name} would appreciate this."), {name = pilotname.human()}),
			fmt.f(_("I'm sure {name} would appreciate this "), {name = pilotname.human()}) .. "{article_of_thought}.",
			fmt.f(_("I miss my friend {name}."), {name = pilotname.human()}),
			fmt.f(_("I used to have a friend called {name}."), {name = pilotname.human()}),
			fmt.f(_("I miss my friend {name}."), {name = lang.getMadeUpName()}),
			fmt.f(_("I used to have a friend called {name}."), {name = lang.getMadeUpName()}),
			fmt.f(_("I miss my old friend {name}."), {name = pilotname.human()}),
			fmt.f(_("I miss my other friend {name}."), {name = pilotname.human()}),
			fmt.f(_("I miss my friend's {name}."), {name = getRandomShip()}),
			fmt.f(_("I miss my friend's {name}. It wasn't special, but our friendship was."), {name = getRandomThing()}),
			fmt.f(_("I miss my friend {name}."), {name = lang.getMadeUpName()}),
			fmt.f(_("I miss my friends from the {name} I used to work on."), {name = getRandomShip()})
		},
		["ships"] = {
			fmt.f(_("Check out this {ship} my friend thinking of buying."), {ship = getRandomShip()}),
			fmt.f(_("Do you want to see my sister's {ship}? She keeps talking about it."), {ship = getRandomShip()}),
			fmt.f(
				_("This is my favourite ship. The {name} of {made_up} was alright but nothing like this."),
				{made_up = lang.getMadeUpName(), name = pilotname.human()}
			),
			fmt.f(
				_("This is such a nice ship. The {made_up} of {name} was decent but nothing like this."),
				{made_up = lang.getMadeUpName(), name = pilotname.human()}
			),
			fmt.f(_("I once constructed a {ship} in a single cycle."), {ship = getRandomShip()}),
			fmt.f(
				_("Have I told you about the prototype {ship} I designed during my training?"),
				{ship = getRandomShip()}
			),
			fmt.f(_("I used to serve on a {ship}. I think I've told you about it, right?"), {ship = getRandomShip()}),
			fmt.f(
				_("I once saw a comet shaped like a {ship} near {place}. It was pretty cool."),
				{ship = getRandomShip(), place = spob.get(true)}
			),
			fmt.f(
				_("I've heard from {name} the new {ship} is going to be even sleeker than the current model."),
				{name = pilotname.human(), ship = getRandomShip()}
			),
			fmt.f(
				_(
					"I've heard from my old friend {name} the next {ship}, code-name {made_up} is going to have a special compartment for {thing}s."
				),
				{
					ship = getRandomShip(),
					name = pilotname.generic(),
					made_up = lang.getMadeUpName(),
					thing = getRandomThing()
				}
			),
			fmt.f(_("Have you seen the new {ship} features?"), {ship = getRandomShip()}),
			fmt.f(_("Have you seen these hidden {ship} features?"), {ship = getRandomShip()}),
			fmt.f(
				_("Did you read that article about the {number} {ship} features no captain knows about?"),
				{ship = getRandomShip(), number = rnd.rnd(3, 14)}
			)
		},
		["business"] = {
			fmt.f(
				_("I was traveling near {place} for business in my early years. Have you been there?"),
				{place = spob.get(faction.get("Independent"))}
			),
			fmt.f(
				_("I was traveling near {place} for business in my early years. Have you been there?"),
				{place = spob.get(faction.get("Empire"))}
			),
			fmt.f(
				_("I had some business near {place} for some {art} back in the day. What a story."),
				{place = spob.get(faction.get("Empire")), art = "{article_of_thought}" }
			),
			fmt.f(
				_("I was traveling near {place} on a ship in my early years. I hated it, but the view was nice."),
				{place = spob.get(faction.get("Dvaered"))}
			),
			fmt.f(
				_("I had to travel near {place} for business in my early years. Have you been there?"),
				{place = spob.get(faction.get("Soromid"))}
			),
			fmt.f(
				_("I've heard that {place} is known for being good at science."),
				{place = spob.get(faction.get("Za'lek"))}
			),
			fmt.f(
				_("Of all my travels I must say, I've been too often to {place}."),
				{place = spob.get(faction.get("Soromid"))}
			),
			fmt.f(
				_("I didn't really like working at {place}, but the pay was good."),
				{place = spob.get(faction.get("Soromid"))}
			),

			fmt.f(
				_("{place} is my favourite pirate outpost. Don't ask me why, it just is."),
				{place = spob.get(faction.get("Raven Clan"))}
			)
		},
		["faith"] = {
			_("Sometimes you just have to have a little bit of faith."),
			_("Sometimes you just have to let the spirits guide you."),
			_("Sometimes you need to trust the universe."),
			_("My motto is: if you want {article_of_thought}s, you should have ethical morals."),
			_("I believe that traveling among the stars makes us immortal."),
			_("We're all going to die one day. Let's enjoy the ride."),
			_("I believe that things get worse, then they get better."),
			fmt.f(_("We all have a lot to believe in, but I believe in my lucky {thing}."), {thing = getRandomThing()})
		},
		["affairs"] = {
			fmt.f(
				_("I too have had my fair share of affairs. One day I might tell you the story of {name}."),
				{name = pilotname.human()}
			),
			fmt.f(_("I had an affair with a dangerous vagabond named {name}."), {name = pilotname.human()}),
			fmt.f(_("I got into a scuffle with a criminal named {name}."), {name = pilotname.human()}),
			fmt.f(
				_("I got into a mighty struggle with {name} of {made_up} before I joined this ship."),
				{made_up = lang.getMadeUpName(), name = pilotname.human()}
			),
			_("Don't ask me about my affairs."),
			_("Don't ask me about my love affairs."),
			_("Don't ask me about my personal affairs."),
			_("Don't ask me about my previous life."),
			_("Don't ask me about my personal life."),
			_("Please don't talk to me when I'm off duty."),
			_("I don't want to talk right now."),
			_("Not right now."),
			_("Sorry, I'm thinking about the {article_of_thought}."),
			_("I know I can be secretive sometimes, but some things are best left unsaid."),
			_("Actually, can we save this for later?"),
			_("Let's save this for later? I wanted to enjoy the view."),
			_("I want to visit one of my previous lovers. I'm just not sure which."),
			_("Not in this company. Later."),
			_("I'm not sure that whatever we're discussing is appropriate but whatever."),
			fmt.f(
				_(
					"... I'm not sure that's appropriate but whatever. I'm sure {captain} doesn't mind. Oh, hey {captain}!"
				),
				{captain = player:name()}
			)
		},
		["travel"] = {
			fmt.f(
				_("One of my favourite places to visit is {place}. Have you been there?"),
				{place = spob.get(faction.get("Independent"))}
			),
			fmt.f(
				_("A fascinating place to visit is {place}. Have you been there?"),
				{place = spob.get(faction.get("Za'lek"))}
			),
			fmt.f(
				_("I heard that {place} is developing a new {made_up}. Have you been there?"),
				{place = spob.get(faction.get("Za'lek")), made_up = lang.getMadeUpName()}
			),
			fmt.f(
				_("Of all my travels I must say, I've been too often to {place}. Have you been there?"),
				{place = spob.get(faction.get("Empire"))}
			),
			fmt.f(
				_("I had an affair with a warrior from {place}. I wonder what fearsome {name} is up to these days."),
				{place = spob.get(faction.get("Dvaered")), name = pilotname.human()}
			),
			fmt.f(
				_(
					"All the violence and lawlessness on {place} led my cousin {name} towards a path of disastrous affairs."
				),
				{place = spob.get(faction.get("Dvaered")), name = pilotname.human()}
			),
			fmt.f(
				_("I went to {place} just to check it out. I haven't had the urge to go since."),
				{place = spob.get(faction.get("Soromid"))}
			),
			fmt.f(
				_("I got to travel to {place} in my childhood. Unforgettable."),
				{place = spob.get(faction.get("Sirius"))}
			),
			fmt.f(
				_("I used to visit my {relative} {name} regularly on {place}."),
				{
					place = spob.get(faction.get("Empire")),
					name = pilotname.human(),
					relative = pick_one({_("aunt"), _("grandmother"), _("uncle"), _("grandfather"), _("councellor")})
				}
			),
		},
		["violence"] = {
			fmt.f(_("I once destroyed a {ship} in a single volley."), {ship = getRandomShip()}),
			fmt.f(_("Have I told you about the {ship} I destroyed during my training?"), {ship = getRandomShip()}),
			_("I've killed a man with my bare hands."),
			_("I could kill you with a spoon."),
			fmt.f(_("I could kill you with a {item}."), { item = pick_one(lang.getAll(lang.nouns.objects)) } ),
			fmt.f(_("I could kill you with a {item}."), { item = pick_one(lang.nouns.gifts) } ),
			_("I could kill you with a {article_of_thought}."),
			_("I could kill you with this {article_of_thought}."),
			_("I could kill you with {article_of_thought}s."),
			_("I could kill you with {article_of_thought}s. Think about that."),
			fmt.f(
				_("I could slay you with a defective {thing} in a {thong} battle."),
				{thing = lang.getMadeUpName(), thong = lang.getMadeUpName()}
			),
			_("You call that a knife?"),
			_("I will bathe in the blood of my enemies."),
			_("What are you looking at?"),
			_("Enjoying the view? Enjoy it while it lasts."),
			_("Give me some credits, or die."),
			_("I'll skin you if you meddle in my personal affairs."),
			_("This part of the ship is mine; you got it, friend?"),
			_(
				"I know we're not supposed to have blades like these in the spaceport but this baby never leaves my side, I take it everywhere."
			),
			_("I like to strike fear in my enemies."),
			_("I will strike fear in my enemies."),
			_("To run is to lose, to win is to die."),
			_("Sometimes, excessive force is necessary."),
			_("You always have a right to defend yourself. Even if that means shooting someone in the face."),
			fmt.f(_("Check out my {made_up} rifle, pretty neat, huh?"), {made_up = lang.getMadeUpName()}),
			fmt.f(
				_(
					"Check out this {made_up}. I only paid {amount} for this killer. How many credits is that per ship destroyed?"
				),
				{made_up = lang.getMadeUpName(), amount = fmt.credits(rnd.rnd(35e3, 725e3))}
			),
			_("I would never kill my friends, but I could break your leg on a whim."),
			fmt.f(
				_("All the violence and lawlessness on {place} excites me."),
				{place = spob.get(faction.get("Dvaered"))}
			),
			fmt.f(
				_("I got into a scuffle on {place} some cycles back. That's where I got the small scar."),
				{place = spob.get(faction.get("Dvaered"))}
			),
			fmt.f(
				_("We all make mistakes. I once killed a man on {place} only to find out I got the wrong guy."),
				{place = spob.get(faction.get("Empire"))}
			),
			fmt.f(
				_(
					"I once had our ship travel all the way to {place} only to find out that I forgot to reset the navigation equipment. Let's just say that I would owe them quite a few credits if they had any use for them."
				),
				{place = spob.get(faction.get("Empire"))}
			)
		},
		["credits"] = {
			_("That's worth a lot of {article_of_thought}s."),
			_("Give me some credits."),
			_("Lend me some credits."),
			_("Hand me that credit chip."),
			_("Is this yours? Do you mind?"),
			_("Is that yours? Can I take it?"),
			_("Can I have that?"),
			_("Are you gonna use that?"),
			_("*inaudible*"),
			_("Are we talking about money? That's what I like to call it."),
			_("Did somebody say credits? Yeah I'm listening."),
			_("How many credits is that?"),
			_("Who doesn't love dough?"),
			_("I heard what you said earlier about your business."),
			_("Who doesn't love credits?"),
			_("Who doesn't love moolah?"),
			_("That's a lot of coin."),
			_("I wouldn't want to owe that much."),
			_("I wouldn't want to own that much."),
			_("It sounds like a lot, but if you scratch my back, I'll scratch yours."),
			_("Stop bothering me, I'm trying to think."),
			_("Stop bothering me, I'm trying to think!"),
			_("Why are we changing the subject?"),
			_("I can't stop thinking about the weight of that last credit chip."),
			_("Can't you see I'm trying to count here?"),
			_("Sorry, I'm having a little trouble doing my finances right now.")
		},
		["science"] = {
			fmt.f(_("Check out the landing gear on this {ship}!"), {ship = getRandomShip()}),
			fmt.f(_("Have you seen the new {ship} features?"), {ship = getRandomShip()}),
			fmt.f(_("Have you seen these hidden {ship} features?"), {ship = getRandomShip()}),
			fmt.f(
				_("Did you read that article about the 7 {ship} features no captain knows about?"),
				{ship = getRandomShip()}
			),
			fmt.f(_("I heard about some unexplained phenomena at {place}."), {place = spob.get(true)}),
			fmt.f(_("I wonder what the big deal about {place} is, there's no mystery."), {place = spob.get(true)}),
			fmt.f(
				_("I once saw a comet shaped like a {ship} near {place}. It was pretty cool."),
				{ship = getRandomShip(), place = spob.get(true)}
			),
			fmt.f(
				_("I've heard from {name} the new Admonisher is going to be even sleeker than the current model."),
				{name = pilotname.human()}
			),
			fmt.f(
				_(
					"I've heard from {name} the next {ship}, code-name {made_up} is going to have a secret unscannable cargo compartment."
				),
				{ship = getRandomShip(), name = pilotname.generic(), made_up = lang.getMadeUpName()}
			),
			fmt.f(
				_("The new '{made_up}' {thing} is supposedly the bee's knees."),
				{made_up = lang.getMadeUpName(), thing = getRandomThing()}
			),
			fmt.f(
				_("I've heard that an updated {thing} is going to be even sleeker than the current model."),
				{thing = getRandomThing()}
			),
			fmt.f(
				_("I've heard that the new {thing} is going to be even sleeker than the current model."),
				{thing = lang.getMadeUpName()}
			),
			fmt.f(_("I just read that the {thing} is getting revamped again."), {thing = lang.getMadeUpName()}),
			fmt.f(_("I've tried that new {thing} and I have to say, I'm amazed."), {thing = lang.getMadeUpName()}),
			fmt.f(
				_("Did you hear that the {thing} now only costs {amount}?"),
				{thing = lang.getMadeUpName(), amount = fmt.credits(rnd.rnd(20e3, 50e3 - 1))}
			),
			fmt.f(_("I've tried that new {thing} and I have to say, I'm amazed."), {thing = lang.getMadeUpName()}),
			fmt.f(
				_("I don't think those paid science publications are any good. I put all my faith in {thing}."),
				{thing = lang.getMadeUpName()}
			),
			fmt.f(
				_(
					"{thing} luxury friendship bracelets are practically being given away for just a single credit if you adopt an abandoned illegal pet iguana and fill out some required forms. The only downside is that we'd have to travel to {place} to go get it."
				),
				{thing = lang.getMadeUpName(), place = spob.get(faction.get("Empire"))}
			)
		}
	}

	seed = seed or rnd.rnd(1, 8888)
	local rng = prng.new( seed )
	local liked = {}
	local disliked = {}
	-- now go through all the topics, and pick whether we like, dislike, or don't care about each one
	for topic, phrases in pairs(topics) do
		local roll = rng:random(0, 6)
		if roll > 3 then -- yay, we like this
			-- pick some of the phrases to learn about this topic
			liked[topic] = pick_some(phrases, 4, rng)
		elseif roll < 3 then -- ouch, we got a 2 or a 3
			disliked[topic] = true
		end -- 3 is indifferent
	end
	return liked, disliked
end


-- generates a rather verbose preference table describing items/foods liked or disliked
function generatePreferences( seed )
	local preferences = {}
	seed = seed or rnd.rnd(1, 8888)
	
	local rng = prng.new( seed )
	
	preferences.liked = pick_some( -- <--- this first pick_some is just to help reduce the size of the preferences a bit
		append_table(
			pick_some(lang.nouns.food.general, 4, rng),			-- have preference for some food
			append_table(
				pick_some(lang.getAll(lang.nouns.objects), 4, rng),	-- appreciate kinds of things more than others
				join_tables(
					join_tables(
						pick_some(lang.nouns.food.fruit, 4, rng),
						pick_some(lang.nouns.food.fruit, 6, rng) -- like some fruit more than others
					), join_tables(
						pick_some(lang.nouns.gifts, 2, rng),		-- like most gifts
						pick_some(lang.adjectives.positive.nice, 2, rng)	-- like most nice things
					)
				)
			)
		),
		3,		-- control size of preferences
		rng
	)
	
	preferences.liked = append_table(preferences.liked,
		pick_some(lang.getAll(lang.adjectives), 4, rng)		-- some adjectives trigger happy memories
	)
	
	-- dislike some fruit, if we like and dislike something then it's
	-- rather random how we feel about it, realistic right?
	preferences.disliked = append_table(
		pick_some(lang.nouns.food.general, 4, rng),
		append_table(
			pick_some(lang.nouns.food.fruit, 5, rng),	-- don't like all fruit
			pick_some(lang.nouns.objects.items, 4, rng)	-- don't like some specific items
		)
	)
	preferences.disliked = append_table(preferences.disliked,
		append_table(
			pick_some(lang.getAll(lang.adjectives.negative), 4, rng),	-- some negative adjectives are extra nasty to us
			pick_some(lang.getAll(lang.adjectives), 5, rng)			-- some adjectives disgust us
		)
	)
	
	return preferences
end

-- reduce save file size by using a fake little in-mem resoruce manager
PREFERENCES = {}
CONVERSATIONS = {}
TOPICS = {}	-- topics to talk about
NOTALK = {}	-- topics not to talk about
SHORT_TERM_MEMORY = {}

function getPreferences( character )
	-- guard case resource not loaded
	if not PREFERENCES[character.name] then
		PREFERENCES[character.name] = generatePreferences(character.pseed)
	end
	return PREFERENCES[character.name]
end

function getConversation(character)
	if not CONVERSATIONS[character.name] then
		CONVERSATIONS[character.name] = conversation[character.personality] or conversation.basic
	end
	local result = CONVERSATIONS[character.name]()
	if character.conversation then		-- special crewmate with custom lines
		-- NOTE: our merge_tables isn't recursive, so we use full_merge here instead
		result = full_merge(result, character.conversation)
		table.insert(result.fatigue, fmt.f(_("*sigh*... Time for my {skill} duty I guess."), character ))
	end
	return result
end

function getTopics(character)
	-- guard case resource not loaded
	if not TOPICS[character.name] then
		local liked, disliked = generateTopics( character.pseed )
		TOPICS[character.name] = liked
		NOTALK[character.name] = disliked
	end

	-- merge topics with memories
	local memories = SHORT_TERM_MEMORY[character.name] or {}
	if character.memories then
		memories = merge_tables(memories, character.memories)
	end
		
	return {
		["liked"] = merge_tables(memories, TOPICS[character.name]),
		["disliked"] = NOTALK
	}
end

return contract.capture {
	name = "content.character",
	requires = { "context", "content.random" },
	exports = {
		"generateTopics", "generatePreferences", "PREFERENCES", "CONVERSATIONS",
		"TOPICS", "NOTALK", "SHORT_TERM_MEMORY", "getPreferences",
		"getConversation", "getTopics",
	},
}

-- for adding a special kind of speech into an utterance
